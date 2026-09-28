"""Fetch references may be absent locally; required source gitlinks may not."""

import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-agents-coverage.sh"


class AgentsCoverageContractTests(unittest.TestCase):
    def test_fetch_cache_absent_is_allowed_but_required_path_is_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "subrepos").mkdir()
            (root / "AGENTS.md").write_text(
                "subrepos/registry.csv\nsubrepos/adoption-matrix.md\n"
                "docs/llm-agent-maintenance-guide.md\n", encoding="utf-8",
            )
            registry = root / "subrepos/registry.csv"
            registry.write_text(
                "repo,group,priority,sync_mode,branch,enabled,notes,status\n"
                "on-demand,workflow-core,P1,fetch,main,yes,fixture,active\n",
                encoding="utf-8",
            )
            allowed = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertEqual(allowed.returncode, 0, allowed.stderr)
            self.assertIn("CACHE", allowed.stdout)
            registry.write_text(
                registry.read_text(encoding="utf-8")
                + "required-core,adk-core,P0,pull,main,yes,fixture,active\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertEqual(rejected.returncode, 2)
            self.assertIn("required-core", rejected.stdout)


if __name__ == "__main__":
    unittest.main()
