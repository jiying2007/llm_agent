"""Synthetic collector contracts; these fixtures are never qualification evidence."""
from __future__ import annotations

import copy
import hashlib
import io
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

from delegated_review_fixtures import policy_fixture, review_fixture, write_json

from tools.control_plane import qualification_followup as followup

CANARY = "test-secret-that-must-not-appear-in-artifacts"


def blocked(check: followup.Check) -> dict:
    """Minimal known-schema checker responses, with no signed or human claims."""
    data = {check.schema_key: check.schema}
    if check.id in ("root-154", "adk-153"):
        flag = "effect_evidence_ready" if check.id == "root-154" else "native_verified"
        data.update(status="pass", software_ready=True, terminal_status="blocked-external-evidence",
                    blockers=["external-evidence-required:test-fixture"], **{flag: False})
    elif check.id == "root-67":
        data.update(status="blocked", reason="summary-evidence-missing", observed_days=37)
    elif check.id == "root-236":
        data.update(status="blocked", read_only=True, stages={"promotion_signature": {
            "status": "blocked", "reason": "fresh pinned-verifier readback required"}},
            model_invocations=0, write_performed=False, software_m5_certified=False,
            release_authorized=False, blocking_gates=["runtime", "field"])
    else:
        data.update(mode="gate", overall_status="partial", as_of="2026-10-20",
                    scan={"errors": [], "truncated": False}, dimensions=[{
                        "dimension_id": "context_legibility", "status": "partial",
                        "last_verified_at": "2026-07-18",
                        "blockers": [{"code": "stale_last_verified_at"}]}])
    return data


def completed(check: followup.Check, data: dict, code: int = 2,
              stderr: bytes = b"") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(list(check.command), code, json.dumps(data).encode(), stderr)


class QualificationFollowupTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="qualification-followup-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.checks = followup._checks(self.root)
        self.source = {"git": {"root": {"head": "a" * 40, "tree": "b" * 40}},
                       "inputs": {}, "scope": "test snapshot", "sha256": "c" * 64}

    def run_item(self, check: followup.Check, data: dict, code: int = 2,
                 stderr: bytes = b"") -> dict:
        with patch.object(followup, "run_bounded", return_value=completed(check, data, code, stderr)):
            return followup._collect_command(self.root, check, {})

    def collect_blocked(self, snapshots: list | None = None) -> dict:
        results = [completed(check, blocked(check)) for check in self.checks]
        # This disposable unit fixture intentionally has no source tree.
        # Isolate the five canonical checker semantics from #201 inventory.
        history = {"id": "adk-201", "title": "Historical source",
                   "scan_status": "complete", "status": "historical-reviewed",
                   "qualification_ready": False, "required_in_current_scope": True,
                   "command": None, "command_exit": None,
                   "result": {"delegated_review_verified": False,
                              "historical_review_verified": True,
                              "semantic_review_performed": False},
                   "remaining_evidence": [], "next_actions": []}
        with patch.object(followup, "_snapshot", side_effect=snapshots or [self.source, self.source]), \
                patch.object(followup, "run_bounded", side_effect=results), \
                patch.object(followup, "_review_inventory", return_value=history):
            return followup.collect(self.root)

    def test_all_blocked_is_complete_read_only_scan(self) -> None:
        report = self.collect_blocked()
        self.assertEqual(report["scan_status"], "complete")
        self.assertTrue(report["source_consistent"])
        self.assertEqual(report["input_digest"], self.source["sha256"])
        self.assertEqual([item["id"] for item in report["items"]],
                         ["root-236", "root-154", "root-67", "adk-153", "adk-205", "adk-201"])
        self.assertEqual([item["command_exit"] for item in report["items"]], [2, 2, 2, 2, 2, None])
        self.assertTrue(report["report_only"])
        for key in ("qualification_all_ready", "release_authorized", "may_fill_owner",
                    "provider_execution_performed", "required_qualification_ready"):
            self.assertFalse(report[key])
        for check, item in zip(self.checks, report["items"], strict=False):
            self.assertEqual(item["result"], blocked(check))
            self.assertFalse(item["qualification_ready"])

    def test_fixed_commands_and_environment_use_current_root_and_utc(self) -> None:
        seen = []

        def runner(command, cwd, **kwargs):
            check = next(check for check in self.checks if check.command == command)
            seen.append((command, cwd, kwargs))
            return completed(check, blocked(check))

        with patch.object(followup, "_snapshot", return_value=self.source), \
                patch.object(followup, "run_bounded", side_effect=runner):
            followup.collect(self.root)
        self.assertEqual(len(seen), 5)
        for command, cwd, kwargs in seen:
            self.assertEqual(command[:2], (sys.executable, "-m"))
            self.assertEqual(cwd, self.root)
            self.assertEqual(kwargs["env"]["TZ"], "UTC")
            self.assertEqual(kwargs["env"]["PYTHONDONTWRITEBYTECODE"], "1")
            self.assertEqual(kwargs["env"]["PYTHONPATH"],
                             os.pathsep.join((str(self.root), str(self.root / "agent-dev-kit/src"))))
            self.assertFalse(set(command).intersection({"--as-of", "--allow-network", "--apply",
                                                       "--approve-unknown-cost", "--output", "shell"}))
        self.assertIn("--require-evidence", self.checks[1].command)
        self.assertIn("--require-native", self.checks[3].command)
        self.assertIn("--gate", self.checks[4].command)

    def test_source_projection_exit_zero_cannot_mean_effect_ready(self) -> None:
        item = self.run_item(self.checks[1], blocked(self.checks[1]), code=0)
        self.assertEqual(item["scan_status"], "error")
        self.assertFalse(item["qualification_ready"])
        self.assertIsNone(item["result"])
        self.assertEqual(item["command_exit"], 0)

    def test_inconsistent_software_block_is_error(self) -> None:
        for check in (self.checks[1], self.checks[3]):
            with self.subTest(check=check.id):
                data = blocked(check)
                data["software_ready"] = False
                item = self.run_item(check, data)
                self.assertEqual(item["scan_status"], "error")
                data["terminal_status"] = "blocked-software"
                self.assertEqual(self.run_item(check, data)["scan_status"], "complete")

    def test_ready_flags_require_exact_boolean_and_matching_exit(self) -> None:
        for check in (self.checks[1], self.checks[3]):
            flag = "effect_evidence_ready" if check.id == "root-154" else "native_verified"
            data = blocked(check)
            data[flag] = True
            data["terminal_status"] = "ready"
            self.assertEqual(self.run_item(check, data, 2)["scan_status"], "error")
            self.assertTrue(self.run_item(check, data, 0)["qualification_ready"])
            data[flag] = 1
            self.assertEqual(self.run_item(check, data, 0)["scan_status"], "error")

    def test_checker_error_retains_all_other_results(self) -> None:
        results = [completed(check, blocked(check), 7 if check.id == "root-154" else 2)
                   for check in self.checks]
        with patch.object(followup, "_snapshot", return_value=self.source), \
                patch.object(followup, "run_bounded", side_effect=results) as runner:
            report = followup.collect(self.root)
        self.assertEqual(runner.call_count, 5)
        self.assertEqual(len(report["items"]), 6)
        self.assertEqual(report["scan_status"], "error")
        self.assertEqual(report["items"][1]["command_exit"], 7)
        self.assertEqual(report["items"][4]["scan_status"], "complete")
        self.assertIsNotNone(report["items"][4]["result"])

    def test_unknown_schema_canary_is_not_copied_to_report(self) -> None:
        check = self.checks[1]
        data = blocked(check)
        data.update(schema="unknown/v9", private_data=CANARY)
        item = self.run_item(check, data)
        self.assertEqual(item["error"], "invalid-checker-schema-or-status")
        self.assertIsNone(item["result"])
        self.assertNotIn(CANARY, json.dumps(item))
        self.assertEqual(item["stdout"]["sha256"],
                         hashlib.sha256(json.dumps(data).encode()).hexdigest())

    def test_invalid_exit_output_is_sanitized(self) -> None:
        for code in (1, 7, -9):
            with self.subTest(code=code):
                data = blocked(self.checks[1])
                data["private_data"] = CANARY
                item = self.run_item(self.checks[1], data, code, CANARY.encode())
                self.assertEqual(item["command_exit"], code)
                self.assertIsNone(item["result"])
                self.assertNotIn(CANARY, json.dumps(item))

    def test_invalid_json_duplicate_keys_and_nonfinite_are_sanitized(self) -> None:
        payloads = [CANARY.encode(), json.dumps([CANARY]).encode(),
                    ('{"secret":"' + CANARY + '","x":1,"x":2}').encode(),
                    ('{"secret":"' + CANARY + '","x":NaN}').encode(), b"\xff"]
        for payload in payloads:
            with self.subTest(payload_digest=hashlib.sha256(payload).hexdigest()):
                result = subprocess.CompletedProcess(self.checks[1].command, 2, payload, CANARY.encode())
                with patch.object(followup, "run_bounded", return_value=result):
                    item = followup._collect_command(self.root, self.checks[1], {})
                self.assertEqual(item["error"], "invalid-checker-json")
                self.assertEqual(item["command_exit"], 2)
                self.assertIsNone(item["result"])
                self.assertNotIn(CANARY, json.dumps(item))

    def test_valid_result_preserved_but_stderr_is_only_digest(self) -> None:
        data = blocked(self.checks[1])
        item = self.run_item(self.checks[1], data, stderr=CANARY.encode())
        self.assertEqual(item["result"], data)
        self.assertEqual(item["stderr"], {"bytes": len(CANARY),
                                         "sha256": hashlib.sha256(CANARY.encode()).hexdigest()})
        self.assertNotIn(CANARY, json.dumps(item))

    def test_real_invalid_unicode_child_preserves_full_error_report(self) -> None:
        malformed = []
        for value in ({"notes": [CANARY + "\ud800"]}, {"nested": {CANARY + "\udfff": 1}}):
            data = blocked(self.checks[1])
            data.update(value)
            malformed.append(json.dumps(data, ensure_ascii=True).encode("utf-8"))
        for encoding in ("utf-16", "utf-16-le", "utf-32", "utf-32-be"):
            malformed.append(json.dumps(blocked(self.checks[1])).encode(encoding))
        child = ("import sys;sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]));"
                 "sys.stderr.buffer.write(bytes.fromhex(sys.argv[2]));sys.exit(2)")
        for raw in malformed:
            with self.subTest(payload_sha256=hashlib.sha256(raw).hexdigest()):
                commands = []
                for check in self.checks:
                    payload = raw if check.id == "root-154" else json.dumps(blocked(check)).encode("utf-8")
                    commands.append(replace(check, command=(sys.executable, "-c", child,
                                                             payload.hex(), CANARY.encode().hex())))
                output = io.StringIO()
                with patch.object(followup, "_checks", return_value=tuple(commands)), \
                        patch.object(followup, "_snapshot", return_value=self.source), redirect_stdout(output):
                    code = followup.main(["--root", str(self.root), "--summary-json"])
                encoded = output.getvalue().encode("utf-8")
                report = json.loads(encoded)
                self.assertEqual(code, 1)
                self.assertEqual(report["scan_status"], "error")
                self.assertTrue(report["source_consistent"])
                self.assertEqual(len(report["items"]), 6)
                failed = report["items"][1]
                self.assertEqual(failed["error"], "invalid-checker-json")
                self.assertEqual(failed["command_exit"], 2)
                self.assertEqual(failed["stdout"], {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
                self.assertEqual(failed["stderr"], {"bytes": len(CANARY),
                                                    "sha256": hashlib.sha256(CANARY.encode()).hexdigest()})
                self.assertIsNone(failed["result"])
                for index in (0, 2, 3, 4):
                    self.assertEqual(report["items"][index]["result"], blocked(self.checks[index]))
                    self.assertEqual(report["items"][index]["command_exit"], 2)
                for flag in ("qualification_all_ready", "required_qualification_ready", "release_authorized"):
                    self.assertFalse(report[flag])
                self.assertNotIn(CANARY.encode(), encoded)

    def test_command_start_error_does_not_echo_exception(self) -> None:
        with patch.object(followup, "run_bounded", side_effect=OSError(CANARY)):
            item = followup._collect_command(self.root, self.checks[1], {})
        self.assertEqual(item["error"], "command-could-not-complete")
        self.assertIsNone(item["command_exit"])
        self.assertNotIn(CANARY, json.dumps(item))

    def test_real_child_timeout_is_bounded_without_fabricated_exit(self) -> None:
        check = replace(self.checks[1], command=(sys.executable, "-c", "import time; time.sleep(20)"))
        with patch.object(followup, "COMMAND_TIMEOUT", 0.05):
            item = followup._collect_command(self.root, check, dict(os.environ))
        self.assertEqual(item["error"], "command-budget-exceeded")
        self.assertIsNone(item["command_exit"])

    def test_real_child_stdout_overflow_is_bounded(self) -> None:
        check = replace(self.checks[1], command=(sys.executable, "-c", "print('x' * 65536)"))
        with patch.object(followup, "MAX_STDOUT", 128):
            item = followup._collect_command(self.root, check, dict(os.environ))
        self.assertEqual(item["error"], "command-budget-exceeded")
        self.assertIsNone(item["result"])

    def test_real_child_stderr_overflow_does_not_leak_environment(self) -> None:
        code = "import os, sys; sys.stderr.write(os.environ['FOLLOWUP_TEST_CANARY'] * 4096)"
        check = replace(self.checks[1], command=(sys.executable, "-c", code))
        env = dict(os.environ, FOLLOWUP_TEST_CANARY=CANARY)
        with patch.object(followup, "MAX_STDERR", 64):
            item = followup._collect_command(self.root, check, env)
        self.assertEqual(item["error"], "command-budget-exceeded")
        self.assertNotIn(CANARY, json.dumps(item))

    def test_non_git_root_never_executes_target_collectors(self) -> None:
        with patch.object(followup, "_collect_command") as runner, \
                patch.object(followup, "_review_inventory") as inventory:
            report = followup.collect(self.root)
        runner.assert_not_called()
        inventory.assert_not_called()
        self.assertEqual(report["errors"], ["source-before-invalid"])
        self.assertEqual(len(report["items"]), 6)
        self.assertTrue(all(item["execution_status"] == "not-run" for item in report["items"]))

    def test_symlink_root_never_starts_any_command(self) -> None:
        link = self.root / "linked-root"
        link.symlink_to(self.root, target_is_directory=True)
        with patch.object(followup, "run_bounded") as runner:
            report = followup.collect(link)
        runner.assert_not_called()
        self.assertEqual(report["scan_status"], "error")
        self.assertEqual(len(report["items"]), 6)
        self.assertTrue(all(item["command_exit"] is None for item in report["items"]))

    def test_invalid_source_snapshot_fails_closed(self) -> None:
        with patch.object(followup, "_snapshot", side_effect=ValueError(CANARY)), \
                patch.object(followup, "_collect_command") as runner, \
                patch.object(followup, "_review_inventory") as inventory:
            report = followup.collect(self.root)
        runner.assert_not_called()
        inventory.assert_not_called()
        self.assertNotIn(CANARY, json.dumps(report))
        self.assertEqual(report["scan_status"], "error")

    def test_source_drift_invalidates_status_but_preserves_valid_observations(self) -> None:
        after = copy.deepcopy(self.source)
        after["sha256"] = "d" * 64
        report = self.collect_blocked([self.source, after])
        self.assertEqual(report["errors"], ["source-inputs-changed-during-scan"])
        self.assertEqual(report["scan_status"], "error")
        self.assertFalse(report["source_consistent"])
        self.assertTrue(all(item["scan_status"] == "error" for item in report["items"]))
        self.assertEqual(report["items"][1]["result"], blocked(self.checks[1]))
        self.assertEqual(report["items"][1]["command_exit"], 2)
        self.assertFalse(report["qualification_all_ready"])

    def test_unreadable_after_snapshot_is_error_with_all_results(self) -> None:
        report = self.collect_blocked([self.source, ValueError(CANARY)])
        self.assertEqual(report["errors"], ["source-after-invalid"])
        self.assertEqual(len(report["items"]), 6)
        self.assertNotIn(CANARY, json.dumps(report))
        self.assertEqual(report["scan_status"], "error")

    def test_raw_file_digest_distinguishes_lf_from_crlf(self) -> None:
        path = self.root / "input.txt"
        path.write_bytes(b"test\n")
        before = followup._file_identity(self.root, "input.txt")
        path.write_bytes(b"test\r\n")
        after = followup._file_identity(self.root, "input.txt")
        self.assertNotEqual(before["sha256"], after["sha256"])
        self.assertEqual(after["bytes"], 6)

    def test_file_identity_rejects_symlink_and_nonregular_inputs(self) -> None:
        (self.root / "link").symlink_to(self.root / "missing")
        (self.root / "directory").mkdir()
        for name in ("link", "directory"):
            with self.subTest(name=name), self.assertRaises(RuntimeError):
                followup._file_identity(self.root, name)

    def test_inventory_does_not_interpret_stage_or_review_content_as_approval(self) -> None:
        change = self.root / "agent-dev-kit/docs/changes" / followup.CHANGE_IDS[0]
        change.mkdir(parents=True)
        (change / "state.yaml").write_text("stage: reviewed\nowner_verdict: approved\n", encoding="utf-8")
        (change / "review-report.md").write_text(CANARY, encoding="utf-8")
        item = followup._review_inventory(self.root)
        self.assertEqual(item["status"], "error")
        self.assertEqual(item["scan_status"], "error")
        self.assertFalse(item["qualification_ready"])
        self.assertFalse(item["result"]["delegated_review_verified"])
        self.assertFalse(item["result"]["semantic_review_performed"])
        self.assertIsNone(item["command_exit"])
        self.assertNotIn(CANARY, json.dumps(item))
        self.assertTrue(item["result"]["changes"][0]["files"]["review-report.md"]["present"])
        self.assertEqual(item["result"]["changes"][1]["reason"], "change-package-missing")

    def test_human_inventory_unsafe_input_is_scan_error(self) -> None:
        change = self.root / "agent-dev-kit/docs/changes" / followup.CHANGE_IDS[0]
        change.mkdir(parents=True)
        (change / "state.yaml").symlink_to(self.root / "missing")
        item = followup._review_inventory(self.root)
        self.assertEqual(item["scan_status"], "error")
        self.assertFalse(item["qualification_ready"])

    def test_calendar_elapsed_does_not_supply_longitudinal_observation(self) -> None:
        item = self.run_item(self.checks[2], blocked(self.checks[2]))
        self.assertFalse(item["qualification_ready"])
        self.assertEqual(item["remaining_evidence"], ["summary-evidence-missing"])
        for simulated in (True, False):
            data = blocked(self.checks[2])
            data.update(status="pass", simulated=simulated)
            self.assertEqual(self.run_item(self.checks[2], data, 0)["scan_status"], "error")

    def test_conditional_m5_diagnostics_do_not_claim_bad_signature_or_activation(self) -> None:
        item = self.run_item(self.checks[0], blocked(self.checks[0]))
        self.assertEqual(item["scope"], "conditional-product-release")
        self.assertEqual(item["activation"], "not-assessed-by-diagnostics")
        self.assertFalse(item["component_signature_reverified"])
        self.assertTrue(item["diagnostics_only"])
        self.assertFalse(item["qualification_ready"])
        self.assertFalse(item["required_in_current_scope"])
        self.assertEqual(item["status"], "conditional")
        self.assertEqual(item["assessment"], "not-assessed")
        self.assertEqual(item["result"]["stages"]["promotion_signature"]["status"], "blocked")

    def reviewed_changes(self) -> list[Path]:
        adk = self.root / "agent-dev-kit"
        now = datetime.now(UTC)
        policy_fixture(adk, now)
        changes = []
        synthetic_patch_digests = {}
        for change_id, head in followup.CHANGE_HEADS.items():
            change = adk / "docs/changes" / change_id
            change.mkdir(parents=True)
            (change / "state.yaml").write_text("stage: review-passed\n", encoding="utf-8")
            source = change / "requirements.md"
            source.write_text("Synthetic frozen source requirements.\n", encoding="utf-8")
            record = review_fixture(adk, change / "review-evidence.json", subject=change_id, scope="source-change",
                                    sources=[source], reviewed_at=now, target={"base_commit": followup.CHANGE_BASES[change_id], "head_commit": head})
            synthetic_patch_digests[change_id] = record["target"]["original_patch_sha256"]
            changes.append(change)
        # The disposable fixture has a small synthetic diff, not historical ADK
        # source. Preserve production's pinned targets and replace only this test
        # consumer's expected diff bytes; mismatch tests still enforce equality.
        expected_patches = patch.dict(followup.CHANGE_PATCHES, synthetic_patch_digests)
        expected_patches.start()
        self.addCleanup(expected_patches.stop)
        return changes

    def archive_fixture(self, first: Path) -> Path:
        archive = first.parent / "archive" / ("20261020-" + first.name)
        archive.parent.mkdir(exist_ok=True)
        first.rename(archive)
        (archive / "state.yaml").write_text("stage: archived\nowner: ai/fixture-coordinator\n", encoding="utf-8")
        record_path = archive / "review-evidence.json"
        record = json.loads(record_path.read_text(encoding="utf-8"))
        fields = {
            "schema": "adk-change-provenance/v1", "authority": "ADK Canonical Change Contract",
            "change_id": first.name, "source_stage": "review-passed", "final_stage": "archived",
            "archived_by": "ai/fixture-coordinator", "archived_at": record["reviewed_at"],
            "reviewer_id": record["reviewer"]["id"], "review_verdict": "pass",
            "review_record_sha256": hashlib.sha256(record_path.read_bytes()).hexdigest(),
        }
        (archive / "provenance.md").write_text("# Archive provenance\n\n" + "".join(
            f"- {key}: {value}\n" for key, value in fields.items()), encoding="utf-8")
        tree = self.pin_synthetic_archive_tree(archive)
        # Disposable historical fixture: never replace real frozen production
        # hashes; scope synthetic pins to this unittest only.
        for mapping, digest in (
            (followup.FROZEN_ARCHIVE_GIT_TREES, tree),
            (followup.FROZEN_ARCHIVED_REVIEW_SHA256, hashlib.sha256(record_path.read_bytes()).hexdigest()),
        ):
            patcher = patch.dict(mapping, {first.name: digest})
            patcher.start()
            self.addCleanup(patcher.stop)
        return archive

    def test_valid_delegated_reviews_have_a_reachable_ready_path(self) -> None:
        self.reviewed_changes()
        item = followup._review_inventory(self.root)
        self.assertEqual(item["status"], "ready", item)
        self.assertTrue(item["qualification_ready"])
        self.assertTrue(item["result"]["delegated_review_verified"])
        self.assertFalse(item["result"]["semantic_review_performed"], "collector does not perform the review itself")
        self.assertTrue(all(change["reviewer"]["kind"] == "ai" for change in item["result"]["changes"]))

    def test_historical_inventory_rejects_rehashed_dirty_adk_authority(self) -> None:
        changes = self.reviewed_changes()
        policy = self.root / "agent-dev-kit/.adk/review-policy.json"
        policy.write_bytes(policy.read_bytes() + b"\n")
        for change in changes:
            path = change / "review-evidence.json"
            record = json.loads(path.read_text(encoding="utf-8"))
            record["policy_sha256"] = hashlib.sha256(policy.read_bytes()).hexdigest()
            write_json(path, record)
        result = followup._review_inventory(self.root)
        self.assertEqual(result["scan_status"], "error")
        self.assertFalse(result["qualification_ready"])

    def test_historical_inventory_rejects_an_adk_head_outside_the_root_pin(self) -> None:
        self.reviewed_changes()
        adk = self.root / "agent-dev-kit"
        subprocess.run(["git", "-C", str(adk), "-c", "user.name=Synthetic Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "--allow-empty", "-qm", "Unpinned historical review fixture"], check=True, capture_output=True)
        result = followup._review_inventory(self.root)
        self.assertEqual(result["scan_status"], "error")
        self.assertFalse(result["qualification_ready"])

    def test_archived_review_resolves_once_without_rewriting_its_record(self) -> None:
        first, *_ = self.reviewed_changes()
        self.archive_fixture(first)
        item = followup._review_inventory(self.root)
        self.assertTrue(item["qualification_ready"], item)
        self.assertEqual(item["result"]["changes"][0]["stage"], "archived")
        first.mkdir()
        duplicate = followup._review_inventory(self.root)
        self.assertEqual(duplicate["scan_status"], "error")
        self.assertFalse(duplicate["qualification_ready"])
        with self.assertRaises(ValueError):
            followup._review_paths(self.root)

    def pin_synthetic_archive_tree(self, archived: Path) -> str:
        """Commit the disposable frozen archive into its exact synthetic Git pin."""
        adk = self.root / "agent-dev-kit"
        relative = archived.relative_to(adk).as_posix()

        def git(*args: str) -> str:
            result = subprocess.run(["git", "-C", str(adk), *args],
                                    check=True, capture_output=True, text=True)
            return result.stdout.strip()

        manifest = adk / "manifest.json"
        manifest.write_text('{"version":"fixture-v1"}\n', encoding="utf-8")
        git("add", "--", relative, "manifest.json")
        subprocess.run(
            ["git", "-C", str(adk), "-c", "user.name=Synthetic Fixture",
             "-c", "user.email=fixture@example.invalid",
             "commit", "-qm", "Pin synthetic historical archive"],
            check=True, capture_output=True,
        )
        head = git("rev-parse", "HEAD")
        subtree = git("rev-parse", "HEAD^{tree}")
        manifest_blob = git("rev-parse", "HEAD:manifest.json")
        subprocess.run(
            ["git", "-C", str(self.root), "update-index", "--add", "--cacheinfo",
             "160000," + head + ",agent-dev-kit"], check=True, capture_output=True,
        )
        (self.root / "adk.lock").write_text(
            "schema=llm-agent-adk-lock/v2\n"
            "agent-dev-kit.version=fixture-v1\n"
            f"agent-dev-kit.commit={head}\n"
            f"agent-dev-kit.tree={subtree}\n"
            f"agent-dev-kit.manifest_blob={manifest_blob}\n"
            "updated_at=2026-10-28\n", encoding="utf-8",
        )
        interface = self.root / "manifests/adk_interface.lock.json"
        interface.parent.mkdir(parents=True, exist_ok=True)
        interface.write_text(json.dumps({
            "schema": "llm-agent-adk-interface-lock/v1", "version": "fixture-v1",
            "commit": head, "tree": subtree, "manifest_blob": manifest_blob,
        }) + "\n", encoding="utf-8")
        subprocess.run(
            ["git", "-C", str(self.root), "add", "--", "adk.lock",
             "manifests/adk_interface.lock.json"], check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "-C", str(self.root), "-c", "user.name=Synthetic Fixture",
             "-c", "user.email=fixture@example.invalid",
             "commit", "-qm", "Commit synthetic Root ADK pin and locks"],
            check=True, capture_output=True,
        )
        return git("rev-parse", "HEAD:" + relative)

    def test_staged_root_gitlink_cannot_replace_committed_root_adk_pin(self) -> None:
        """An ADK commit B with the same archive tree is still not Root HEAD A."""
        first, *_ = self.reviewed_changes()
        archived = self.archive_fixture(first)
        frozen_tree = followup.FROZEN_ARCHIVE_GIT_TREES[first.name]
        adk = self.root / "agent-dev-kit"

        def git(directory: Path, *args: str) -> str:
            result = subprocess.run(["git", "-C", str(directory), *args],
                                    check=True, capture_output=True, text=True)
            return result.stdout.strip()

        committed_root_pin = git(self.root, "rev-parse", "HEAD:agent-dev-kit")
        self.assertEqual(committed_root_pin, git(adk, "rev-parse", "HEAD"))
        with patch.dict(followup.FROZEN_ARCHIVE_GIT_TREES, {first.name: frozen_tree}):
            self.assertTrue(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))
            subprocess.run(
                ["git", "-C", str(adk), "-c", "user.name=Synthetic Fixture",
                 "-c", "user.email=fixture@example.invalid",
                 "commit", "--allow-empty", "-qm", "Alternate ADK source B, identical archive"],
                check=True, capture_output=True,
            )
            alternate_head = git(adk, "rev-parse", "HEAD")
            self.assertNotEqual(committed_root_pin, alternate_head)
            self.assertEqual(frozen_tree, git(
                adk, "rev-parse", "HEAD:" + archived.relative_to(adk).as_posix()
            ))
            subprocess.run(
                ["git", "-C", str(self.root), "update-index", "--add", "--cacheinfo",
                 "160000," + alternate_head + ",agent-dev-kit"],
                check=True, capture_output=True,
            )
            self.assertEqual(committed_root_pin, git(self.root, "rev-parse", "HEAD:agent-dev-kit"))
            self.assertFalse(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))

    def test_dirty_root_adk_lock_cannot_claim_original_git_pin(self) -> None:
        first, *_ = self.reviewed_changes()
        archived = self.archive_fixture(first)
        tree = followup.FROZEN_ARCHIVE_GIT_TREES[first.name]
        with patch.dict(followup.FROZEN_ARCHIVE_GIT_TREES, {first.name: tree}):
            self.assertTrue(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))
            lock = self.root / "adk.lock"
            original = lock.read_bytes()
            lock.write_bytes(original + b"extra=forged\\n")
            self.assertFalse(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))
            lock.write_bytes(original)
            self.assertTrue(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))
            subprocess.run(
                ["git", "-C", str(self.root), "add", "--", "adk.lock"],
                check=True, capture_output=True,
            )
            self.assertTrue(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))
            lock.write_bytes(original + b"other=malformed\\n")
            subprocess.run(
                ["git", "-C", str(self.root), "add", "--", "adk.lock"],
                check=True, capture_output=True,
            )
            lock.write_bytes(original)
            self.assertFalse(followup._frozen_archive_matches_pinned_git(
                self.root, archived, first.name
            ))

    def test_original_archives_match_exact_pinned_git_tree(self) -> None:
        root = Path(__file__).resolve().parents[1]
        adk = root / "agent-dev-kit"
        if not (adk / ".git").exists():
            self.skipTest("ADK source is not initialized by this job")
        for change in followup.CHANGE_IDS:
            with self.subTest(change=change):
                archived = adk / "docs/changes/archive" / ("20261020-" + change)
                self.assertTrue(followup._frozen_archive_matches_pinned_git(
                    root, archived, change
                ))

    def test_frozen_archive_bytes_reject_unreferenced_provenance_and_index_drift(self) -> None:
        first, *_ = self.reviewed_changes()
        archived = self.archive_fixture(first)
        extra = archived / "unreferenced-material.md"
        extra.write_text("Synthetic unreviewed historical document.\n", encoding="utf-8")
        frozen_tree = self.pin_synthetic_archive_tree(archived)
        with patch.dict(followup.FROZEN_ARCHIVE_GIT_TREES, {first.name: frozen_tree}):
            def matches():
                return followup._frozen_archive_matches_pinned_git(self.root, archived, first.name)

            self.assertTrue(matches())
            provenance = archived / "provenance.md"
            original = provenance.read_text(encoding="utf-8")
            for mutation in (
                original.replace("archived_by: ai/fixture-coordinator",
                                 "archived_by: ai/forged-archiver"),
                original + "- repository_head: " + "a" * 40 + "\n",
            ):
                provenance.write_text(mutation, encoding="utf-8")
                self.assertFalse(matches())
            provenance.write_text(original, encoding="utf-8")
            self.assertTrue(matches())

            for file in (extra, archived / "state.yaml", archived / "review-report.md"):
                previous = file.read_bytes() if file.exists() else None
                file.write_text("forged non-referenced content\n", encoding="utf-8")
                self.assertFalse(matches())
                if previous is None:
                    file.unlink()
                else:
                    file.write_bytes(previous)
                self.assertTrue(matches())

            unknown = archived / "unexpected.md"
            unknown.write_text("untracked\n", encoding="utf-8")
            self.assertFalse(matches())
            unknown.unlink()
            self.assertTrue(matches())

            previous = extra.read_bytes()
            extra.unlink()
            extra.symlink_to(archived / "provenance.md")
            self.assertFalse(matches())
            extra.unlink()
            extra.write_bytes(previous)
            self.assertTrue(matches())

            extra.write_text("staged-only content\n", encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(self.root / "agent-dev-kit"), "add", "--",
                 extra.relative_to(self.root / "agent-dev-kit").as_posix()],
                check=True, capture_output=True,
            )
            extra.write_bytes(previous)
            self.assertFalse(matches())

    def test_successful_delegated_review_does_not_bypass_frozen_archive(self) -> None:
        """A current-validator PASS must not authorize altered historical bytes."""
        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        unreferenced = archive / "unreferenced-original.md"
        unreferenced.write_text("Synthetic historical document outside review refs.\n", encoding="utf-8")
        tree = self.pin_synthetic_archive_tree(archive)
        with patch.dict(followup.FROZEN_ARCHIVE_GIT_TREES, {first.name: tree}):
            baseline = followup._review_inventory(self.root)
            self.assertEqual(baseline["scan_status"], "complete", baseline)
            self.assertTrue(baseline["result"]["changes"][0]["review_verified"])
            self.assertTrue(baseline["result"]["delegated_review_verified"])

            original = unreferenced.read_bytes()
            unreferenced.write_bytes(b"modified original outside review evidence\n")
            changed = followup._review_inventory(self.root)
            self.assertEqual(changed["scan_status"], "error")
            self.assertFalse(changed["result"]["changes"][0]["review_verified"])
            unreferenced.write_bytes(original)

            # Replacing a policy-valid review receipt and updating its
            # provenance is not a renewal of the original frozen archive.
            record_path = archive / "review-evidence.json"
            record = json.loads(record_path.read_text(encoding="utf-8"))
            record["limitations"].append("Synthetic new historical review record.")
            write_json(record_path, record)
            prov = archive / "provenance.md"
            prov.write_text(prov.read_text(encoding="utf-8").replace(
                "review_record_sha256: " + followup.FROZEN_ARCHIVED_REVIEW_SHA256[first.name],
                "review_record_sha256: " + hashlib.sha256(record_path.read_bytes()).hexdigest(),
            ), encoding="utf-8")
            replaced = followup._review_inventory(self.root)
            self.assertEqual(replaced["scan_status"], "error")
            self.assertFalse(replaced["result"]["changes"][0]["review_verified"])

    def test_archive_chmod_only_and_untracked_empty_directory_are_rejected(self) -> None:
        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        self.assertTrue(followup._frozen_archive_matches_pinned_git(
            self.root, archive, first.name
        ))
        file = archive / "provenance.md"
        original_mode = stat.S_IMODE(file.lstat().st_mode)
        try:
            file.chmod(original_mode | stat.S_IXUSR)
            self.assertFalse(followup._frozen_archive_matches_pinned_git(
                self.root, archive, first.name
            ))
            self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")
        finally:
            file.chmod(original_mode)
        self.assertTrue(followup._frozen_archive_matches_pinned_git(
            self.root, archive, first.name
        ))
        unexpected = archive / "untracked-empty" / "nested"
        unexpected.mkdir(parents=True)
        self.assertFalse(followup._frozen_archive_matches_pinned_git(
            self.root, archive, first.name
        ))
        self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")
        unexpected.rmdir()
        unexpected.parent.rmdir()
        self.assertTrue(followup._frozen_archive_matches_pinned_git(
            self.root, archive, first.name
        ))

    def test_frozen_historical_validator_drift_never_renews_a_review(self) -> None:
        from agent_dev_kit.review_evidence import ReviewEvidenceError
        from tools.control_plane.adk_interface import validate_delegated_review

        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        pinned_tree = followup.FROZEN_ARCHIVE_GIT_TREES[first.name]
        record_path = archive / "review-evidence.json"
        record = json.loads(record_path.read_text(encoding="utf-8"))
        digest = hashlib.sha256(record_path.read_bytes()).hexdigest()

        def stale(*args, **kwargs):
            if Path(args[1]) == record_path:
                raise ReviewEvidenceError("review validator source identity changed")
            return validate_delegated_review(*args, **kwargs)

        legacy_fixture = {
            "schema": followup.HISTORICAL_REVIEW_SCHEMA,
            "source": {"tag": "v8.0.36", "commit": "42ae95d146ceb441ff91ea33dbbed581c33de305"},
            "records": {
                name: {"record_sha256": digest if name == first.name
                       else followup.FROZEN_ARCHIVED_REVIEW_SHA256[name],
                       "spec": "pass", "quality": "pass", "reviewed_at": record["reviewed_at"]}
                for name in followup.CHANGE_IDS
            },
            "historical_review_verified": True, "current_source_review_verified": False,
            "release_authorized": False,
        }
        with patch.dict(followup.FROZEN_ARCHIVED_REVIEW_SHA256, {first.name: digest}), \
                patch.dict(followup.FROZEN_ARCHIVE_GIT_TREES, {first.name: pinned_tree}), \
                patch.object(followup, "FROZEN_ARCHIVED_VALIDATOR_SHA256", record["validator_sha256"]), \
                patch.object(followup, "verify_original_reviews", return_value=legacy_fixture) as original, \
                patch("tools.control_plane.adk_interface.validate_delegated_review", side_effect=stale):
            item = followup._review_inventory(self.root)
            original.assert_called_once()
            self.assertEqual(item["scan_status"], "error", item)
            self.assertFalse(item["qualification_ready"])
            self.assertFalse(item["result"]["delegated_review_verified"])
            # Only one of three packages is archived in this synthetic
            # mixed fixture; the original 3/3 Git result cannot make the
            # current materialized inventory complete.
            self.assertFalse(item["result"]["historical_review_verified"])
            self.assertEqual(item["result"]["changes"][0]["reason"], "historical-reviewed")
            self.assertTrue(item["result"]["changes"][0]["historical_review_verified"])
            self.assertFalse(item["result"]["changes"][0]["review_verified"])
            self.assertFalse(item["result"]["changes"][0]["current_source_review_verified"])
            self.assertEqual(item["result"]["changes"][0]["historical_review_record_sha256"], digest)
            with patch.object(followup, "verify_original_reviews", side_effect=ValueError("missing pinned original")):
                failed = followup._review_inventory(self.root)
                self.assertEqual(failed["scan_status"], "error")
                self.assertFalse(failed["qualification_ready"])

            source = archive / "requirements.md"
            before = source.read_text(encoding="utf-8")
            source.write_text("tampered source\n", encoding="utf-8")
            self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")
            source.write_text(before, encoding="utf-8")
            provenance = archive / "provenance.md"
            provenance.write_text(provenance.read_text(encoding="utf-8") +
                                  "- review_verdict: pass\n", encoding="utf-8")
            self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")

    def test_validator_drift_exception_cannot_mask_other_archive_failures(self) -> None:
        from agent_dev_kit.review_evidence import ReviewEvidenceError
        from tools.control_plane.adk_interface import validate_delegated_review

        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        record_path = archive / "review-evidence.json"
        record = json.loads(record_path.read_text(encoding="utf-8"))
        digest = hashlib.sha256(record_path.read_bytes()).hexdigest()

        def incorrect(*args, **kwargs):
            if Path(args[1]) == record_path:
                raise ReviewEvidenceError("review source or evidence digest does not match")
            return validate_delegated_review(*args, **kwargs)

        with patch.dict(followup.FROZEN_ARCHIVED_REVIEW_SHA256, {first.name: digest}), \
                patch.object(followup, "FROZEN_ARCHIVED_VALIDATOR_SHA256", record["validator_sha256"]), \
                patch("tools.control_plane.adk_interface.validate_delegated_review", side_effect=incorrect):
            self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")

        with patch.dict(followup.FROZEN_ARCHIVED_REVIEW_SHA256, {first.name: "0" * 64}), \
                patch.object(followup, "FROZEN_ARCHIVED_VALIDATOR_SHA256", record["validator_sha256"]), \
                patch("tools.control_plane.adk_interface.validate_delegated_review",
                      side_effect=ReviewEvidenceError("review validator source identity changed")):
            self.assertEqual(followup._review_inventory(self.root)["scan_status"], "error")

    def test_archive_requires_matching_unambiguous_provenance(self) -> None:
        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        path = archive / "provenance.md"
        baseline = path.read_text(encoding="utf-8")
        variants = (
            "", baseline.replace("source_stage: review-passed", "source_stage: verified"),
            baseline.replace("review_verdict: pass", "review_verdict: fail"),
            baseline.replace("reviewer_id: fixture-ai-reviewer", "reviewer_id: ai/wrong-reviewer"),
            baseline.replace("review_record_sha256: ", "review_record_sha256: 0"),
            baseline + "- review_verdict: pass\n",
        )
        for value in variants:
            with self.subTest(value=value):
                path.write_text(value, encoding="utf-8")
                item = followup._review_inventory(self.root)
                self.assertEqual(item["scan_status"], "error")
                self.assertFalse(item["qualification_ready"])
        path.unlink()
        self.assertFalse(followup._review_inventory(self.root)["qualification_ready"])

    def test_archive_provenance_cannot_predate_review_or_claim_the_future(self) -> None:
        first, *_ = self.reviewed_changes()
        archive = self.archive_fixture(first)
        path = archive / "provenance.md"
        baseline = path.read_text(encoding="utf-8")
        record = json.loads((archive / "review-evidence.json").read_text(encoding="utf-8"))
        reviewed = datetime.fromisoformat(record["reviewed_at"].replace("Z", "+00:00"))
        for value in (reviewed - timedelta(seconds=1), datetime.now(UTC) + timedelta(days=1)):
            path.write_text(baseline.replace("archived_at: " + record["reviewed_at"],
                                             "archived_at: " + value.isoformat().replace("+00:00", "Z")), encoding="utf-8")
            self.assertFalse(followup._review_inventory(self.root)["qualification_ready"])

    def test_wrong_historical_head_cannot_reuse_a_valid_receipt(self) -> None:
        first, *_ = self.reviewed_changes()
        path = first / "review-evidence.json"
        value = json.loads(path.read_text())
        value["target"]["head_commit"] = "b" * 40
        write_json(path, value)
        item = followup._review_inventory(self.root)
        self.assertFalse(item["qualification_ready"])
        self.assertEqual(item["scan_status"], "error")

    def test_wrong_base_or_empty_diff_cannot_reuse_a_historical_review(self) -> None:
        first, *_ = self.reviewed_changes()
        record_path = first / "review-evidence.json"
        record = json.loads(record_path.read_text(encoding="utf-8"))
        for base in ("c" * 40, followup.CHANGE_HEADS[first.name]):
            with self.subTest(base=base):
                record["target"]["base_commit"] = base
                write_json(record_path, record)
                result = followup._review_inventory(self.root)
                self.assertEqual(result["scan_status"], "error")
                self.assertFalse(result["qualification_ready"])

    def test_an_arbitrary_patch_cannot_claim_the_fixed_historical_target(self) -> None:
        first, *_ = self.reviewed_changes()
        record_path = first / "review-evidence.json"
        record = json.loads(record_path.read_text(encoding="utf-8"))
        patch = first / "evidence/original.patch"
        patch.write_text("diff --git a/unrelated b/unrelated\n+synthetic unrelated\n", encoding="utf-8")
        digest = hashlib.sha256(patch.read_bytes()).hexdigest()
        record["target"]["original_patch_sha256"] = digest
        for source in record["sources"]:
            if source["path"] == "evidence/original.patch":
                source["sha256"] = digest
        write_json(record_path, record)
        result = followup._review_inventory(self.root)
        self.assertEqual(result["scan_status"], "error")
        self.assertFalse(result["qualification_ready"])

    def test_review_does_not_skip_the_canonical_lifecycle(self) -> None:
        first, *_ = self.reviewed_changes()
        (first / "state.yaml").write_text("stage: verified\n", encoding="utf-8")
        item = followup._review_inventory(self.root)
        self.assertEqual(item["scan_status"], "complete")
        self.assertFalse(item["qualification_ready"])
        self.assertIn("canonical-review-lifecycle-incomplete", item["remaining_evidence"][0])

    def test_review_input_snapshot_includes_authorization_and_all_declared_inputs(self) -> None:
        first, *_ = self.reviewed_changes()
        paths = followup._review_input_paths(self.root, followup._review_paths(self.root))
        self.assertIn("agent-dev-kit/authorization.txt", paths)
        self.assertIn((first / "requirements.md").relative_to(self.root).as_posix(), paths)
        self.assertIn((first / "review-evidence-observations.txt").relative_to(self.root).as_posix(), paths)
        receipt = first / "review-evidence.json"
        value = json.loads(receipt.read_text())
        value["sources"][0]["path"] = "../outside"
        write_json(receipt, value)
        with self.assertRaises(ValueError):
            followup._review_input_paths(self.root, followup._review_paths(self.root))

    def test_scope_aware_readiness_does_not_turn_m5_diagnostics_into_certification(self) -> None:
        self.reviewed_changes()
        results = []
        for check in self.checks:
            data = blocked(check)
            if check.id == "root-236":
                results.append(completed(check, data, 2))
                continue
            if check.id in ("root-154", "adk-153"):
                data["effect_evidence_ready" if check.id == "root-154" else "native_verified"] = True
                data["terminal_status"] = "ready"
            elif check.id == "root-67":
                data["status"] = "pass"
            else:
                data["overall_status"] = "pass"
            results.append(completed(check, data, 0))
        with patch.object(followup, "_snapshot", return_value=self.source), \
                patch.object(followup, "run_bounded", side_effect=results):
            report = followup.collect(self.root)
        self.assertTrue(report["required_qualification_ready"], report)
        self.assertFalse(report["qualification_all_ready"])
        self.assertFalse(report["items"][0]["qualification_ready"])
        self.assertFalse(report["release_authorized"])

    def test_effect_and_longitudinal_review_snapshot_uses_root_source_authority(self) -> None:
        self.reviewed_changes()
        source = self.root / "manifests/fixture-source.json"
        write_json(source, {"synthetic": True})
        records = []
        for scope, subject in (("effect-value-review", "fixture-campaign"), ("longitudinal-review", "lta-04/fixture-pilot")):
            path = self.root / "reports" / scope / "review.json"
            review_fixture(self.root, path, subject=subject, scope=scope, sources=[source],
                           reviewed_at=datetime.now(UTC), policy_root=self.root / "agent-dev-kit")
            records.append(path)
        write_json(self.root / "reports/runtime-evidence/effect-value/evidence-index.json",
                   {"entries": [{"review_evidence_path": records[0].relative_to(self.root).as_posix()}]})
        write_json(self.root / "reports/long-term-assets/longitudinal-operation-current.json",
                   {"review": {"mode": "owner-delegated-ai", "evidence_path": records[1].relative_to(self.root).as_posix()}})
        paths = followup._review_input_paths(self.root, followup._review_paths(self.root))
        self.assertIn("manifests/fixture-source.json", paths)
        self.assertNotIn("agent-dev-kit/manifests/fixture-source.json", paths)
        for path in records:
            self.assertIn(path.relative_to(self.root).as_posix(), paths)
            self.assertIn(path.with_name("review-observations.txt").relative_to(self.root).as_posix(), paths)

    def test_m5_cannot_cross_read_only_or_qualification_boundary(self) -> None:
        for field, value in (("read_only", False), ("write_performed", True), ("model_invocations", 1),
                             ("software_m5_certified", True), ("release_authorized", True)):
            with self.subTest(field=field):
                data = blocked(self.checks[0])
                data[field] = value
                self.assertEqual(self.run_item(self.checks[0], data)["scan_status"], "error")

    def test_harness_partial_and_not_applicable_do_not_refresh_human_dates(self) -> None:
        data = blocked(self.checks[4])
        data["dimensions"].append({"dimension_id": "tool_boundary", "status": "not-applicable",
                                   "last_verified_at": "2026-07-18", "blockers": []})
        item = self.run_item(self.checks[4], data)
        self.assertEqual(item["scan_status"], "complete")
        self.assertFalse(item["qualification_ready"])
        self.assertEqual(item["result"]["dimensions"][0]["last_verified_at"], "2026-07-18")
        self.assertEqual(item["remaining_evidence"], ["context_legibility:stale_last_verified_at"])

    def test_incomplete_harness_scan_is_error(self) -> None:
        for change in ({"truncated": True}, {"errors": ["read-failed"]}):
            data = blocked(self.checks[4])
            data["scan"].update(change)
            self.assertEqual(self.run_item(self.checks[4], data)["scan_status"], "error")

    def test_report_budget_error_retains_six_exits_without_raw_results(self) -> None:
        budget = len(followup._json(self.collect_blocked()))
        with patch.object(followup, "MAX_REPORT", budget):
            report = self.collect_blocked()
        self.assertEqual(report["scan_status"], "error")
        self.assertIn("aggregate-report-byte-budget-exceeded", report["errors"])
        self.assertEqual(len(report["items"]), 6)
        self.assertTrue(all(item["result"] is None for item in report["items"]))
        self.assertEqual([item["command_exit"] for item in report["items"]], [2, 2, 2, 2, 2, None])
        self.assertLessEqual(len(followup._json(report)) + 1, budget)

    def test_report_budget_bounds_large_source_inventory_and_preserves_identity(self) -> None:
        source = copy.deepcopy(self.source)
        source["inputs"] = {
            "synthetic/{:04d}/".format(index) + "x" * 144 + "/" + "y" * 143: {"present": False}
            for index in range(8192)
        }
        source["inputs"]["synthetic/present.json"] = {
            "present": True, "bytes": 17, "sha256": "d" * 64,
        }
        source["sha256"] = followup._digest({"git": source["git"], "inputs": source["inputs"]})
        original = copy.deepcopy(source)
        report = self.collect_blocked([source, source])
        self.assertLessEqual(len(followup._json(report)) + 1, followup.MAX_REPORT)
        self.assertEqual(report["scan_status"], "error")
        self.assertTrue(report["source_consistent"])
        self.assertTrue(report["report_truncated"])
        self.assertEqual(report["input_digest"], original["sha256"])
        self.assertEqual(source, original, "summarizing must not mutate the observed snapshot")
        for key in ("source_before", "source_after"):
            snapshot = report[key]
            self.assertEqual(snapshot["git"], original["git"])
            self.assertEqual(snapshot["sha256"], original["sha256"])
            self.assertNotIn("inputs", snapshot)
            self.assertTrue(snapshot["inputs_omitted"])
            self.assertEqual(snapshot["input_count"], 8193)
            self.assertEqual(snapshot["input_file_bytes"], 17)
        self.assertEqual([item["command_exit"] for item in report["items"]], [2, 2, 2, 2, 2, None])
        self.assertTrue(all(item["scan_status"] == "error" and not item["qualification_ready"]
                            for item in report["items"]))
        for item, check in zip(report["items"], self.checks, strict=False):
            raw = completed(check, blocked(check)).stdout
            self.assertEqual(item["stdout"], {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
            self.assertIsNone(item["result"])
        for key in ("qualification_all_ready", "required_qualification_ready", "release_authorized",
                    "may_fill_owner", "provider_execution_performed"):
            self.assertIs(report[key], False)
        output = io.StringIO()
        with patch.object(followup, "collect", return_value=report), redirect_stdout(output):
            code = followup.main(["--root", str(self.root), "--summary-json"])
        self.assertEqual(code, 1)
        self.assertLessEqual(len(output.getvalue().encode("utf-8")), followup.MAX_REPORT)
        self.assertEqual(json.loads(output.getvalue()), report)

    def test_report_budget_counts_utf8_and_final_newline_at_exact_boundary(self) -> None:
        report = self.collect_blocked()
        report["items"][0]["remaining_evidence"] = ["真实证据仍缺失"]
        original = copy.deepcopy(report)
        encoded = followup._json(report)
        self.assertGreater(len(encoded), len(encoded.decode("utf-8")))
        with patch.object(followup, "MAX_REPORT", len(encoded) + 1):
            self.assertIs(followup._bounded_report(report), report)
        self.assertEqual(report, original)
        with patch.object(followup, "MAX_REPORT", len(encoded)):
            limited = followup._bounded_report(report)
        self.assertEqual(limited["scan_status"], "error")
        self.assertLessEqual(len(followup._json(limited)) + 1, len(encoded))

    def test_report_budget_compacts_large_metadata_without_losing_actual_exits(self) -> None:
        results = [completed(check, blocked(check)) for check in self.checks]
        data = blocked(self.checks[1])
        data["blockers"] = ["界" * 1024 for _ in range(32)]
        results[1] = completed(self.checks[1], data)
        with patch.object(followup, "MAX_REPORT", 16 * 1024), \
                patch.object(followup, "_snapshot", return_value=self.source), \
                patch.object(followup, "run_bounded", side_effect=results):
            report = followup.collect(self.root)
        self.assertLessEqual(len(followup._json(report)) + 1, 16 * 1024)
        self.assertEqual(report["scan_status"], "error")
        self.assertIn("aggregate-report-byte-budget-exceeded", report["errors"])
        self.assertEqual([item["command_exit"] for item in report["items"]], [2, 2, 2, 2, 2, None])
        self.assertEqual(report["items"][1]["stdout"]["sha256"], hashlib.sha256(results[1].stdout).hexdigest())
        self.assertTrue(report["items"][1]["diagnostics_omitted"])
        self.assertEqual(report["items"][1]["remaining_evidence"], [])
        self.assertFalse(report["release_authorized"])

    def test_report_budget_also_bounds_invalid_source_early_return(self) -> None:
        with patch.object(followup, "MAX_REPORT", 12 * 1024), \
                patch.object(followup, "_collect_command") as runner:
            report = followup.collect(self.root / ("x" * 4096))
        runner.assert_not_called()
        self.assertLessEqual(len(followup._json(report)) + 1, 12 * 1024)
        self.assertEqual(report["scan_status"], "error")
        self.assertIn("source-before-invalid", report["errors"])
        self.assertIn("aggregate-report-byte-budget-exceeded", report["errors"])
        self.assertIsNone(report["input_digest"])
        self.assertEqual(len(report["items"]), 6)
        self.assertTrue(all(item["execution_status"] == "not-run" and item["command_exit"] is None
                            for item in report["items"]))

    def test_report_budget_rejects_impossibly_small_internal_limit(self) -> None:
        report = self.collect_blocked()
        with patch.object(followup, "MAX_REPORT", 128), \
                self.assertRaisesRegex(ValueError, "cannot contain the minimal diagnostic"):
            followup._bounded_report(report)

    def test_cli_exit_is_scan_status_not_qualification_readiness(self) -> None:
        for status, expected in (("complete", 0), ("error", 1)):
            report = {"scan_status": status, "qualification_all_ready": False}
            output = io.StringIO()
            with patch.object(followup, "collect", return_value=report), redirect_stdout(output):
                code = followup.main(["--root", str(self.root), "--summary-json"])
            self.assertEqual(code, expected)
            self.assertEqual(json.loads(output.getvalue()), report)

    def test_cli_has_no_simulated_time_or_output_mutation_options(self) -> None:
        for option in ("--as-of", "--output"):
            with patch.object(followup, "collect") as collector, redirect_stderr(io.StringIO()), \
                    self.assertRaises(SystemExit) as raised:
                followup.main([option, "test-only"])
            self.assertEqual(raised.exception.code, 2)
            collector.assert_not_called()


if __name__ == "__main__":
    unittest.main()
