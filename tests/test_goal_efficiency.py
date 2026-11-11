"""Read-only Goal snapshot and job/Token observation regressions."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.control_plane.goal_efficiency import ObservationError, observe
from tools.codex_assets.goal_loop_event_context import build_plan

SHA = "a" * 40


def checkpoint() -> dict:
    return {"schema_version": "adk.current-state/v1", "goal_ref": "EP-293",
            "milestone": "CI review", "evidence_refs": ["GitHub PR #305"],
            "blockers": ["unqualified-provider"], "next_actions": ["Read CI", "Check review"],
            "history_refs": ["EP-293"]}


def jobs() -> dict:
    return {"total_count": 2, "jobs": [
        {"id": 11, "run_id": 456, "run_attempt": 1, "head_sha": SHA,
         "status": "completed", "conclusion": "success",
         "started_at": "2026-11-03T01:00:00Z", "completed_at": "2026-11-03T01:02:00Z"},
        {"id": 12, "run_id": 456, "run_attempt": 1, "head_sha": SHA,
         "status": "completed", "conclusion": "failure",
         "started_at": "2026-11-03T01:01:00Z", "completed_at": "2026-11-03T01:04:00Z"},
    ]}


def runtime() -> dict:
    return {"schema_version": "runtime_control.state/v1", "usage": {
        "observed_at": "2026-11-03T01:04:00Z",
        "input_tokens": 400, "output_tokens": 150, "cached_input_tokens": 200,
        "reasoning_tokens": 50, "total_tokens": 600,
    }}


def goal_event(kind: str = "ci_pending", action: str = "none") -> dict:
    return {
        "schema": "llm-agent-goal-loop-snapshot/v1", "workflow_id": "adk",
        "goal_id": "EP-293", "phase_id": "CI-review", "risk": "normal",
        "source_sha": SHA, "plan_sha256": "a" * 64,
        "state_sha256": "b" * 64, "event_sha256": "c" * 64,
        "event_kind": kind, "pending_action": action, "observation_complete": True,
        "evidence": [],
    }


class GoalEfficiencyTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)

    def save(self, name: str, value: dict) -> Path:
        path = self.root / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_missing_costs_are_unknown_and_completion_never_granted(self) -> None:
        report = observe(self.save("state.json", checkpoint()))
        self.assertEqual(report["status"], "OBSERVED_NOT_CERTIFIED")
        self.assertEqual(report["runtime_tokens"]["status"], "UNKNOWN")
        self.assertEqual(report["github_job_cost"]["status"], "UNKNOWN")
        self.assertIs(report["goal_completion_verified"], False)
        self.assertIs(report["production_qualified"], False)
        self.assertEqual(report["current_state"]["next_actions"], checkpoint()["next_actions"])

    def test_exact_job_time_is_not_billing_and_tokens_are_unverified(self) -> None:
        report = observe(self.save("state.json", checkpoint()),
                         jobs=self.save("jobs.json", jobs()), run_id=456,
                         attempt=1, head_sha=SHA, runtime_state=self.save("runtime.json", runtime()))
        self.assertEqual(report["github_job_cost"]["status"], "COMPLETE")
        self.assertEqual(report["github_job_cost"]["job_seconds_sum"], 300)
        self.assertEqual(report["github_job_cost"]["observed_wall_seconds"], 240)
        self.assertEqual(report["github_job_cost"]["jobs_failed"], 1)
        self.assertFalse(report["github_job_cost"]["is_billing_measurement"])
        self.assertEqual(report["runtime_tokens"]["status"], "REPORTED_UNVERIFIED")
        self.assertEqual(report["runtime_tokens"]["tokens"]["cached_input_tokens"], 200)
        self.assertFalse(report["runtime_tokens"]["billing_verified"])

    def test_partial_jobs_and_unobserved_runtime_state_remain_unknown(self) -> None:
        data = jobs()
        data["jobs"][1].update(status="in_progress", conclusion=None,
                               started_at=None, completed_at=None)
        report = observe(self.save("state.json", checkpoint()),
                         jobs=self.save("jobs.json", data), run_id=456, attempt=1, head_sha=SHA)
        self.assertEqual(report["github_job_cost"]["status"], "PARTIAL")
        self.assertEqual(report["github_job_cost"]["jobs_completed"], 1)
        state = runtime()
        state["usage"]["observed_at"] = None
        report = observe(self.save("state.json", checkpoint()),
                         runtime_state=self.save("runtime.json", state))
        self.assertEqual(report["runtime_tokens"]["status"], "UNKNOWN")

    def test_wrong_source_attempt_duplicate_and_truncated_jobs_rejected(self) -> None:
        for kind in ("sha", "attempt", "duplicate", "count", "end", "boolean", "conclusion"):
            with self.subTest(kind=kind):
                data = jobs()
                if kind == "sha":
                    data["jobs"][0]["head_sha"] = "b" * 40
                elif kind == "attempt":
                    data["jobs"][0]["run_attempt"] = 2
                elif kind == "duplicate":
                    data["jobs"][1]["id"] = 11
                elif kind == "count":
                    data["total_count"] = 1
                elif kind == "end":
                    data["jobs"][1]["completed_at"] = "2026-11-03T00:00:00Z"
                elif kind == "boolean":
                    data["jobs"][1]["id"] = True
                else:
                    data["jobs"][1]["conclusion"] = "unavailable"
                with self.assertRaises(ObservationError):
                    observe(self.save("state.json", checkpoint()),
                            jobs=self.save("jobs.json", data),
                            run_id=456, attempt=1, head_sha=SHA)

    def test_usage_wrong_counters_and_missing_date_rejected(self) -> None:
        for change in ({"cached_input_tokens": 401}, {"total_tokens": 300},
                       {"input_tokens": -1}, {"output_tokens": True},
                       {"observed_at": "invalid"}):
            with self.subTest(change=change):
                state = runtime()
                state["usage"].update(change)
                with self.assertRaises(ObservationError):
                    observe(self.save("state.json", checkpoint()),
                            runtime_state=self.save("runtime.json", state))

    def test_event_preflight_integrated_into_goal_observation(self) -> None:
        state = self.save("state.json", checkpoint())
        event = self.save("event.json", goal_event())
        report = observe(state, event_snapshot=event)
        self.assertEqual(report["event_preflight"]["status"], "ADVISORY_ONLY")
        self.assertEqual(report["event_preflight"]["action"], "skip-model")
        self.assertFalse(report["event_preflight"]["model_invocation_required"])
        self.assertEqual(report["event_preflight"]["llm_packet"]["goal_id"], "EP-293")
        self.assertFalse(report["goal_completion_verified"])
        self.assertNotIn("next_cursor", report["event_preflight"])

        changed = goal_event("ci_failed", "model")
        report = observe(state, event_snapshot=self.save("failure.json", changed))
        self.assertEqual(report["event_preflight"]["action"], "invoke-model")
        prior = build_plan(changed)["next_cursor"]
        report = observe(state, event_snapshot=self.save("failure2.json", changed),
                         event_cursor=self.save("cursor.json", prior))
        self.assertEqual(report["event_preflight"]["action"], "skip-model")

    def test_wrong_goal_and_untrusted_event_cursor_fail_closed(self) -> None:
        state = self.save("state.json", checkpoint())
        event = goal_event("ci_failed", "model")
        event["goal_id"] = "other-goal"
        with self.assertRaises(ObservationError):
            observe(state, event_snapshot=self.save("other.json", event))

        event["goal_id"] = "EP-293"
        event_path = self.save("event.json", event)
        with self.assertRaises(ObservationError):
            observe(state, event_cursor=self.save("unattached.json", {}))
        wrong = build_plan(event)["next_cursor"]
        wrong["phase_id"] = "other-phase"
        with self.assertRaises(ValueError):
            observe(state, event_snapshot=event_path,
                    event_cursor=self.save("wrong.json", wrong))
        alias = self.root / "event-link.json"
        alias.symlink_to(event_path)
        with self.assertRaises(ObservationError):
            observe(state, event_snapshot=alias)

    def test_existing_llm_ctl_routes_goal_event_preflight(self) -> None:
        src = self.save("event-cli.json", goal_event())
        result = subprocess.run(
            [sys.executable, "-m", "tools.control_plane.cli",
             "goal-loop", "preflight", "--snapshot", str(src)],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["action"], "skip-model")
        result = subprocess.run(
            [sys.executable, "-m", "tools.control_plane.cli", "goal-efficiency", "--help"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--event-snapshot", result.stdout)

    def test_bad_adk_checkpoint_and_untrusted_files_rejected(self) -> None:
        for change in ({"schema_version": "adk.current-state/v0"},
                       {"next_actions": []}, {"evidence_refs": [None]}):
            with self.subTest(change=change):
                state = checkpoint()
                state.update(change)
                with self.assertRaises(ObservationError):
                    observe(self.save("state.json", state))
        original = self.save("state.json", checkpoint())
        alias = self.root / "alias.json"
        alias.symlink_to(original)
        with self.assertRaises(ObservationError):
            observe(alias)
        original.write_text('{"schema_version":"v1","schema_version":"v2"}', encoding="utf-8")
        with self.assertRaises(ObservationError):
            observe(original)
        original.write_bytes(b" " * (256 * 1024 + 1))
        with self.assertRaises(ObservationError):
            observe(original)


if __name__ == "__main__":
    unittest.main()
