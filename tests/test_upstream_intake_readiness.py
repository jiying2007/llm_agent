"""Independent pilot repositories do not imply upstream practice adoption."""

import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-upstream-intake-readiness.sh"
MATRIX_ROW = (
    "| 2026-09-28 | superpowers | workflow-core | bounded practice | 高 | 低 | 低 "
    "| adopt | done | agent-dev-kit | reports/reference-review.md |\n"
)


class UpstreamIntakeReadinessTests(unittest.TestCase):
    def test_independent_pilot_is_excluded_but_reference_requires_adoption_row(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subrepos = root / "subrepos"
            subrepos.mkdir()
            (subrepos / "adoption-matrix.md").write_text(MATRIX_ROW, encoding="utf-8")
            registry = subrepos / "registry.csv"
            registry.write_text(
                "repo,group,priority,sync_mode,branch,enabled\n"
                "superpowers,workflow-core,P0,fetch,main,yes\n"
                "digital-worker,pilot-repo,P0,fetch,main,yes\n",
                encoding="utf-8",
            )
            accepted = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertEqual(accepted.returncode, 0, accepted.stderr)
            registry.write_text(
                registry.read_text(encoding="utf-8") + "new-reference,workflow-core,P1,fetch,main,yes\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("new-reference", rejected.stderr)


if __name__ == "__main__":
    unittest.main()
