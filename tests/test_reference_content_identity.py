"""Actual Git fixtures for working-tree identity drift and link boundaries."""

import hashlib
import json
import os
import subprocess
import shutil
import csv
import tempfile
import unittest
from pathlib import Path
from unittest import mock
from datetime import date, timedelta

from tools.codex_assets import reference_worktree_identity as identity


class ReferenceIdentityTests(unittest.TestCase):
    @staticmethod
    def fixture_git(repo, *args):
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_TEMPLATE_DIR="")
        return subprocess.check_output(["git", "-c", "core.hooksPath=" + os.devnull, "-c", "init.templateDir=",
                                        "-c", "commit.gpgSign=false", "-c", "maintenance.auto=false", "-c", "gc.auto=0",
                                        "-C", str(repo), *args], env=environment)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / "sample"
        self.repo.mkdir()
        for args in (("init", "-q"), ("config", "user.name", "Fixture"), ("config", "user.email", "fixture@example.invalid"), ("config", "core.fileMode", "true")):
            self.git(*args)
        self.file = self.repo / "file.txt"
        self.file.write_bytes(b"original")
        self.git("add", "file.txt")
        self.git("commit", "-q", "-m", "fixture")

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return self.fixture_git(self.repo, *args)

    def snap(self):
        return identity.snapshot(self.root, "sample")

    def test_second_content_change_with_same_porcelain_is_detected(self):
        self.file.write_bytes(b"first")
        status = self.git("status", "--porcelain")
        before = self.snap()
        self.file.write_bytes(b"second")
        self.assertEqual(status, self.git("status", "--porcelain"))
        self.assertNotEqual(before["snapshot_sha256"], self.snap()["snapshot_sha256"])

    def test_mode_change_binds_without_rewriting(self):
        before = self.snap()
        self.file.chmod(0o755)
        after = self.snap()
        self.assertNotEqual(before["snapshot_sha256"], after["snapshot_sha256"])
        self.assertEqual(before["head"], after["head"])
        self.assertEqual(before["index_sha256"], after["index_sha256"])
        self.assertEqual(0o755, self.file.stat().st_mode & 0o777)

    def test_index_and_head_are_bound(self):
        self.file.write_bytes(b"changed")
        before = self.snap()
        self.git("add", "file.txt")
        staged = self.snap()
        self.assertNotEqual(before["index_sha256"], staged["index_sha256"])
        self.assertEqual(before["worktree_sha256"], staged["worktree_sha256"])
        self.git("commit", "-q", "-m", "next")
        self.assertNotEqual(staged["snapshot_sha256"], self.snap()["snapshot_sha256"])

    def test_symlink_hashes_text_not_outside_referent(self):
        outside = self.root / "outside"
        outside.write_bytes(b"private first")
        link = self.repo / "link"
        link.symlink_to(outside)
        before = self.snap()
        outside.write_bytes(b"private second")
        self.assertEqual(before["snapshot_sha256"], self.snap()["snapshot_sha256"])
        target = os.fsencode(str(outside))
        link.unlink()
        link.write_bytes(target)
        self.assertNotEqual(before["snapshot_sha256"], self.snap()["snapshot_sha256"])

    def test_symlink_parent_is_not_traversed(self):
        directory = self.repo / "directory"
        directory.mkdir()
        (directory / "tracked").write_bytes(b"inside")
        self.git("add", "directory/tracked")
        self.git("commit", "-q", "-m", "directory")
        (directory / "tracked").unlink()
        directory.rmdir()
        directory.symlink_to(self.root)
        with self.assertRaises(OSError):
            self.snap()

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX")
    def test_special_file_is_rejected_without_opening(self):
        self.file.unlink()
        os.mkfifo(self.file)
        with self.assertRaises(identity.IdentityError):
            self.snap()

    def test_limits_fail_closed(self):
        with mock.patch.object(identity, "MAX_FILE_BYTES", 1):
            with self.assertRaises(identity.IdentityError):
                self.snap()

    def test_review_false_flags_and_identity_required(self):
        observed = self.snap()["snapshot_sha256"]
        record = {"schema": "llm-agent-reference-worktree-review/v1", "mode": "report-only",
                  "reviewed_on": date.today().isoformat(), "expires_on": (date.today() + timedelta(days=7)).isoformat(),
                  "owner_approval": False, "runtime_enablement": False,
                  "observations": {"sample": {"snapshot_sha256": observed, "source_approved": False}}}
        path = self.root / "review.json"
        def publish(value):
            value.pop("record_sha256", None)
            value["record_sha256"] = hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
            path.write_text(json.dumps(value), encoding="utf-8")
        publish(record)
        identity.verify_review(self.root, "sample", observed, "review.json")
        record["observations"]["sample"]["source_approved"] = True
        publish(record)
        with self.assertRaises(identity.IdentityError):
            identity.verify_review(self.root, "sample", observed, "review.json")
        record["observations"]["sample"]["source_approved"] = False
        record["expires_on"] = (date.today() - timedelta(days=1)).isoformat()
        publish(record)
        with self.assertRaises(identity.IdentityError):
            identity.verify_review(self.root, "sample", observed, "review.json")

    def test_checker_recomputes_content_instead_of_trusting_report_flags(self):
        source = Path(__file__).resolve().parents[1]
        (self.root / "scripts").mkdir()
        (self.root / "subrepos").mkdir()
        (self.root / "reports").mkdir()
        shutil.copyfile(source / "scripts/classify-repo-worktree.sh", self.root / "scripts/classify-repo-worktree.sh")
        (self.root / "scripts/classify-repo-worktree.sh").chmod(0o755)
        observations = {}
        rows = []
        for name in ("OpenSpec", "superpowers", "vibeflow"):
            repo = self.root / name
            repo.mkdir()
            def git(*args):
                return self.fixture_git(repo, *args)
            git("init", "-q")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            file = repo / "tracked"
            file.write_text("original")
            git("add", "tracked")
            git("commit", "-q", "-m", "fixture")
            file.write_text("first")
            observed = identity.snapshot(self.root, name)["snapshot_sha256"]
            observations[name] = {"snapshot_sha256": observed, "source_approved": False}
            status = subprocess.check_output(["bash", str(source / "scripts/classify-repo-worktree.sh"), str(self.root), name])
            classified = json.loads(status)
            rows.append({"repo": name, "expected_state": "dirty", "baseline_ref": "fixture",
                         "status_fingerprint": classified["status_fingerprint"], "change_count": 1,
                         "expected_classification": "content", "analysis_policy": "commit-snapshot-only",
                         "expires_on": (date.today() + timedelta(days=7)).isoformat(), "owner": "fixture-role", "reason": "isolated",
                         "snapshot_schema": identity.SCHEMA, "snapshot_sha256": observed,
                         "review_record": "reports/review.json"})
        record = {"schema": "llm-agent-reference-worktree-review/v1", "mode": "report-only", "owner_approval": False,
                  "runtime_enablement": False, "reviewed_on": date.today().isoformat(),
                  "expires_on": (date.today() + timedelta(days=7)).isoformat(), "observations": observations}
        record["record_sha256"] = hashlib.sha256(json.dumps(record, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
        (self.root / "reports/review.json").write_text(json.dumps(record))
        with (self.root / "subrepos/dirty-baseline.tsv").open("w", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=list(rows[0]), delimiter="\t")
            writer.writeheader()
            writer.writerows(rows)
        report = self.root / ("reports/reference-dirty-triage-" + date.today().isoformat() + ".json")
        subprocess.run(["bash", str(source / "scripts/generate-reference-dirty-triage.sh"), str(self.root), "--out", str(self.root / "reports/triage.md"), "--json-out", str(report)], check=True, capture_output=True)
        command = ["bash", str(source / "scripts/check-reference-dirty-triage.sh"), str(self.root), "--summary-json"]
        self.assertEqual(0, subprocess.run(command, capture_output=True).returncode)
        (self.root / "OpenSpec/tracked").write_text("second")
        failed = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(0, failed.returncode)
        self.assertIn("current content identity", failed.stdout)

    def test_ambient_git_variables_and_hooks_cannot_escape_fixture(self):
        sentinel = self.root / "outside-index"
        sentinel.write_bytes(b"unchanged")
        hooks = self.root / "hooks"
        hooks.mkdir()
        hook = hooks / "pre-commit"
        marker = self.root / "hook-ran"
        hook.write_text("#!/bin/sh\ntouch '" + str(marker) + "'\n")
        hook.chmod(0o755)
        self.git("config", "core.hooksPath", str(hooks))
        with mock.patch.dict(os.environ, {"GIT_DIR": str(self.root / "outside-git"), "GIT_WORK_TREE": str(self.root), "GIT_INDEX_FILE": str(sentinel)}):
            self.file.write_bytes(b"safe fixture")
            self.git("add", "file.txt")
            self.git("commit", "-q", "-m", "safe")
        self.assertFalse(marker.exists())
        self.assertEqual(b"unchanged", sentinel.read_bytes())

    def test_checker_rejects_unsafe_discovered_reports(self):
        source = Path(__file__).resolve().parents[1]
        (self.root / "subrepos").mkdir()
        evidence = self.root / "docs/changes/fixture/evidence"
        evidence.mkdir(parents=True)
        (self.root / "subrepos/dirty-baseline.tsv").write_text(
            "repo\treview_record\nsample\tdocs/changes/fixture/evidence/review.json\n")
        candidate = evidence / "reference-dirty-triage-9999-12-31.json"
        target = self.root / "outside.json"
        target.write_text("{}")
        for kind in ("fifo", "link", "array", "duplicate", "items", "large"):
            with self.subTest(kind=kind):
                if kind == "fifo":
                    os.mkfifo(candidate)
                elif kind == "link":
                    candidate.symlink_to(target)
                else:
                    candidate.write_text({"array": "[]", "duplicate": '{"items":[],"items":[]}',
                                          "items": '{"items":[1]}', "large": " " * (512 * 1024 + 1)}[kind])
                result = subprocess.run(["bash", str(source / "scripts/check-reference-dirty-triage.sh"),
                                         str(self.root), "--summary-json"], capture_output=True, text=True, timeout=5)
                self.assertEqual(1, result.returncode, result.stderr)
                self.assertEqual("fail", json.loads(result.stdout)["status"])
                candidate.unlink()

    def test_classifier_does_not_execute_clean_filter_or_fsmonitor(self):
        source = Path(__file__).resolve().parents[1]
        marker = self.root / "filter-ran"
        program = self.root / "unsafe-filter"
        program.write_text("#!/bin/sh\ntouch '" + str(marker) + "'\ncat\n")
        program.chmod(0o755)
        self.git("config", "filter.fixture.clean", str(program))
        self.git("config", "core.fsmonitor", str(program))
        (self.repo / ".gitattributes").write_text("file.txt filter=fixture\n")
        self.file.write_bytes(b"modified")
        result = subprocess.run(["bash", str(source / "scripts/classify-repo-worktree.sh"), str(self.root), "sample"], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse(marker.exists())
        for driver in ("unsafe name", "unsafe=value"):
            with self.subTest(driver=driver):
                self.git("config", "filter." + driver + ".clean", str(program))
                result = subprocess.run(["bash", str(source / "scripts/classify-repo-worktree.sh"), str(self.root), "sample"], capture_output=True, text=True)
                self.assertEqual(1, result.returncode, result.stderr)
                self.assertFalse(marker.exists())
                self.git("config", "--unset", "filter." + driver + ".clean")


if __name__ == "__main__":
    unittest.main()
