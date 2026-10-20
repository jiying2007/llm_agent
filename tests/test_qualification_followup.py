"""Synthetic collector contracts; these fixtures are never qualification evidence."""
from __future__ import annotations

import copy
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

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
        with patch.object(followup, "_snapshot", side_effect=snapshots or [self.source, self.source]), \
                patch.object(followup, "run_bounded", side_effect=results):
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
                    "provider_execution_performed"):
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

    def test_human_inventory_does_not_interpret_stage_or_review_content_as_approval(self) -> None:
        change = self.root / "agent-dev-kit/docs/changes" / followup.CHANGE_IDS[0]
        change.mkdir(parents=True)
        (change / "state.yaml").write_text("stage: reviewed\nowner_verdict: approved\n", encoding="utf-8")
        (change / "review-report.md").write_text(CANARY, encoding="utf-8")
        item = followup._review_inventory(self.root)
        self.assertEqual(item["status"], "human-review-required")
        self.assertFalse(item["qualification_ready"])
        self.assertFalse(item["result"]["owner_verdict_verified"])
        self.assertFalse(item["result"]["semantic_review_performed"])
        self.assertIsNone(item["command_exit"])
        self.assertNotIn(CANARY, json.dumps(item))
        self.assertTrue(item["result"]["changes"][0]["files"]["review-report.md"]["present"])
        self.assertFalse(item["result"]["changes"][1]["files"]["review-report.md"]["present"])

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
        self.assertEqual(item["result"]["stages"]["promotion_signature"]["status"], "blocked")

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
        with patch.object(followup, "MAX_REPORT", 128):
            report = self.collect_blocked()
        self.assertEqual(report["scan_status"], "error")
        self.assertIn("aggregate-report-byte-budget-exceeded", report["errors"])
        self.assertEqual(len(report["items"]), 6)
        self.assertTrue(all(item["result"] is None for item in report["items"]))
        self.assertEqual([item["command_exit"] for item in report["items"]], [2, 2, 2, 2, 2, None])

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
