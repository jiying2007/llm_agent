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

    def test_wait_events_with_stale_model_action_never_poll(self) -> None:
        for kind in ("heartbeat", "ci_pending"):
            with self.subTest(kind=kind):
                waiting = snapshot(kind, action="model")
                first = build_plan(waiting)
                self.assertEqual(first["action"], "skip-model")
                self.assertEqual(first["reason"], "awaiting-material-event")
                self.assertFalse(first["model_invocation_required"])
                self.assertEqual(first["cursor_commit_condition"], "read-only-observation")
                # A fresh heartbeat fingerprint alone cannot authorize another
                # model turn while the underlying CI/work is still pending.
                waiting["event_sha256"] = "f" * 64
                self.assertEqual(build_plan(waiting, first["next_cursor"])["action"], "skip-model")

                high = snapshot(kind, action="model", risk="high")
                result = build_plan(high)
                self.assertEqual(result["action"], "needs-review")
                self.assertFalse(result["model_invocation_required"])
                critical = snapshot(kind, action="model", items=[evidence(1, priority="critical")])
                flagged = build_plan(critical)
                self.assertEqual(flagged["action"], "needs-review")
                self.assertEqual(flagged["reason"], "wait-event-requires-review")
                self.assertFalse(flagged["model_invocation_required"])

        # Genuine material events can still request semantic reasoning.
        for kind in ("user_updated", "ci_failed", "source_changed"):
            self.assertEqual(build_plan(snapshot(kind, action="model"))["action"], "invoke-model")

    def test_review_gate_precedes_stale_tool_and_verify(self) -> None:
        for pending in ("tool", "verify"):
            with self.subTest(pending=pending):
                review = snapshot("review_required", action=pending)
                result = build_plan(review)
                self.assertEqual(result["action"], "needs-review")
                self.assertEqual(result["reason"], "review-before-deterministic-action")
                self.assertEqual(result["cursor_commit_condition"], "after-reviewed-escalation")
                self.assertFalse(result["model_invocation_required"])
                self.assertEqual(build_plan(review, result["next_cursor"])["action"], "needs-review")

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

    def test_acknowledged_identical_tool_and_verify_do_not_replay(self) -> None:
        for pending in ("tool", "verify"):
            with self.subTest(pending=pending):
                event = snapshot(action=pending)
                first = build_plan(event)
                self.assertEqual(
                    first["action"], "run-tool" if pending == "tool" else "run-verification"
                )
                # Only a Host-acknowledged completion cursor may be reused.
                repeated = build_plan(event, first["next_cursor"])
                self.assertEqual(repeated["action"], "skip-model")
                self.assertEqual(repeated["reason"], "previously-acknowledged-unchanged-action")
                changed = copy.deepcopy(event)
                changed["event_sha256"] = "d" * 64
                self.assertEqual(build_plan(changed, first["next_cursor"])["action"], first["action"])

    def test_high_risk_deterministic_replay_requires_review(self) -> None:
        event = snapshot(action="verify", risk="high")
        prior = build_plan(event)["next_cursor"]
        next_ = build_plan(event, prior)
        self.assertEqual(next_["action"], "needs-review")
        self.assertEqual(next_["reason"], "high-risk-repeated-deterministic-action")

    def test_cursor_fingerprint_and_evidence_must_agree(self) -> None:
        event = snapshot(kind="ci_failed", action="model", items=[evidence(1)])
        original = build_plan(event)
        prior = copy.deepcopy(original["next_cursor"])
        prior["evidence"][0]["sha256"] = B
        # A forged matching fingerprint with contradictory evidence cannot
        # turn a new decision into a skip.
        self.assertEqual(build_plan(event, prior)["action"], "invoke-model")

    def test_unknown_completion_requires_review_not_fake_done(self) -> None:
        self.assertEqual(build_plan(snapshot("ci_completed"))["action"], "needs-review")
        s = snapshot()
        s["observation_complete"] = False
        self.assertEqual(build_plan(s)["reason"], "incomplete-state-observation")

    def test_incremental_changed_evidence_only(self) -> None:
        prior = build_plan(snapshot(kind="ci_failed", action="model", items=[evidence(1), evidence(2)]))["next_cursor"]
        future = snapshot(kind="ci_failed", action="model", items=[evidence(1), evidence(2, B), evidence(3, C)])
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
        current = snapshot(kind="ci_failed", action="model")
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

    def test_provider_cost_increase_blocks_token_only_improvement(self) -> None:
        for task_before, task_after in zip(self.base["tasks"], self.cand["tasks"]):
            task_before["billed_fen"] = 100
            task_after["billed_fen"] = 130
        report = compare_trials(self.base, self.cand)
        self.assertTrue(report["cost_regression"])
        self.assertEqual("PAIRED", report["cost_evidence_status"])
        self.assertLess(report["cost_per_milestone_saving_pct"], 0)
        self.assertFalse(report["candidate_for_review"])

    def test_unknown_or_partial_provider_cost_never_fabricates_savings(self) -> None:
        self.base["tasks"][0]["billed_fen"] = 100
        result = compare_trials(self.base, self.cand)
        self.assertEqual("UNAVAILABLE", result["cost_evidence_status"])
        self.assertIsNone(result["cost_per_milestone_saving_pct"])
        self.assertIsNone(result["candidate_fen_per_verified_milestone"])
        self.cand["tasks"][0]["billed_fen"] = -1
        with self.assertRaises(PreflightError):
            compare_trials(self.base, self.cand)

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

    def test_non_mapping_trial_row_is_a_validation_error(self) -> None:
        for bad in (None, 42, ["not", "a", "task"]):
            with self.subTest(bad=bad):
                altered = copy.deepcopy(self.cand)
                altered["tasks"][0] = bad
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

    def test_provider_billing_and_cache_write_subsets_are_observed(self) -> None:
        trace = {"schema": "llm-agent-goal-loop-usage-trace/v1",
                 "source": "provider-usage", "tokenizer_verified": True,
                 "requests": [dict(metered_request(0), billed_fen=25,
                                   cache_write_tokens_30m=60, cache_write_tokens_12h=40)]}
        report = attribute_usage(trace)
        self.assertEqual(report["provider_billed_fen_total"], 25)
        self.assertEqual(report["provider_cost_status"], "COMPLETE")
        self.assertEqual(report["cache_write_30m_tokens_observed"], 60)
        self.assertEqual(report["cache_write_12h_tokens_observed"], 40)
        self.assertEqual(report["uncached_input_tokens"], 100)
        self.assertEqual(report["input_tokens"], 10000)  # writes are a subset, not additive
        trace["requests"].append(metered_request(1))
        report = attribute_usage(trace)
        self.assertEqual(report["provider_cost_status"], "PARTIAL")
        self.assertIsNone(report["provider_billed_fen_total"])
        self.assertEqual(report["provider_billed_fen_observed"], 25)


    def test_model_cost_hotspots_are_bounded_and_unknown_not_attributed(self) -> None:
        trace = {"schema": "llm-agent-goal-loop-usage-trace/v1",
                 "source": "provider-usage", "tokenizer_verified": True,
                 "requests": [
                     dict(metered_request(0, 10000), model="gpt-6.1-sol", billed_fen=21),
                     dict(metered_request(1, 20000), model="gpt-6.1-sol", billed_fen=42),
                     dict(metered_request(2, 280000), model="gpt-6-astra"),
                     metered_request(3),
                 ]}
        report = attribute_usage(trace)
        self.assertEqual(report["model_count"], 2)
        self.assertEqual(report["model_observation_calls"], 3)
        self.assertEqual(report["unattributed_model_calls"], 1)
        self.assertEqual(report["top_models"][0]["model"], "gpt-6-astra")
        self.assertIsNone(report["top_models"][0]["billed_fen_total"])
        self.assertEqual(report["top_models"][0]["over_272k_calls"], 1)
        self.assertEqual(report["top_models"][1]["cached_input_tokens"], 29800)
        self.assertEqual(report["top_models"][1]["billed_fen_total"], 63)
        self.assertEqual(report["provider_cost_status"], "PARTIAL")
        self.assertIsNone(report["provider_billed_fen_total"])

    def test_model_groups_limit_cardinality_without_dropping_totals(self) -> None:
        requests = [dict(metered_request(i), model="model-" + str(i), billed_fen=1)
                    for i in range(15)]
        report = attribute_usage({"schema": "llm-agent-goal-loop-usage-trace/v1",
                                  "source": "provider-usage", "tokenizer_verified": True,
                                  "requests": requests})
        self.assertEqual(report["model_count"], 15)
        self.assertEqual(len(report["top_models"]), 10)
        self.assertEqual(report["truncated_model_summaries"], 5)
        self.assertEqual(report["provider_billed_fen_total"], 15)
        self.assertEqual(report["requests"], 15)

    def test_untrusted_or_malformed_model_identity_is_rejected(self) -> None:
        for bad in (None, 7, "../MODEL", "model with spaces", "x" * 200):
            with self.subTest(model=bad):
                trace = {"schema": "llm-agent-goal-loop-usage-trace/v1",
                         "source": "provider-usage", "tokenizer_verified": True,
                         "requests": [dict(metered_request(0), model=bad)]}
                with self.assertRaises(PreflightError):
                    attribute_usage(trace)

    def test_invalid_cache_write_metrics_fail_closed(self) -> None:
        base = {"schema": "llm-agent-goal-loop-usage-trace/v1",
                "source": "provider-usage", "tokenizer_verified": True,
                "requests": [metered_request(0)]}
        for extra in ({"cache_write_tokens_30m": 1},
                      {"cache_write_tokens_30m": 101, "cache_write_tokens_12h": 0},
                      {"billed_fen": -1},
                      {"cache_write_tokens_30m": True, "cache_write_tokens_12h": 0}):
            with self.subTest(extra=extra):
                data = copy.deepcopy(base)
                data["requests"][0].update(extra)
                with self.assertRaises(PreflightError):
                    attribute_usage(data)

    def test_trace_bad_counts_duplicates_and_prompt_injection_rejected(self) -> None:
        base = {
            "schema": "llm-agent-goal-loop-usage-trace/v1",
            "source": "provider-usage", "tokenizer_verified": True,
            "requests": [metered_request(0)],
        }
        for mutated in (
            {"requests": [metered_request(0), metered_request(0)]},
            {"requests": [None]},
            {"requests": [42]},
            {"requests": [["malformed"]]},
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
