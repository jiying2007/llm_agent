"""Goal/Loop event preflight and paired-efficiency negative/positive regressions."""
from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.codex_assets.goal_loop_event_context import (
    PreflightError, build_plan, compare_trials, attribute_usage, _read,
)

A, B, C = "a" * 64, "b" * 64, "c" * 64
GIT = "e" * 40


def evidence(n: int, sha: str = A, priority: str = "normal") -> dict:
    return {"id": "result-" + str(n), "sha256": sha,
            "raw_ref": "reports/result-" + str(n) + ".json", "priority": priority}


def snapshot(kind: str = "ci_pending", action: str = "none",
             risk: str = "normal", items: list | None = None) -> dict:
    return {
        "schema": "llm-agent-goal-loop-snapshot/v1",
        "workflow_id": "main", "goal_id": "goal-a", "phase_id": "phase-1",
        "risk": risk, "source_sha": GIT, "plan_sha256": A, "state_sha256": B,
        "event_sha256": C, "event_kind": kind, "pending_action": action,
        "observation_complete": True, "evidence": items if items is not None else [],
    }


def task(name: str, tokens: int | None = 1000, completed: bool = True) -> dict:
    return {
        "task_id": name, "completed": completed, "verified_milestones": 1,
        "input_tokens": tokens, "cached_input_tokens": int(tokens * .9) if tokens is not None else None,
        "output_tokens": 100, "nonclosing_calls": 2,
        "repeated_context_calls": 1, "first_useful_action_ms": 100,
    }


def experiment(rows: list[dict]) -> dict:
    return {"schema": "llm-agent-goal-loop-comparison-set/v1",
            "task_set_sha256": C, "source_sha": GIT, "tasks": rows}


class PreflightTests(unittest.TestCase):
    def test_ci_pending_and_heartbeat_do_not_invoke(self) -> None:
        for kind in ("ci_pending", "heartbeat"):
            r = build_plan(snapshot(kind))
            self.assertEqual(r["action"], "skip-model")
            self.assertFalse(r["model_invocation_required"])
            self.assertFalse(r["owns_goal_completion"])
            self.assertFalse(r["raw_prompt_included"])

    def test_repeated_model_decision_and_source_change(self) -> None:
        s = snapshot("ci_failed", "model")
        first = build_plan(s)
        self.assertEqual(first["action"], "invoke-model")
        again = build_plan(s, first["next_cursor"])
        self.assertEqual(again["reason"], "unchanged-model-decision-input")
        changed = copy.deepcopy(s)
        changed["source_sha"] = "f" * 40
        self.assertEqual(build_plan(changed, first["next_cursor"])["action"], "invoke-model")

    def test_explicit_user_update_and_high_risk_repeat(self) -> None:
        s = snapshot("user_updated")
        self.assertEqual(build_plan(s)["action"], "invoke-model")
        prior = build_plan(s)["next_cursor"]
        self.assertEqual(build_plan(s, prior)["action"], "skip-model")
        high = snapshot("review_required", "model", risk="high")
        self.assertEqual(build_plan(high, build_plan(high)["next_cursor"])["action"], "needs-review")

    def test_deterministic_tool_and_verification_routes(self) -> None:
        for action, expected in (("tool", "run-tool"), ("verify", "run-verification")):
            r = build_plan(snapshot(action=action))
            self.assertEqual(r["action"], expected)
            self.assertFalse(r["model_invocation_required"])

    def test_unknown_completion_requires_review_not_fake_done(self) -> None:
        self.assertEqual(build_plan(snapshot("ci_completed"))["action"], "needs-review")
        s = snapshot()
        s["observation_complete"] = False
        self.assertEqual(build_plan(s)["reason"], "incomplete-state-observation")

    def test_incremental_changed_evidence_only(self) -> None:
        prior = build_plan(snapshot(action="model", items=[evidence(1), evidence(2)]))["next_cursor"]
        future = snapshot(action="model", items=[evidence(1), evidence(2, B), evidence(3, C)])
        result = build_plan(future, prior)
        self.assertEqual(result["action"], "invoke-model")
        self.assertEqual({x["id"] for x in result["llm_packet"]["evidence"]},
                         {"result-2", "result-3"})
        self.assertEqual(len(result["next_cursor"]["evidence"]), 3)

    def test_bounded_evidence_critical_priority(self) -> None:
        items = [evidence(i) for i in range(10)]
        items[-1]["priority"] = "critical"
        res = build_plan(snapshot(action="model", items=items))
        self.assertEqual(res["llm_packet"]["evidence"][0]["id"], "result-9")
        self.assertEqual(res["llm_packet"]["deferred_evidence_count"], 2)
        self.assertEqual(res["action"], "needs-review")
        high = build_plan(snapshot(action="model", risk="high", items=items))
        self.assertEqual(high["action"], "needs-review")

    def test_completeness_transition_changes_fingerprint(self) -> None:
        current = snapshot(action="model")
        current["observation_complete"] = False
        previous = build_plan(current)["next_cursor"]
        current["observation_complete"] = True
        result = build_plan(current, previous)
        self.assertEqual(result["action"], "invoke-model")
        self.assertNotEqual(result["fingerprint"], previous["fingerprint"])

    def test_cursor_commit_requires_finished_execution(self) -> None:
        result = build_plan(snapshot("ci_failed", "model"))
        self.assertEqual(result["cursor_commit_condition"], "after-model-or-tool-receipt")
        self.assertEqual(result["suggested_effort"], "high")
        self.assertEqual(build_plan(snapshot())["suggested_effort"], "none")

    def test_cursor_goals_and_phases_never_mix(self) -> None:
        s = snapshot()
        prior = build_plan(s)["next_cursor"]
        prior["goal_id"] = "another"
        with self.assertRaises(PreflightError):
            build_plan(s, prior)

    def test_negative_inputs_and_prompt_payloads_rejected(self) -> None:
        cases = [
            {"raw_prompt": "never log"},
            {"source_sha": "short"}, {"event_kind": "invented"},
            {"observation_complete": "true"},
            {"evidence": [dict(evidence(1), raw_ref="../token")]},
            {"evidence": [dict(evidence(1), raw_ref="https://attacker.example/steal")]},
            {"evidence": [evidence(1), evidence(1)]},
        ]
        for update in cases:
            with self.subTest(update=update):
                s = snapshot()
                s.update(update)
                with self.assertRaises(PreflightError):
                    build_plan(s)


