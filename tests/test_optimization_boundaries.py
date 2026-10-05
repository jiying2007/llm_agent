"""Regression of owned intake IO ports after hotspot extraction."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets import intake_io as io
from tools.codex_assets import practice_intake as intake


class IntakeIOTests(unittest.TestCase):
    def test_stable_consumer_ports_use_owned_implementation(self):
        self.assertIs(intake.IntakeError, io.IntakeError)
        self.assertIs(intake._load_json, io._load_json)
        self.assertIs(intake._transactional_write, io._transactional_write)

    def test_actual_json_and_jsonl_consumers_reject_ambiguity(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "input.json"
            for raw in ('{"x":1,"x":2}', '{"x":1,"\\u0078":2}',
                        '{"a":{"x":1,"x":2}}', '{"x":NaN}', '{"x":1e999}'):
                path.write_text(raw)
                with self.subTest(raw=raw), self.assertRaises(io.IntakeError):
                    intake._load_json(path, 1024, "fixture")
                with self.subTest(raw=raw), self.assertRaises(io.IntakeError):
                    intake._load_jsonl(path, 1024, "fixture")
            path.write_text('{"x":"secret-value","x":1}')
            with self.assertRaises(io.IntakeError) as caught:
                intake._load_json(path, 1024, "fixture")
            self.assertNotIn("secret-value", str(caught.exception))

    def test_second_output_failure_rolls_back_original_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            first, second = Path(temp) / "first", Path(temp) / "second"
            first.write_bytes(b"original-first")
            second.write_bytes(b"original-second")
            original_replace = io.os.replace
            def fail_second(source, target):
                if "stage" in Path(source).name and Path(target) == second:
                    raise OSError("injected second output failure")
                return original_replace(source, target)
            with patch.object(io.os, "replace", side_effect=fail_second):
                with self.assertRaises(io.IntakeError):
                    io._transactional_write([(first, b"new-first"), (second, b"new-second")])
            self.assertEqual(first.read_bytes(), b"original-first")
            self.assertEqual(second.read_bytes(), b"original-second")
            self.assertEqual(sorted(p.name for p in Path(temp).iterdir()), ["first", "second"])


if __name__ == "__main__":
    unittest.main()
