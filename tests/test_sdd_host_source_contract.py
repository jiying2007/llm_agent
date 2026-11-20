"""Cross-repository SDD/Host *source* contract smoke; not native runtime evidence."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class SddHostSourceContractTests(unittest.TestCase):
    def test_pinned_adk_has_single_existing_sdd_route(self) -> None:
        manifest = json.loads(read("agent-dev-kit/manifest.json"))
        routes = [x for x in manifest["routing"]["intents"] if x["intent"] == "spec_driven_delivery"]
        self.assertEqual(len(routes), 1)
        self.assertEqual(routes[0]["primary_skill"], "adk-requirements-triage")
        self.assertEqual(routes[0]["mutation_permission"], "deny")
        self.assertEqual(len(manifest["skills"]), 56)
        self.assertEqual(len(manifest["optional_skills"]), 9)
        guide = read("agent-dev-kit/docs/runbooks/spec-driven-delivery.md")
        for marker in ("Canonical Change Contract", "SoC ↔ MCU UART", "not-tested"):
            self.assertIn(marker, guide)

    def test_root_reports_actual_host_effect_as_unverified(self) -> None:
        guide = read("docs/runbooks/goal-loop-token-efficiency.md")
        runtime = read("docs/runbooks/runtime-target-activation.md")
        for marker in ("requires-host-integration", "skip-model", "provider usage", "至少 10 个真实 Goal", "Root #322"):
            self.assertIn(marker, guide)
        for marker in ("source/live", "Gitlink", "不在没有 native conformance"):
            self.assertIn(marker, runtime)
        self.assertIn("不是独立的", runtime)
        self.assertIn("SDD 最小路径", read("README.md"))


if __name__ == "__main__":
    unittest.main()
