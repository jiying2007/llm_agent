"""Synthetic input validation only; never execute or certify a real runtime."""
import json
import os
import tempfile
import unittest
from unittest import mock
from datetime import datetime, timedelta, timezone
from pathlib import Path

from tools.codex_assets import software_m5_rollover as rollover


class RolloverModelBindingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "runtime.json"
        self.now = datetime.now(timezone.utc).replace(microsecond=0)
        self.lock = {"agent-dev-kit.version": "8.0.5", "agent-dev-kit.commit": "a" * 40,
                     "agent-dev-kit.tree": "b" * 40, "agent-dev-kit.manifest_blob": "c" * 40}

    def evidence(self, model):
        value = {"schema": rollover.EVIDENCE_SCHEMA, "manifest_version": "8.0.5",
                 "adk_commit": "a" * 40, "adk_tree": "b" * 40, "manifest_blob": "c" * 40,
                 "runtime": "codex", "requested_model": model,
                 "generated_at": self.now.isoformat().replace("+00:00", "Z"),
                 "review_after": (self.now + timedelta(days=30)).date().isoformat(),
                 "result": {"status": "pass", "runtime": "codex", "condition": "adk",
                            "requested_model": model, "quality_gate": {"synthetic": True}}}
        value["evidence_sha256"] = rollover._digest(value)
        self.path.write_text(json.dumps(value))
        return value

    def test_default_preserves_historical_model_binding(self):
        self.evidence("gpt-5.5")
        rollover._validate_runtime(self.path, self.lock, self.now)

    def test_current_model_requires_explicit_selection(self):
        self.evidence("gpt-6.1-sol")
        with self.assertRaises(rollover.RolloverError):
            rollover._validate_runtime(self.path, self.lock, self.now)
        result = rollover._validate_runtime(self.path, self.lock, self.now, expected_model="gpt-6.1-sol")
        self.assertEqual("gpt-6.1-sol", result["requested_model"])

    def test_wrong_model_and_invalid_selection_remain_blocked(self):
        self.evidence("gpt-6.1-sol")
        for model in ("gpt-other", "", " gpt-6.1-sol", "x" * 129, None):
            with self.subTest(model=model), self.assertRaises(rollover.RolloverError):
                rollover._validate_runtime(self.path, self.lock, self.now, expected_model=model)

    def test_nested_model_mismatch_is_rejected_even_with_new_digest(self):
        value = self.evidence("gpt-6.1-sol")
        value["result"]["requested_model"] = "gpt-other"
        value.pop("evidence_sha256")
        value["evidence_sha256"] = rollover._digest(value)
        self.path.write_text(json.dumps(value))
        with self.assertRaises(rollover.RolloverError):
            rollover._validate_runtime(self.path, self.lock, self.now, expected_model="gpt-6.1-sol")

    def test_strict_json_rejects_duplicates_nonfinite_and_nonobjects(self):
        for raw in ('{"a":1,"a":2}', '{"a":NaN}', '{"a":1e999}', '[]'):
            self.path.write_text(raw)
            with self.subTest(raw=raw), self.assertRaises(rollover.RolloverError):
                rollover._load_json(self.path, "fixture")

    def test_links_and_fifo_are_rejected_without_reading_them(self):
        target = self.path.parent / "target.json"
        target.write_text('{}')
        self.path.symlink_to(target)
        with self.assertRaises(rollover.RolloverError):
            rollover._load_json(self.path, "fixture")
        self.path.unlink()
        if hasattr(os, "mkfifo"):
            os.mkfifo(self.path)
            with self.assertRaises(rollover.RolloverError):
                rollover._load_json(self.path, "fixture")

    def test_finalize_does_not_resolve_away_link_rejection(self):
        self.evidence("gpt-5.5")
        target = self.path.parent / "target.json"
        self.path.rename(target)
        self.path.symlink_to(target)
        with mock.patch.object(rollover, "_git", side_effect=["", "a" * 40]), \
                mock.patch.object(rollover, "_read_lock", return_value=self.lock), \
                mock.patch.object(rollover, "_validate_promotion", return_value={}):
            with self.assertRaisesRegex(rollover.RolloverError, "invalid measured runtime evidence"):
                rollover.finalize(self.path.parent, self.path, 1)


if __name__ == "__main__":
    unittest.main()
