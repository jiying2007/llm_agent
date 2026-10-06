from pathlib import Path
import subprocess
import tempfile
import unittest
import os

ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "scripts/check-stale-references.sh"


class StaleReferenceScopeTest(unittest.TestCase):
    def check(self, root: Path) -> subprocess.CompletedProcess:
        # Exercise the caller-independent root argument from a non-repo cwd.
        return subprocess.run(["bash", str(CHECKER), str(root)], cwd=root.parent,
                              text=True, capture_output=True)

    def test_historical_upstream_documents_are_not_active_references(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "workspace"
            retired = "scripts/" + "install_assets.sh"
            count = "97" + "/97"
            for directory in ("changes/previous", "archive/previous"):
                path = root / "agent-dev-kit/docs" / directory / "evidence.md"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(retired + "\n" + count + "\n", encoding="utf-8")
            result = self.check(root)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_current_upstream_runbook_still_rejects_retired_commands(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "workspace"
            path = root / "agent-dev-kit/docs/runbooks/current.md"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("scripts/" + "install_assets.sh\n", encoding="utf-8")
            result = self.check(root)
            self.assertEqual(1, result.returncode)
            self.assertIn(str(path), result.stderr)

    def test_current_root_governance_still_rejects_retired_commands(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "workspace"
            root.mkdir()
            path = root / "AGENTS.md"
            path.write_text("scripts/" + "validate_assets.sh\n", encoding="utf-8")
            result = self.check(root)
            self.assertEqual(1, result.returncode)
            self.assertIn("validate_assets.sh", result.stderr)

    def test_missing_ripgrep_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            env = dict(os.environ, PATH="/nonexistent-stale-reference-tools")
            result = subprocess.run(["/bin/bash", str(CHECKER), str(root)],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(2, result.returncode)
            self.assertIn("ripgrep", result.stderr)
            self.assertNotIn("[PASS]", result.stdout)

    def test_scan_error_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "workspace"
            root.mkdir()
            (root / "AGENTS.md").write_text("current guidance\n", encoding="utf-8")
            bin_dir = Path(temp) / "bin"
            bin_dir.mkdir()
            rg = bin_dir / "rg"
            rg.write_text("#!/bin/sh\nexit 2\n", encoding="utf-8")
            rg.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
            result = subprocess.run(["bash", str(CHECKER), str(root)],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(2, result.returncode)
            self.assertIn("scan failed", result.stderr)
            self.assertNotIn("[PASS]", result.stdout)


if __name__ == "__main__":
    unittest.main()
