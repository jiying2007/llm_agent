"""The workspace health summary reads the active ADK JSON manifest."""

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AssetInventoryContractTests(unittest.TestCase):
    def test_manifest_counts_and_inventory_gate(self):
        manifest = json.loads((ROOT / "agent-dev-kit/manifest.json").read_text(encoding="utf-8"))
        health = subprocess.run(
            ["bash", str(ROOT / "scripts/health-check.sh"), str(ROOT), "--summary-json"],
            capture_output=True, text=True,
        )
        self.assertEqual(health.returncode, 0, health.stderr)
        summary = json.loads(health.stdout)
        self.assertEqual(summary["adk_version"], manifest["version"])
        self.assertEqual(summary["adk_profiles"], len(manifest["profiles"]))
        self.assertEqual(summary["adk_workflows"], len(manifest["workflows"]))
        checked = subprocess.run(
            ["bash", str(ROOT / "scripts/check-asset-inventory.sh"), str(ROOT)],
            capture_output=True, text=True,
        )
        self.assertEqual(checked.returncode, 0, checked.stderr)


if __name__ == "__main__":
    unittest.main()
