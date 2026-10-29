"""Prevent diagnostic automation from acquiring qualification or mutation authority."""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


class QualificationWorkflowBoundaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = (ROOT / ".github/workflows/qualification-followup.yml").read_text(encoding="utf-8")
        self.workflow = yaml.load(self.raw, Loader=yaml.BaseLoader)
        self.job = self.workflow["jobs"]["followup"]
        self.steps = self.job["steps"]

    def test_only_read_permission_and_no_privileged_trigger(self) -> None:
        self.assertEqual(self.workflow["permissions"], {"contents": "read"})
        self.assertEqual(set(self.workflow["on"]), {"pull_request", "push", "schedule", "workflow_dispatch"})
        self.assertNotIn("permissions", self.job)
        self.assertNotIn("secrets.", self.raw)
        self.assertNotIn("pull_request_target", self.raw)
        self.assertNotIn("id-token", self.raw)
        self.assertNotIn("issues: write", self.raw)
        self.assertEqual(self.job["timeout-minutes"], "10")

    def test_exact_event_source_and_credentials_not_retained(self) -> None:
        checkout = next(step for step in self.steps if step.get("uses", "").startswith("actions/checkout@"))
        self.assertEqual(checkout["with"]["persist-credentials"], "false")
        self.assertNotIn("ref", checkout["with"], "PR must exercise its candidate, not silently force main")
        self.assertEqual(self.workflow["on"]["push"]["branches"], ["main"])
        self.assertEqual(self.workflow["on"]["schedule"], [{"cron": "23 1 * * *"}])

    def test_scan_failure_cannot_be_converted_to_success(self) -> None:
        collect = next(step for step in self.steps if step.get("id") == "collect")
        self.assertNotIn("continue-on-error", collect)
        self.assertIn('|| code=$?', collect["run"])
        self.assertIn('exit "$code"', collect["run"])
        self.assertIn("qualification-followup --root . --summary-json", collect["run"])
        self.assertNotIn("--as-of", collect["run"])
        self.assertNotIn("--allow-network", collect["run"])
        self.assertNotIn("--approve", collect["run"])

    def test_original_validator_fetch_is_read_only_and_tag_pinned(self) -> None:
        install = next(step for step in self.steps if step["name"].startswith("Install the pinned"))
        script = install["run"]
        self.assertIn("git submodule update --init --depth=1 agent-dev-kit", script)
        self.assertIn("git -C agent-dev-kit fetch --depth=1 origin tag v8.0.36", script)
        self.assertIn("d4b6d5c6c852b54e1f8153a3c9caa8c55d8b3ab8", script)
        self.assertIn("42ae95d146ceb441ff91ea33dbbed581c33de305", script)
        self.assertNotIn("checkout v8.0.36", script)
        self.assertNotIn("pip install", script.split("python -m pip install", 1)[0])
        self.assertEqual(self.workflow["permissions"], {"contents": "read"})

    def test_only_explicit_report_uploaded_even_after_scan_failure(self) -> None:
        upload = next(step for step in self.steps if step.get("uses", "").startswith("actions/upload-artifact@"))
        self.assertIn("always()", upload["if"])
        self.assertIn("steps.collect.outcome != 'skipped'", upload["if"])
        self.assertEqual(upload["with"]["path"], "${{ runner.temp }}/qualification-followup.json")
        self.assertEqual(upload["with"]["if-no-files-found"], "error")
        self.assertEqual(upload["with"]["retention-days"], "30")

    def test_summary_does_not_relabel_scan_as_qualification(self) -> None:
        summary = next(step for step in self.steps if step["name"].startswith("Summarize collection"))
        self.assertIn("always()", summary["if"])
        self.assertIn("report['scan_status']", summary["run"])
        self.assertIn("report['qualification_all_ready']", summary["run"])
        self.assertIn("Release authorized by this report: **false**", summary["run"])
        self.assertIn("does not certify the product or record Owner approval", summary["run"])


if __name__ == "__main__":
    unittest.main()
