from __future__ import annotations

import unittest
from tools.codex_assets.actions_cost_audit import summarize, SCHEMA


def run(run_id: int, name: str, conclusion: str, jobs: list[dict], sha: str = "a" * 40) -> dict:
    return {"id": run_id, "name": name, "event": "push", "head_sha": sha,
            "conclusion": conclusion, "jobs": jobs}


class CostAuditTests(unittest.TestCase):
    def test_proxy_and_billing_are_distinct(self) -> None:
        rows = [
            run(1, "CI", "success", [
                {"id": 11, "conclusion": "success",
                 "started_at": "2026-11-04T01:00:00Z",
                 "completed_at": "2026-11-04T01:02:30Z"},
                {"id": 12, "conclusion": "skipped"},
            ]),
            run(2, "CI", "cancelled", [
                {"id": 21, "conclusion": "cancelled",
                 "started_at": "2026-11-04T01:00:00Z",
                 "completed_at": None},
            ]),
        ]
        value = summarize("jiying2007/llm_agent", rows)
        self.assertEqual(value["schema"], SCHEMA)
        self.assertEqual(value["sampled_runs"], 2)
        self.assertEqual(value["observed_job_wall_minutes"], 2.5)
        self.assertEqual(value["possible_same_head_repetitions"], 1)
        self.assertIsNone(value["billable_minutes"])
        self.assertIsNone(value["usd_cost"])
        breakdown = value["workflow_breakdown"][0]
        self.assertEqual(breakdown["jobs"], 3)
        self.assertEqual(breakdown["skipped_jobs"], 1)
        self.assertEqual(breakdown["jobs_without_finished_timestamps"], 1)
        self.assertEqual(breakdown["cancelled_runs"], 1)

    def test_missing_identity_duplicate_and_negative_duration_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            summarize("../evil", [])
        with self.assertRaises(ValueError):
            summarize("jiying2007/llm_agent", [run(1, "CI", "success", []),
                                                  run(1, "CI", "success", [])])
        with self.assertRaises(ValueError):
            summarize("jiying2007/llm_agent", [run(2, "CI", "success", [
                {"id": 3, "conclusion": "success",
                 "started_at": "2026-11-04T01:03:00Z",
                 "completed_at": "2026-11-04T01:01:00Z"},
            ])])
        with self.assertRaises(ValueError):
            summarize("jiying2007/llm_agent", [run(1, "CI", "success", [{"id": 3}, {"id": 3}])])


if __name__ == "__main__":
    unittest.main()