class PairedTests(unittest.TestCase):
    def setUp(self) -> None:
        self.base = experiment([task(str(i), 12000) for i in range(10)])
        self.cand = experiment([task(str(i), 3000) for i in range(10)])

    def test_observed_savings_requires_paired_quality(self) -> None:
        result = compare_trials(self.base, self.cand)
        self.assertEqual(result["tasks_paired"], 10)
        self.assertEqual(result["evidence_status"], "PAIRED")
        self.assertTrue(result["candidate_for_review"])
        self.assertGreater(result["tokens_per_milestone_saving_pct"], 50)
        self.assertFalse(result["owns_goal_completion"])

    def test_small_sample_and_unknown_usage_are_insufficient(self) -> None:
        result = compare_trials(experiment(self.base["tasks"][:9]),
                                experiment(self.cand["tasks"][:9]))
        self.assertEqual(result["evidence_status"], "INSUFFICIENT")
        self.cand["tasks"][0]["input_tokens"] = None
        self.cand["tasks"][0]["cached_input_tokens"] = None
        result = compare_trials(self.base, self.cand)
        self.assertIsNone(result["tokens_per_milestone_saving_pct"])
        self.assertFalse(result["candidate_for_review"])

    def test_quality_regressions_fail_closed(self) -> None:
        self.cand["tasks"][0]["completed"] = False
        result = compare_trials(self.base, self.cand)
        self.assertTrue(result["quality_regression"])
        self.assertFalse(result["candidate_for_review"])

    def test_more_nonclosing_or_repeated_context_cannot_claim_improvement(self) -> None:
        self.cand["tasks"][0]["nonclosing_calls"] = 4
        self.assertFalse(compare_trials(self.base, self.cand)["candidate_for_review"])
        self.cand["tasks"][0]["nonclosing_calls"] = 2
        self.cand["tasks"][0]["repeated_context_calls"] = 4
        self.assertFalse(compare_trials(self.base, self.cand)["candidate_for_review"])

    def test_first_useful_action_latency_regression_blocks_review(self) -> None:
        self.cand["tasks"][0]["first_useful_action_ms"] = 10000
        report = compare_trials(self.base, self.cand)
        self.assertTrue(report["efficiency_regression"])
        self.assertFalse(report["candidate_for_review"])
        self.assertIsNotNone(report["baseline_mean_first_useful_action_ms"])

    def test_task_identity_and_cache_integrity(self) -> None:
        altered = copy.deepcopy(self.cand)
        altered["tasks"][0]["task_id"] = "unknown"
        with self.assertRaises(PreflightError):
            compare_trials(self.base, altered)
        altered = copy.deepcopy(self.cand)
        altered["tasks"][0]["cached_input_tokens"] = 999999
        with self.assertRaises(PreflightError):
            compare_trials(self.base, altered)

    def test_prompt_field_cannot_enter_ledger(self) -> None:
        self.cand["tasks"][0]["prompt"] = "secret"
        with self.assertRaises(PreflightError):
            compare_trials(self.base, self.cand)


