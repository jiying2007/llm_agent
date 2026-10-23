"""Behavioral regressions for Git impact, gate process budgets and pass caches."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from tools.control_plane.gate_runner import run_profile
from tools.control_plane.impact import _git_changed_paths, calculate_impact
from tools.control_plane.process_budget import ProcessBudgetError, run_bounded
from tools.control_plane.receipts import bind_receipt

REPOSITORY = Path(__file__).resolve().parents[1]


def git(root: Path, *args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(root), *args], check=True, capture_output=True, timeout=30,
    ).stdout


def initialize(root: Path) -> None:
    git(root, "init", "-q")
    git(root, "config", "user.name", "Gate Boundary Test")
    git(root, "config", "user.email", "gate-boundary@example.invalid")
    git(root, "config", "core.quotePath", "true")


def commit(root: Path) -> str:
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "fixture")
    return git(root, "rev-parse", "HEAD").decode().strip()


def gate(argv: list[str], *, cache: str = "disabled", inputs: tuple[str, ...] = ()) -> dict:
    return {
        "owner": "boundary-fixture", "side_effect": "none", "depends_on": [],
        "inputs": list(inputs), "outputs": [], "cache_policy": cache,
        "argv": argv, "timeout_seconds": 1, "evidence_class": "test",
    }


class TemporaryRepository(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="llm-gate-boundary-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        initialize(self.root)
        (self.root / "manifests").mkdir()

    def manifest(self, gates: dict) -> None:
        (self.root / "manifests/gates.json").write_text(
            json.dumps({"schema": "llm-agent-gates/v2", "gates": gates,
                        "profiles": {"fixture": list(gates)}}), encoding="utf-8",
        )
        commit(self.root)


class ImpactPathTests(TemporaryRepository):
    def setUp(self) -> None:
        super().setUp()
        shutil.copyfile(REPOSITORY / "manifests/gates.json", self.root / "manifests/gates.json")
        self.base = commit(self.root)

    def test_real_git_paths_preserve_literal_names_and_trigger_owned_gates(self) -> None:
        owned = [
            "tools/中文.py", "tools/with space.py", 'tools/with"quote.py',
            "tools/with\ttab.py", "tools/with\nnewline.py", "tools/ leading.py",
            "tools/trailing.py ", "tools/literal\\slash.py",
        ]
        unowned = [" tools/not-owned.py", "tools\\not-owned.py"]
        for name in owned + unowned:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture\n", encoding="utf-8")
        head = commit(self.root)

        changed = _git_changed_paths(self.root, self.base, head, "two-dot")
        self.assertEqual(set(owned + unowned), set(changed))
        for name in owned:
            with self.subTest(name=name):
                result = calculate_impact(self.root, [name], group="integration-deep")
                self.assertTrue(result["required"], result)
                self.assertIn("root-regression", result["group_gates"])
                self.assertEqual([name], result["changed_paths"])
        for name in unowned:
            with self.subTest(name=name):
                result = calculate_impact(self.root, [name], group="integration-deep")
                self.assertFalse(result["required"], result)

    def test_rename_out_of_owned_directory_keeps_old_path_in_impact(self) -> None:
        (self.root / "tools").mkdir()
        (self.root / "tools/before.py").write_text("same content\n", encoding="utf-8")
        base = commit(self.root)
        (self.root / "docs").mkdir()
        (self.root / "tools/before.py").rename(self.root / "docs/after.py")
        head = commit(self.root)
        changed = _git_changed_paths(self.root, base, head, "two-dot")
        self.assertEqual(["docs/after.py", "tools/before.py"], changed)
        self.assertTrue(calculate_impact(self.root, changed, group="integration-deep")["required"])

    def test_git_failure_never_becomes_an_empty_change(self) -> None:
        for base, head in (("", "HEAD"), ("f" * 40, "HEAD"), (self.base, "missing-head")):
            with self.subTest(base=base, head=head), self.assertRaises(ValueError):
                _git_changed_paths(self.root, base, head, "two-dot")

    def test_cli_rejects_empty_base_and_preserves_changed_file_mode(self) -> None:
        command = [sys.executable, "-m", "tools.control_plane.cli", "impact",
                   "--root", str(self.root), "--summary-json"]
        with self.subTest(mode="empty-base"):
            result = subprocess.run(
                [*command, "--base", "", "--head", "HEAD"], cwd=REPOSITORY,
                check=False, capture_output=True, text=True, timeout=10,
            )
            self.assertNotEqual(0, result.returncode, result.stdout)
            self.assertEqual("", result.stdout)
            self.assertIn("Git impact comparison requires both base and head", result.stderr)
        with self.subTest(mode="changed-file-only"):
            result = subprocess.run(
                [*command, "--changed-file", "tools/中文.py"], cwd=REPOSITORY,
                check=False, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertTrue(receipt["required"], receipt)
            self.assertEqual(["tools/中文.py"], receipt["changed_paths"])

    @unittest.skipUnless(os.name == "posix", "raw Git filename bytes")
    def test_non_utf8_git_path_fails_closed(self) -> None:
        (self.root / "tools").mkdir()
        descriptor = os.open(os.fsencode(self.root) + b"/tools/\xff.py", os.O_CREAT | os.O_WRONLY, 0o600)
        os.close(descriptor)
        head = commit(self.root)
        with self.assertRaises(ValueError):
            _git_changed_paths(self.root, self.base, head, "two-dot")


class GateProcessTests(TemporaryRepository):
    def execute(self, code: str, *, failure_lines: int = 80) -> dict:
        self.manifest({"process": gate([sys.executable, "-c", code])})
        result = run_profile(self.root, "fixture", set(), failure_lines)
        self.assertEqual(result["receipt_sha256"], bind_receipt(result)["receipt_sha256"])
        return result

    def test_non_object_configuration_fails_with_a_configuration_error(self) -> None:
        for value in (None, [], "invalid", 7):
            with self.subTest(value=value):
                (self.root / "manifests/gates.json").write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "gate manifest root must be an object"):
                    run_profile(self.root, "fixture", set(), 10)

    def test_success_nonzero_and_both_output_streams_are_preserved(self) -> None:
        result = self.execute("import sys;print('stdout');print('stderr',file=sys.stderr);sys.exit(7)")
        item = result["gates"][0]
        self.assertEqual(("fail", 7, "nonzero-exit"),
                         (item["status"], item["exit_code"], item["failure_reason"]))
        self.assertIn("stdout", item["output_tail"])
        self.assertIn("stderr", item["output_tail"])

    def test_output_budget_fails_instead_of_returning_a_truncated_pass(self) -> None:
        for stream, byte_count in ((1, 2 * 1024 * 1024 + 1), (2, 64 * 1024 + 1)):
            with self.subTest(stream=stream):
                result = self.execute(f"import os;os.write({stream}, b'x' * {byte_count})")
                item = result["gates"][0]
                self.assertEqual(("fail", "output-budget"), (item["status"], item["failure_reason"]))
                self.assertIsNone(item["exit_code"])
                self.assertLessEqual(sum(len(line.encode()) for line in item["output_tail"]),
                                     2 * 1024 * 1024 + 64 * 1024 + 100)

    @unittest.skipUnless(os.name == "posix", "POSIX process-group cleanup")
    def test_timeout_stops_descendant_and_preserves_bounded_diagnostics(self) -> None:
        marker = self.root / "late-child.txt"
        child = "import pathlib,sys,time;time.sleep(1.5);pathlib.Path(sys.argv[1]).write_text('late')"
        code = (
            "import subprocess,sys,time;"
            f"subprocess.Popen([sys.executable,'-c',{child!r},{str(marker)!r}],"
            "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);"
            "print('before-timeout',flush=True);time.sleep(30)"
        )
        started = time.monotonic()
        result = self.execute(code)
        self.assertLess(time.monotonic() - started, 3)
        item = result["gates"][0]
        self.assertEqual(("fail", None, "timeout"),
                         (item["status"], item["exit_code"], item["failure_reason"]))
        self.assertIn("before-timeout", item["output_tail"])
        time.sleep(max(0, started + 2.0 - time.monotonic()))
        self.assertFalse(marker.exists(), "a timed-out gate descendant continued writing")

    def test_failed_dependency_is_blocked_and_zero_lines_hide_output(self) -> None:
        first = gate([sys.executable, "-c", "import sys;print('failed');sys.exit(3)"])
        downstream = gate([sys.executable, "-c", "raise AssertionError('must not execute')"])
        downstream["depends_on"] = ["first"]
        self.manifest({"first": first, "downstream": downstream})
        result = run_profile(self.root, "fixture", set(), 0)
        self.assertEqual(["fail", "blocked"], [item["status"] for item in result["gates"]])
        self.assertEqual([], result["gates"][0]["output_tail"])
        self.assertEqual("dependency-blocked", result["gates"][1]["failure_reason"])

    def test_budget_exception_keeps_message_and_bounded_partial_output(self) -> None:
        with self.assertRaises(ProcessBudgetError) as caught:
            run_bounded([sys.executable, "-c", "import time;print('ready',flush=True);time.sleep(30)"],
                        timeout=0.15, max_stdout=1024, max_stderr=1024)
        self.assertIn("timeout", str(caught.exception))
        self.assertEqual("timeout", caught.exception.reason)
        self.assertEqual(b"ready\n", caught.exception.stdout)
        self.assertEqual(b"", caught.exception.stderr)
        original = ProcessBudgetError("legacy message")
        self.assertEqual("legacy message", str(original))
        self.assertEqual((b"", b""), (original.stdout, original.stderr))


class GateCacheTests(TemporaryRepository):
    def test_non_object_cache_records_are_misses(self) -> None:
        self.manifest({"pure": gate([sys.executable, "-c", "pass"], cache="content-addressed")})
        cache = self.root / "pass-cache"
        first = run_profile(self.root, "fixture", set(), 10, cache)
        cache_file = cache / (first["gates"][0]["cache_key"] + ".json")
        for value in (None, [], "invalid", 7):
            with self.subTest(value=value):
                cache_file.write_text(json.dumps(value), encoding="utf-8")
                result = run_profile(self.root, "fixture", set(), 10, cache)
                self.assertEqual("pass", result["status"])
                self.assertFalse(result["gates"][0]["cache_hit"])

    def test_complete_declared_input_cache_hits_and_invalidates(self) -> None:
        (self.root / "input.txt").write_text("good", encoding="utf-8")
        code = "from pathlib import Path;import sys;sys.exit(0 if Path('input.txt').read_text()=='good' else 4)"
        self.manifest({"pure": gate([sys.executable, "-c", code], cache="content-addressed", inputs=("input.txt",))})
        cache = self.root / "pass-cache"
        first = run_profile(self.root, "fixture", set(), 10, cache)
        second = run_profile(self.root, "fixture", set(), 10, cache)
        self.assertEqual("pass", first["status"])
        self.assertFalse(first["gates"][0]["cache_hit"])
        self.assertTrue(second["gates"][0]["cache_hit"])
        (self.root / "input.txt").write_text("bad", encoding="utf-8")
        third = run_profile(self.root, "fixture", set(), 10, cache)
        self.assertEqual("fail", third["status"])
        self.assertFalse(third["gates"][0]["cache_hit"])

    def test_production_gates_with_incomplete_inputs_do_not_cache(self) -> None:
        manifest = json.loads((REPOSITORY / "manifests/gates.json").read_text(encoding="utf-8"))
        for name in (
            "adk-pin", "adk-interface", "codex-pin", "runtime-chain-pin", "gitlink-registry",
            "reference-pins", "source-hygiene", "status-projection", "active-contracts",
        ):
            with self.subTest(gate=name):
                self.assertEqual("disabled", manifest["gates"][name]["cache_policy"])

    def test_real_production_graph_rechecks_same_head_index_changes(self) -> None:
        clone = self.root / "source"
        git(self.root, "clone", "--quiet", "--local", "--no-hardlinks", str(REPOSITORY), str(clone))
        shutil.copyfile(REPOSITORY / "manifests/gates.json", clone / "manifests/gates.json")
        cache = self.root / "production-cache"
        initial_head = git(clone, "rev-parse", "HEAD")
        baseline = run_profile(clone, "source-hygiene", set(), 10, cache)
        self.assertEqual("pass", baseline["status"], baseline)
        (clone / "build").mkdir()
        (clone / "build/audit.bin").write_bytes(b"harmless boundary fixture")
        git(clone, "add", "-f", "build/audit.bin")
        cached = run_profile(clone, "source-hygiene", set(), 10, cache)
        uncached = run_profile(clone, "source-hygiene", set(), 10)
        self.assertEqual(("fail", "fail"), (cached["status"], uncached["status"]))
        self.assertIn("build/audit.bin", "\n".join(cached["gates"][-1]["output_tail"]))
        self.assertTrue(all(not item["cache_hit"] for item in cached["gates"]))
        git(clone, "reset", "--quiet", "HEAD", "--", "build/audit.bin")
        git(clone, "update-index", "--force-remove", "agent-dev-kit")
        removed = run_profile(clone, "source-hygiene", set(), 10, cache)
        self.assertEqual("fail", removed["status"], removed)
        self.assertEqual("fail", removed["gates"][0]["status"])
        self.assertFalse(removed["gates"][0]["cache_hit"])
        self.assertEqual(initial_head, git(clone, "rev-parse", "HEAD"))


if __name__ == "__main__":
    unittest.main()
