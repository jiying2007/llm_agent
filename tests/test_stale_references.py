from pathlib import Path
import subprocess
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()
