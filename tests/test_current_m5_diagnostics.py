"""Current-candidate diagnostics stay read-only and reject unsafe evidence."""

import hashlib
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.codex_assets import software_m5_diagnostics as diagnostic
from tools.codex_assets import software_m5_v3_core as core

ROOT = Path(__file__).resolve().parents[1]


class CurrentM5DiagnosticsTests(unittest.TestCase):
    def test_actual_diagnostics_preserve_history_and_do_not_certify(self):
        paths = [ROOT / "manifests/software_m5_policy.json", ROOT / "manifests/product_maturity_scorecard.json",
                 ROOT / "reports/runtime-evidence/software-m5-production-qualification-2026-09-12.json"]
        before = [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths]
        with mock.patch("subprocess.Popen", side_effect=AssertionError("external process")):
            result = diagnostic.diagnose(ROOT)
        self.assertEqual("blocked", result["status"])
        self.assertFalse(result["software_m5_certified"])
        self.assertFalse(result["release_authorized"])
        self.assertEqual(0, result["model_invocations"])
        self.assertIn("runtime", result["blocking_gates"])
        self.assertIn("qualification", result["blocking_gates"])
        self.assertEqual(before, [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths])

    def test_duplicate_nonfinite_and_overflow_json_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "evidence.json"
            for text in ('{"a":1,"a":2}', '{"a":NaN}', '{"a":1e999}'):
                path.write_text(text)
                with self.assertRaises(core.M5Error):
                    core._load_object(path, "fixture")

    def test_leaf_link_is_not_resolved_before_strict_read(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "target.json"
            target.write_text('{}')
            link = root / "link.json"
            link.symlink_to(target)
            path = core._repo_path(root, "link.json", "fixture")
            self.assertEqual(link, path)
            with self.assertRaises(core.M5Error):
                core._load_object(path, "fixture")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX")
    def test_special_evidence_is_rejected_without_hanging(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fifo"
            os.mkfifo(path)
            with self.assertRaises(core.M5Error):
                core._load_object(path, "fixture")

    def test_duplicate_lock_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "adk.lock"
            path.write_text('schema=llm-agent-adk-lock/v2\nschema=llm-agent-adk-lock/v2\n')
            with self.assertRaises(core.M5Error):
                diagnostic._lock(root)
            with self.assertRaises(core.M5Error):
                core._kv(path)

    def test_field_hash_and_jsonl_reject_links_and_special_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            outside = root / "outside"
            outside.write_text('{}\n')
            link = root / "link"
            link.symlink_to(outside)
            for operation in (lambda: core._sha256_file(link), lambda: core._read_events(root, link)):
                with self.assertRaises(core.M5Error):
                    operation()
            if hasattr(os, "mkfifo"):
                fifo = root / "fifo"
                os.mkfifo(fifo)
                for operation in (lambda: core._sha256_file(fifo), lambda: core._read_events(root, fifo)):
                    with self.assertRaises(core.M5Error):
                        operation()

    def test_duplicate_jsonl_event_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "events.jsonl"
            path.write_text('{"sequence":1,"sequence":1}\n')
            with self.assertRaises(core.M5Error):
                core._read_events(root, path)


if __name__ == "__main__":
    unittest.main()
