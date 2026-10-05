import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from tools.codex_assets.effect_planning import prepare

ROOT = Path(__file__).resolve().parents[1]


class EffectPlanningTests(unittest.TestCase):
    def test_plan_has_complete_population_and_never_executes_provider(self):
        value = prepare(ROOT, ROOT / "fixtures/effect-planning/tasks.jsonl", runtime="claude", model="unverified-test-model")
        self.assertEqual(value["task_count"], 12)
        self.assertEqual(value["planned_runs"], 72)
        self.assertFalse(value["provider_execution_performed"])
        self.assertFalse(value["provider_execution_allowed"])
        self.assertFalse(value["release_authorized"])
        self.assertEqual(value["controls"]["model_identity"], "alias-unverified")

    def test_cli_from_non_repository_cwd_and_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "campaign"
            command = [sys.executable, "-m", "tools.codex_assets.effect_planning", "--root", str(ROOT),
                       "--runtime", "claude", "--model", "unverified-test-model", "--out", str(target)]
            import os
            environment = dict(os.environ, PYTHONPATH=str(ROOT) + ":" + str(ROOT / "agent-dev-kit/src"))
            result = subprocess.run(command, cwd=temp, env=environment, text=True, capture_output=True, check=True)
            self.assertEqual(json.loads(result.stdout)["status"], "ready-for-review")
            before = (target / "preparation.json").read_bytes()
            again = subprocess.run(command, cwd=temp, env=environment, text=True, capture_output=True)
            self.assertEqual(again.returncode, 2)
            self.assertEqual(before, (target / "preparation.json").read_bytes())

    def test_actual_preparation_rejects_nonfinite_extra_bank_fields(self):
        raw = (ROOT / "fixtures/effect-planning/tasks.jsonl").read_text()
        first, rest = raw.split("\n", 1)
        for value in ("NaN", "Infinity", "1e999", "[" * 65 + "0" + "]" * 65):
            bad = (first[:-1] + ',"untrusted_metric":' + value + "}\n" + rest).encode()
            with self.subTest(value=value), self.assertRaises(ValueError):
                prepare(ROOT, ROOT / "fixtures/effect-planning/tasks.jsonl", runtime="claude",
                        model="unverified-test-model", bank_payload=bad)


if __name__ == "__main__":
    unittest.main()