def metered_request(n: int, total: int = 10000) -> dict:
    return {
        "request_id": "request-" + str(n), "workflow_id": "goal-loop",
        "goal_id": "research", "input_tokens": total,
        "cached_input_tokens": total - 100, "output_tokens": 100,
        "segments": [{"kind": "history", "tokens": total - 1000},
                     {"kind": "current_delta", "tokens": 1000}],
    }


class AttributionTests(unittest.TestCase):
    def test_real_usage_shape_and_3669_call_bounded_summary(self) -> None:
        trace = {
            "schema": "llm-agent-goal-loop-usage-trace/v1",
            "source": "provider-usage", "tokenizer_verified": True,
            "requests": [metered_request(i) for i in range(3669)],
        }
        result = attribute_usage(trace)
        self.assertEqual(result["attribution_status"], "COMPLETE")
        self.assertEqual(result["requests"], 3669)
        self.assertEqual(result["input_tokens"], 36690000)
        self.assertEqual(result["input_breakdown"][0]["category"], "history")
        self.assertEqual(result["workflow_count"], 1)
        self.assertLess(len(json.dumps(result)), 5000)
        self.assertFalse(result["daily_cost_hard_limit"])

    def test_unassigned_input_never_credited_to_a_category(self) -> None:
        trace = {
            "schema": "llm-agent-goal-loop-usage-trace/v1",
            "source": "provider-usage", "tokenizer_verified": True,
            "requests": [metered_request(0, 280000)],
        }
        trace["requests"][0]["segments"] = [{"kind": "history", "tokens": 200000}]
        result = attribute_usage(trace)
        self.assertEqual(result["attribution_status"], "PARTIAL")
        self.assertEqual(result["unattributed_input_tokens"], 80000)
        self.assertEqual(result["over_272k_calls"], 1)

    def test_trace_bad_counts_duplicates_and_prompt_injection_rejected(self) -> None:
        base = {
            "schema": "llm-agent-goal-loop-usage-trace/v1",
            "source": "provider-usage", "tokenizer_verified": True,
            "requests": [metered_request(0)],
        }
        for mutated in (
            {"requests": [metered_request(0), metered_request(0)]},
            {"requests": [dict(metered_request(0), input_tokens=None)]},
            {"requests": [dict(metered_request(0), prompt="SECRET")]},
            {"requests": [dict(metered_request(0), cached_input_tokens=999999)]},
            {"source": "model-inferred"},
        ):
            with self.subTest(mutated=mutated):
                item = copy.deepcopy(base)
                item.update(mutated)
                with self.assertRaises(PreflightError):
                    attribute_usage(item)

    def test_mismatched_segment_counts_are_rejected(self) -> None:
        trace = {
            "schema": "llm-agent-goal-loop-usage-trace/v1",
            "source": "provider-usage", "tokenizer_verified": True,
            "requests": [metered_request(0)],
        }
        trace["requests"][0]["segments"] = [{"kind": "history", "tokens": 20000}]
        with self.assertRaises(PreflightError):
            attribute_usage(trace)


class CliTests(unittest.TestCase):
    def test_both_cli_paths(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            s = root / "snapshot.json"
            s.write_text(json.dumps(snapshot()), encoding="utf-8")
            argv = [sys.executable, "-m", "tools.codex_assets.goal_loop_event_context"]
            r = subprocess.run(argv + ["preflight", "--snapshot", str(s)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(json.loads(r.stdout)["action"], "skip-model")
            a, b = root / "baseline.json", root / "candidate.json"
            a.write_text(json.dumps(experiment([task(str(i)) for i in range(10)])), encoding="utf-8")
            b.write_text(json.dumps(experiment([task(str(i), 500) for i in range(10)])), encoding="utf-8")
            r = subprocess.run(argv + ["compare", "--baseline", str(a),
                                       "--candidate", str(b)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(json.loads(r.stdout)["candidate_for_review"])

    def test_bad_json_and_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "bad.json"
            p.write_text('{"x":1,"x":2}', encoding="utf-8")
            with self.assertRaises(PreflightError):
                _read(p)
            link = Path(d) / "alias.json"
            link.symlink_to(p)
            with self.assertRaises(PreflightError):
                _read(link)


if __name__ == "__main__":
    unittest.main()
