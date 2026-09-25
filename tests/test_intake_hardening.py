"""Offline cache-to-analysis and resource-boundary regression tests."""

from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import time
import tracemalloc
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets import intake_pipeline as intake
from tools.control_plane import reference_pins as pins
from tools.control_plane.process_budget import ProcessBudgetError, run_bounded


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, timeout=10)
    return result.stdout.decode().strip()


def initialize(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q")
    git(root, "config", "user.name", "Offline Test")
    git(root, "config", "user.email", "offline@example.invalid")


class ProcessTests(unittest.TestCase):
    def test_success_and_nonzero_are_preserved(self) -> None:
        result = run_bounded([sys.executable, "-c", "import sys;print('ok');sys.stderr.write('error');sys.exit(3)"])
        self.assertEqual((result.returncode, result.stdout, result.stderr), (3, b"ok\n", b"error"))

    def test_stdout_flood(self) -> None:
        with self.assertRaisesRegex(ProcessBudgetError, "stdout"):
            run_bounded([sys.executable, "-c", "import os;os.write(1,b'x'*1000000)"], max_stdout=1024)

    def test_stderr_flood(self) -> None:
        with self.assertRaisesRegex(ProcessBudgetError, "stderr"):
            run_bounded([sys.executable, "-c", "import os;os.write(2,b'x'*1000000)"], max_stderr=1024)

    def test_sink_never_exceeds_budget(self) -> None:
        with tempfile.TemporaryFile() as sink:
            with self.assertRaises(ProcessBudgetError):
                run_bounded([sys.executable, "-c", "import os;os.write(1,b'x'*1000000)"],
                            max_stdout=1024, stdout_sink=sink)
            self.assertLessEqual(sink.tell(), 1024)

    def test_timeout(self) -> None:
        start = time.monotonic()
        with self.assertRaisesRegex(ProcessBudgetError, "timeout"):
            run_bounded([sys.executable, "-c", "import time;time.sleep(30)"], timeout=0.15)
        self.assertLess(time.monotonic() - start, 3)

    @unittest.skipUnless(os.name == "posix", "POSIX descendant cleanup")
    def test_descendant_inheriting_pipes_is_bounded(self) -> None:
        code = "import subprocess,sys;subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])"
        start = time.monotonic()
        with self.assertRaises(ProcessBudgetError):
            run_bounded([sys.executable, "-c", code], timeout=0.2)
        self.assertLess(time.monotonic() - start, 3)

    def test_invalid_budgets(self) -> None:
        for kwargs in ({"timeout": 0}, {"timeout": float("nan")}, {"max_stdout": True}, {"max_stderr": -1}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                run_bounded([sys.executable, "-c", "pass"], **kwargs)


class MetadataTests(unittest.TestCase):
    def test_crlf_frontmatter(self) -> None:
        status, value = intake._frontmatter("---\r\nname: test\r\ndescription: >\r\n  first line\r\n  second line\r\n---\r\nbody")
        self.assertEqual(status, "valid")
        self.assertEqual(value["description"].strip(), "first line second line")

    def test_literal_and_folded_description(self) -> None:
        for marker in ("|", ">"):
            status, value = intake._frontmatter(f"---\nname: test\ndescription: {marker}\n  first line\n  second line\n---\nbody")
            self.assertEqual(status, "valid")
            self.assertIn("first line", value["description"])
            self.assertIn("second line", value["description"])
            self.assertNotIn(value["description"].strip(), ("|", ">"))

    def test_duplicate_alias_tag_and_nesting_rejected(self) -> None:
        samples = [
            "name: x\nname: y", "name: &x yes\ndescription: *x", "name: !!python/object:os.system {}",
            "name: [x]", "description: true", "name: x\nvalue: " + "[" * 20 + "0" + "]" * 20,
        ]
        for sample in samples:
            with self.subTest(sample=sample):
                self.assertEqual(intake._frontmatter("---\n" + sample + "\n---\nbody")[0], "invalid")

    def test_missing_and_oversized_metadata(self) -> None:
        self.assertEqual(intake._frontmatter("body")[0], "missing")
        self.assertEqual(intake._frontmatter("---\nname: x\n")[0], "invalid")
        self.assertEqual(intake._frontmatter("---\ndescription: " + "x" * 70000 + "\n---\n")[0], "invalid")


class ReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root, self.cache, self.reports = self.base / "root", self.base / "cache", self.base / "reports"
        initialize(self.root)
        source = self.base / "source"
        initialize(source)
        git(source, "remote", "add", "origin", "https://github.com/example/Reference.git")
        (source / "skills" / "sample").mkdir(parents=True)
        (source / "skills" / "sample" / "SKILL.md").write_text(
            "---\nname: sample\ndescription: |\n  A multiline description\n  with clear boundaries\n---\nMust not auto-adopt.\n", encoding="utf-8")
        (source / "prompt.rs").write_text('let system_prompt = "hello";\n', encoding="utf-8")
        (source / "prompt.go").write_text('system_prompt := "hello"\n', encoding="utf-8")
        (source / "empty.md").write_text("", encoding="utf-8")
        git(source, "add", ".")
        git(source, "commit", "-qm", "fixture")
        self.commit = git(source, "rev-parse", "HEAD")
        self.tree = git(source, "rev-parse", "HEAD^{tree}")
        self.source = self.cache / "Reference" / self.commit
        self.source.parent.mkdir(parents=True)
        source.rename(self.source)
        self.manifest = {
            "schema": "llm-agent-reference-pins/v2",
            "policy": {"tracked_gitlink_forbidden": True, "submodule_entry_forbidden": True,
                       "runtime_enablement": False, "pin_is_evidence_not_source": True,
                       "materialization_root": "user-cache-only", "materialization_requires_explicit_id": True},
            "pins": [{"id": "Reference", "kind": "reference-repo", "path": "Reference",
                      "url": "https://github.com/example/Reference.git", "commit": self.commit}],
        }
        (self.root / "manifests").mkdir()
        self.save_manifest()

    def save_manifest(self) -> None:
        (self.root / "manifests" / "reference_pins.json").write_text(json.dumps(self.manifest), encoding="utf-8")

    def analyze(self, **kwargs):
        return intake.analyze(self.root, "Reference", "HEAD", "all", self.reports, cache_root=str(self.cache), **kwargs)

    def test_cache_only_end_to_end_and_root_unchanged(self) -> None:
        before = git(self.root, "status", "--porcelain=v1", "--untracked-files=all")
        result = self.analyze()
        self.assertEqual(git(self.root, "status", "--porcelain=v1", "--untracked-files=all"), before)
        self.assertFalse((self.root / "Reference").exists())
        report = json.loads((Path(result["report_dir"]) / "analysis.json").read_text())
        self.assertEqual(report["schema"], "llm-agent-intake-analysis/v2")
        self.assertEqual((report["source"]["commit"], report["source"]["tree"]), (self.commit, self.tree))
        self.assertEqual(report["status"], "static-complete")
        self.assertEqual(report["coverage"]["by_suffix"][".rs"]["analyzed"], 1)
        self.assertEqual(report["coverage"]["by_suffix"][".go"]["analyzed"], 1)
        self.assertEqual(report["prompt_evidence"]["code_signal_count"], 2)
        self.assertIn("clear boundaries", report["skills"][0]["description"])
        self.assertNotIn("structural_score", report)
        self.assertEqual(report["comparison"]["adk_catalog_status"], "unavailable")
        decision = json.loads((Path(result["report_dir"]) / "decision-candidate.json").read_text())
        self.assertFalse(decision["auto_apply"])
        self.assertEqual(decision["status"], "review-required")

    def test_dirty_cache_cannot_contaminate_snapshot(self) -> None:
        (self.source / "prompt.rs").write_text("not committed\n")
        result = self.analyze()
        report = json.loads((Path(result["report_dir"]) / "analysis.json").read_text())
        self.assertEqual(report["prompt_evidence"]["code_signal_count"], 2)
        self.assertGreater(report["source"]["worktree"]["dirty_count"], 0)

    def test_origin_replacement_rejected(self) -> None:
        git(self.source, "remote", "set-url", "origin", "https://github.com/other/Reference.git")
        with self.assertRaisesRegex(RuntimeError, "origin"):
            self.analyze()

    def test_head_drift_rejected(self) -> None:
        (self.source / "new.md").write_text("new")
        git(self.source, "add", ".")
        git(self.source, "commit", "-qm", "drift")
        with self.assertRaisesRegex(RuntimeError, "drift"):
            self.analyze()

    def test_no_root_fallback(self) -> None:
        self.source.rename(self.root / "Reference")
        with self.assertRaisesRegex(RuntimeError, "not materialized"):
            self.analyze()

    def test_wrong_ref_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "exact pin"):
            intake.analyze(self.root, "Reference", "main", "all", self.reports, cache_root=str(self.cache))

    def test_cache_workspace_and_runtime_boundaries(self) -> None:
        runtime = self.base / "live"
        (self.root / "manifests" / "runtime_targets.json").write_text(json.dumps({
            "targets": [{"source_repo": str(self.base / "runtime-source"), "live_root": str(runtime)}]}))
        for target in (self.root, self.root / "cache", self.base, runtime / "cache", self.base / "runtime-source" / "cache"):
            with self.subTest(target=target), self.assertRaisesRegex(RuntimeError, "overlaps"):
                pins.plan(self.root, "Reference", str(target))

    def test_cache_symlink_escape_rejected(self) -> None:
        link_cache = self.base / "link-cache"
        link_cache.mkdir()
        (link_cache / "Reference").symlink_to(self.source.parent, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "symlink"):
            pins.resolve_source(self.root, "Reference", str(link_cache))

    def test_unsafe_pin_ids_and_credential_urls_rejected(self) -> None:
        for name in ("..", ".", "../escape"):
            self.manifest["pins"][0]["id"] = name
            self.save_manifest()
            with self.assertRaises(RuntimeError):
                pins.check(self.root)
        self.manifest["pins"][0]["id"] = "Reference"
        for url in ("https://user:password@example.org/repo", "https://example.org/repo?token=secret"):
            self.manifest["pins"][0]["url"] = url
            self.save_manifest()
            with self.assertRaises(RuntimeError):
                pins.check(self.root)

    def test_reuse_checks_identity(self) -> None:
        receipt = pins.materialize(self.root, "Reference", str(self.cache))
        self.assertTrue(receipt["reused"])
        self.assertEqual(receipt["tree"], self.tree)

    def test_report_cannot_write_live_root(self) -> None:
        live = self.base / "live"
        (self.root / "manifests" / "runtime_targets.json").write_text(json.dumps({
            "targets": [{"source_repo": None, "live_root": str(live)}]}))
        with self.assertRaisesRegex(RuntimeError, "protected"):
            intake.analyze(self.root, "Reference", "HEAD", "all", live, cache_root=str(self.cache))
        self.assertFalse(live.exists())

    def test_malformed_runtime_registry_is_structured_failure(self) -> None:
        (self.root / "manifests" / "runtime_targets.json").write_text('{"targets":[null]}')
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = intake.main(["Reference", "--root", str(self.root), "--cache-root", str(self.cache), "--summary-json"])
        self.assertEqual((code, json.loads(stdout.getvalue())["status"]), (1, "fail"))

    def test_managed_dependency_requires_explicit_kind_and_exact_gitlink(self) -> None:
        managed = self.root / "Dependency"
        self.source.rename(managed)
        (self.root / "manifests" / "gitlinks.json").write_text(json.dumps({
            "schema": "llm-agent-gitlinks/v2", "gitlinks": [{
                "path": "Dependency", "kind": "managed-dependency", "url": "https://github.com/example/Reference.git"}]}))
        git(self.root, "update-index", "--add", "--cacheinfo", "160000," + self.commit + ",Dependency")
        result = intake.analyze(self.root, "Dependency", "HEAD", "all", self.reports, source_kind="managed-dependency")
        self.assertEqual(result["source_commit"], self.commit)
        git(managed, "remote", "set-url", "origin", "https://github.com/other/Dependency.git")
        with self.assertRaisesRegex(RuntimeError, "origin"):
            intake.analyze(self.root, "Dependency", "HEAD", "all", self.reports, source_kind="managed-dependency")

    def test_git_archive_links_are_skipped_and_reported(self) -> None:
        (self.source / "external-link").symlink_to("/etc/passwd")
        git(self.source, "add", ".")
        git(self.source, "commit", "-qm", "link fixture")
        new_commit = git(self.source, "rev-parse", "HEAD")
        moved = self.source.parent / new_commit
        self.source.rename(moved)
        self.source = moved
        self.manifest["pins"][0]["commit"] = new_commit
        self.save_manifest()
        result = self.analyze()
        report = json.loads((Path(result["report_dir"]) / "analysis.json").read_text())
        self.assertEqual(report["source"]["skipped_archive_links"], 1)
        self.assertEqual(report["status"], "static-partial")

    def test_archive_generation_byte_limit(self) -> None:
        with self.assertRaises(ProcessBudgetError):
            self.analyze(budget=intake.IntakeBudget(archive_bytes=100))
        self.assertFalse(self.reports.exists())

    def test_member_limit(self) -> None:
        with self.assertRaises(ProcessBudgetError):
            self.analyze(budget=intake.IntakeBudget(archive_members=1))

    def test_failure_json_and_exit_code_agree(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = intake.main(["Reference", "--root", str(self.root), "--cache-root", str(self.cache),
                                "--summary-json", "--max-archive-bytes", "100"])
        result = json.loads(stdout.getvalue())
        self.assertEqual((code, result["status"], result["reason"]), (1, "fail", "budget-exceeded"))


class SnapshotTests(unittest.TestCase):
    def test_coverage_is_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "ok.rs").write_text('let system_prompt = "test";')
            (root / "bad.rs").write_bytes(b"\xff")
            (root / "big.md").write_bytes(b"x" * 1000)
            (root / "data.bin").write_bytes(b"123")
            (root / "empty.md").write_text("")
            scanned = intake._scan_snapshot(root, intake.IntakeBudget(text_bytes=512))
            self.assertEqual(scanned["coverage"]["by_status"],
                             {"analyzed": 2, "decode-error": 1, "oversized": 1, "unsupported": 1})
            self.assertEqual(sum(sum(v.values()) for v in scanned["coverage"]["by_suffix"].values()), 5)

    def test_archive_path_and_special_file_rejection(self) -> None:
        for name, kind in (("../escape", tarfile.REGTYPE), ("/escape", tarfile.REGTYPE),
                           ("bad\\path", tarfile.REGTYPE), ("device", tarfile.CHRTYPE)):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                data = io.BytesIO()
                with tarfile.open(fileobj=data, mode="w") as archive:
                    member = tarfile.TarInfo(name)
                    member.type = kind
                    archive.addfile(member)
                def fake_run(command, **kwargs):
                    kwargs["stdout_sink"].write(data.getvalue())
                    return subprocess.CompletedProcess(command, 0, b"", b"")
                with patch.object(intake, "run_bounded", side_effect=fake_run), self.assertRaises(intake.IntakeError):
                    intake._safe_extract_archive(Path(tmp), "a" * 40, Path(tmp), intake.IntakeBudget())

    def test_streaming_scan_does_not_retain_all_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = "guardrail approval " + "x" * (256 * 1024)
            for index in range(64):
                (root / f"file-{index}.md").write_text(text)
            tracemalloc.start()
            try:
                scanned = intake._scan_snapshot(root, intake.IntakeBudget())
                _, peak = tracemalloc.get_traced_memory()
            finally:
                tracemalloc.stop()
            self.assertEqual(scanned["coverage"]["by_status"]["analyzed"], 64)
            self.assertLess(peak, 8 * 1024 * 1024)
            print(json.dumps({"metric": "scanner-python-allocation-peak", "peak_bytes": peak,
                              "input_text_bytes": len(text.encode()) * 64, "scope": "offline-synthetic-test"}))


if __name__ == "__main__":
    unittest.main()
