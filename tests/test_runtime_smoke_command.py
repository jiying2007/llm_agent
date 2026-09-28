"""Provider-free checks for the current ADK runtime smoke invocation boundary."""

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets import runtime_smoke_evidence as smoke


class RuntimeSmokeCommandTests(unittest.TestCase):
    def test_execute_requires_explicit_unknown_cost_acknowledgment(self):
        with patch.object(smoke, "_validate_source_identity") as source:
            with self.assertRaises(smoke.SmokeEvidenceError):
                smoke.collect(
                    Path("/unused"), Path("/unused/result.json"), raw_result=None,
                    raw_output=Path("/unused/raw.json"), execute=True, model="gpt-5.5",
                    limit=1, tasks=None, runtime_binary=None, generated_at=None,
                    review_days=30,
                )
        source.assert_not_called()

    def test_current_adk_entry_and_budget_flags_are_passed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "agent-dev-kit"
            (adk / "scripts").mkdir(parents=True)
            (adk / "scripts/devkit.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
            tasks = root / "tasks.jsonl"
            tasks.write_text("{}\n", encoding="utf-8")
            output = root / "raw.json"

            def fake_run(command, **kwargs):
                self.assertEqual(command[:2], ["bash", str(adk / "scripts/devkit.sh")])
                if "--help" in command:
                    return subprocess.CompletedProcess(
                        command, 0, stdout="--max-new-results --approve-unknown-cost", stderr="",
                    )
                self.assertEqual(command[command.index("--max-new-results") + 1], "2")
                self.assertIn("--approve-unknown-cost", command)
                self.assertEqual(command[command.index("--model") + 1], "gpt-5.5")
                output.write_text("{}\n", encoding="utf-8")
                return subprocess.CompletedProcess(command, 0)

            with patch.object(smoke.subprocess, "run", side_effect=fake_run):
                smoke._execute_runtime(root, adk, output, "gpt-5.5", 2, tasks)

            output.unlink()
            with patch.object(smoke.subprocess, "run", return_value=subprocess.CompletedProcess(
                ["bash", str(adk / "scripts/devkit.sh"), "eval", "run", "--help"],
                0, stdout="legacy eval help", stderr="",
            )) as model_call:
                with self.assertRaises(smoke.SmokeEvidenceError):
                    smoke._execute_runtime(root, adk, output, "gpt-5.5", 2, tasks)
            model_call.assert_called_once()
            self.assertFalse(output.exists())

    def test_duplicate_task_fields_cannot_define_report_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            tasks = Path(directory) / "tasks.jsonl"
            tasks.write_text('{"id":"one","id":"two"}\n', encoding="utf-8")
            with self.assertRaises(smoke.SmokeEvidenceError):
                smoke._selected_tasks(tasks, 1)

    def test_source_drift_after_raw_report_prevents_evidence_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "agent-dev-kit"
            adk.mkdir()
            output = root / "evidence.json"
            identity = ({"agent-dev-kit.version": "7.12.2"}, {"version": "7.12.2"}, adk)
            with patch.object(smoke, "_validate_source_identity", side_effect=[
                identity, smoke.SmokeEvidenceError("source changed"),
            ]) as source:
                with patch.object(smoke, "_selected_tasks", return_value=([{"id": "case"}], "a" * 64)):
                    with patch.object(smoke, "_load_json", return_value={}):
                        with patch.object(smoke, "_validate_raw_report"):
                            with self.assertRaises(smoke.SmokeEvidenceError):
                                smoke.collect(
                                    root, output, raw_result=root / "raw.json", raw_output=None,
                                    execute=False, model="gpt-5.5", limit=1, tasks=None,
                                    runtime_binary=None, generated_at=None, review_days=30,
                                )
            self.assertEqual(source.call_count, 2)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
