"""Negative-path and accounting regressions for the provider-neutral call guard."""
from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.codex_assets.model_call_budget import (
    BudgetError, DEFAULT_POLICY, empty_state, ledger, replan, report, reserve,
    settle, validate_policy,
)

POLICY = validate_policy(json.loads(DEFAULT_POLICY.read_text(encoding="utf-8")))
DIGEST = "a" * 64


def request(rid: str = "r-1", inp: int = 1200, charge: int = 100, *,
            workflow: str = "adk", session: str = "session-1") -> dict:
    return {
        "schema": "llm-agent-model-call/v2", "request_id": rid,
        "workflow_id": workflow, "session_id": session, "model": "gpt-6.1-sol",
        "input_tokens_bound": inp, "max_output_tokens": 2048,
        "quoted_max_charge_fen": charge, "compaction_checked": False,
        "risk": "normal", "exception": None,
        "goal_id": None, "phase_id": None, "context_sha256": None,
    }


def settlement(rid: str = "r-1", progress: str | None = None) -> dict:
    return {
        "schema": "llm-agent-model-call-settlement/v1", "request_id": rid,
        "outcome": "success", "input_tokens": 1200,
        "cached_input_tokens": 1000, "output_tokens": 100,
        "billed_fen": 20, "progress_evidence_sha256": progress,
    }


class CallBudgetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.state = empty_state()

    def test_normal_reserve_and_report(self) -> None:
        result = reserve(request(), self.state, POLICY)
        self.assertEqual(result["status"], "allow")
        self.assertEqual(result["tokens_reserved"], 3248)
        self.assertEqual(result["charge_reserved_fen"], 100)
        r = report(self.state, POLICY)["workflows"]["adk"]
        self.assertEqual(r["requests"], 1)
        self.assertEqual(r["cny_fen_allocated"], 100)

    def test_compaction_and_soft_review(self) -> None:
        value = request(inp=96000)
        self.assertEqual(reserve(value, self.state, POLICY)["reason"], "compact-first")
        self.assertFalse(self.state["calls"])
        value["compaction_checked"] = True
        self.assertEqual(reserve(value, self.state, POLICY)["status"], "allow")
        long_req = request("r-2", inp=128001)
        long_req["compaction_checked"] = True
        self.assertEqual(reserve(long_req, self.state, POLICY)["reason"], "review-long-context")

    def test_hard_limit_and_price_cliff(self) -> None:
        for inp in (200001, 272000, 450000):
            with self.subTest(inp=inp):
                value = request("r-" + str(inp), inp=inp)
                value["compaction_checked"] = True
                self.assertEqual(reserve(value, self.state, POLICY)["status"], "blocked")
        self.assertFalse(self.state["calls"])

    def test_expensive_average_first_requests_compaction(self) -> None:
        big = request(inp=223700)
        self.assertEqual(reserve(big, self.state, POLICY)["reason"], "compact-first")
        self.assertFalse(self.state["calls"])
        big["compaction_checked"] = True
        self.assertEqual(reserve(big, self.state, POLICY)["reason"], "hard-input-limit")

    def test_high_risk_exception_requires_host_override(self) -> None:
        value = request(inp=300000)
        value.update(compaction_checked=True, risk="high",
                     exception={"approval_id": "review-123", "reason_code": "incident"})
        self.assertEqual(reserve(value, self.state, POLICY)["status"], "blocked")
        approved = reserve(value, self.state, POLICY, allow_exception=True)
        self.assertEqual(approved["status"], "allow")
        self.assertTrue(approved["long_context_price_advisory"])
        value["risk"] = "normal"
        with self.assertRaises(BudgetError):
            reserve(value, empty_state(), POLICY, allow_exception=True)

    def test_duplicate_request_and_mutated_replay_are_rejected(self) -> None:
        reserve(request(), self.state, POLICY)
        self.assertEqual(reserve(request(), self.state, POLICY)["reason"], "request-id-already-used")
        changed = request()
        changed["quoted_max_charge_fen"] = 999
        with self.assertRaises(BudgetError):
            reserve(changed, self.state, POLICY)
        self.assertEqual(len(self.state["calls"]), 1)

    def test_bad_inputs_and_prompt_injection_are_rejected(self) -> None:
        for field, bad in (
            ("input_tokens_bound", True), ("max_output_tokens", 0),
            ("quoted_max_charge_fen", -1), ("model", "x\nPROMPT"),
            ("goal_id", "a b"), ("phase_id", "a b"), ("context_sha256", "not-a-digest"),
            ("input_tokens_bound", None), ("request_id", ""),
        ):
            with self.subTest(field=field):
                value = request()
                value[field] = bad
                with self.assertRaises(BudgetError):
                    reserve(value, empty_state(), POLICY)
        value = request()
        value["raw_prompt"] = "DO NOT LOG THIS"
        with self.assertRaises(BudgetError):
            reserve(value, empty_state(), POLICY)

    def test_no_daily_money_token_or_call_hard_caps(self) -> None:
        self.assertFalse(any(key.startswith("daily_") for key in POLICY["caps"]))
        for i in range(300):
            result = reserve(request("daily-" + str(i), charge=10000), self.state, POLICY)
            self.assertEqual(result["status"], "allow")
        self.assertEqual(report(self.state, POLICY)["global"]["requests"], 300)
        self.assertEqual(report(self.state, POLICY)["global"]["cny_fen_allocated"], 3000000)

    def test_parallel_reservations_are_atomic_without_daily_stop(self) -> None:
        from concurrent.futures import ThreadPoolExecutor

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.json"

            def attempt(n: int) -> str:
                with ledger(path) as current:
                    return reserve(request("parallel-" + str(n)), current, POLICY)["status"]

            with ThreadPoolExecutor(max_workers=8) as pool:
                outcomes = list(pool.map(attempt, range(16)))
            self.assertEqual(outcomes.count("allow"), 16)
            with ledger(path, write=False) as current:
                self.assertEqual(report(current, POLICY)["global"]["requests"], 16)

    def test_quote_is_optional_telemetry_not_a_dispatch_limit(self) -> None:
        value = request(charge=0)
        self.assertEqual(reserve(value, self.state, POLICY)["status"], "allow")
        no_quote = request("unpriced")
        no_quote["quoted_max_charge_fen"] = None
        self.assertEqual(reserve(no_quote, self.state, POLICY)["status"], "allow")
        report_value = report(self.state, POLICY)["global"]
        self.assertEqual(report_value["unpriced_calls"], 1)
        self.assertEqual(report_value["cny_fen_allocated"], 0)
        no_quote_result = settlement("unpriced")
        no_quote_result["billed_fen"] = None
        self.assertTrue(settle(no_quote_result, self.state)["usage_observed"])
        self.assertEqual(report(self.state, POLICY)["global"]["unpriced_calls"], 1)

    def test_same_goal_phase_identical_context_is_not_replayed(self) -> None:
        value = request()
        value.update(goal_id="goal-a", phase_id="phase-1", context_sha256=DIGEST)
        self.assertEqual(reserve(value, self.state, POLICY)["status"], "allow")
        second = request("r-2")
        second.update(goal_id="goal-a", phase_id="phase-1", context_sha256=DIGEST)
        self.assertEqual(reserve(second, self.state, POLICY)["reason"], "identical-goal-context")
        self.assertEqual(len(self.state["calls"]), 1)
        second["phase_id"] = "phase-2"
        self.assertEqual(reserve(second, self.state, POLICY)["status"], "allow")
        third = request("r-3")
        third.update(goal_id="goal-a", phase_id="phase-1", context_sha256="b" * 64)
        self.assertEqual(reserve(third, self.state, POLICY)["status"], "allow")

    def test_same_evidence_does_not_reset_loop_stall(self) -> None:
        first = request("evidence-first")
        first["goal_id"] = "goal-a"
        self.assertEqual(reserve(first, self.state, POLICY)["status"], "allow")
        self.assertTrue(settle(settlement("evidence-first", DIGEST), self.state)["new_progress"])
        second = request("evidence-repeated")
        second["goal_id"] = "goal-a"
        self.assertEqual(reserve(second, self.state, POLICY)["status"], "allow")
        repeated = settle(settlement("evidence-repeated", DIGEST), self.state)
        self.assertFalse(repeated["new_progress"])
        self.assertEqual(repeated["no_progress_turns"], 1)
        third = request("evidence-fresh")
        third["goal_id"] = "goal-a"
        self.assertEqual(reserve(third, self.state, POLICY)["status"], "allow")
        self.assertTrue(settle(settlement("evidence-fresh", "b" * 64), self.state)["new_progress"])
        self.assertEqual(self.state["no_progress"]["adk|session-1|goal-a"], 0)

    def test_unrelated_goals_do_not_share_stall_counter(self) -> None:
        for index in range(3):
            request_id = "goal-A-" + str(index)
            value = request(request_id)
            value["goal_id"] = "goal-A"
            self.assertEqual(reserve(value, self.state, POLICY)["status"], "allow")
            settle(settlement(request_id), self.state)
        blocked = request("goal-A-stalled")
        blocked["goal_id"] = "goal-A"
        self.assertEqual(reserve(blocked, self.state, POLICY)["reason"], "no-progress-replan-required")
        other = request("goal-B-continues")
        other["goal_id"] = "goal-B"
        self.assertEqual(reserve(other, self.state, POLICY)["status"], "allow")
        self.assertEqual(self.state["no_progress"]["adk|session-1|goal-A"], 3)
        self.assertEqual(self.state["no_progress"].get("adk|session-1|goal-B", 0), 0)

    def test_replan_requires_genuine_changed_plan_fingerprints(self) -> None:
        for i in range(3):
            rid = "plan-check-" + str(i)
            value = request(rid)
            value["goal_id"] = "goal-A"
            reserve(value, self.state, POLICY)
            settle(settlement(rid), self.state)
        for before, after, evidence in (
            (DIGEST, DIGEST, "c" * 64),
            (DIGEST, "b" * 64, DIGEST),
        ):
            with self.subTest(before=before, after=after, evidence=evidence):
                with self.assertRaises(BudgetError):
                    replan(self.state, "adk", "session-1", evidence, goal_id="goal-A",
                           prior_plan_sha256=before, revised_plan_sha256=after)
        result = replan(self.state, "adk", "session-1", "c" * 64, goal_id="goal-A",
                        prior_plan_sha256=DIGEST, revised_plan_sha256="b" * 64)
        self.assertEqual(result["status"], "recorded")
        self.assertTrue(result["plan_changed"])

    def test_goal_summary_measures_tokens_per_new_progress(self) -> None:
        for i, evidence in enumerate((DIGEST, DIGEST, None)):
            rid = "goal-report-" + str(i)
            value = request(rid)
            value["goal_id"] = "goal-a"
            self.assertEqual(reserve(value, self.state, POLICY)["status"], "allow")
            settle(settlement(rid, evidence), self.state)
        result = report(self.state, POLICY)["goals"]["adk/goal-a"]
        self.assertEqual(result["calls"], 3)
        self.assertEqual(result["new_progress_events"], 1)
        self.assertEqual(result["nonclosing_calls"], 2)
        self.assertEqual(result["input_tokens_per_progress"], 3600)

    def test_settlement_and_idempotency(self) -> None:
        reserve(request(), self.state, POLICY)
        result = settle(settlement(), self.state)
        self.assertTrue(result["usage_observed"])
        self.assertEqual(result["budget_allocation_fen"], 20)
        self.assertEqual(settle(settlement(), self.state)["status"], "duplicate")
        changed = settlement()
        changed["billed_fen"] = 22
        with self.assertRaises(BudgetError):
            settle(changed, self.state)
        self.assertEqual(report(self.state, POLICY)["workflows"]["adk"]["tokens_allocated"], 1300)

    def test_unknown_usage_keeps_conservative_reservation(self) -> None:
        reserve(request(), self.state, POLICY)
        unknown = settlement()
        unknown.update(outcome="unavailable", input_tokens=None,
                       cached_input_tokens=None, output_tokens=None, billed_fen=None)
        self.assertFalse(settle(unknown, self.state)["usage_observed"])
        data = report(self.state, POLICY)["workflows"]["adk"]
        self.assertEqual(data["tokens_allocated"], 3248)
        self.assertEqual(data["cny_fen_allocated"], 100)
        self.assertEqual(data["unknown_usage"], 1)

    def test_no_progress_replan_and_verified_progress(self) -> None:
        for n in range(3):
            rid = "r-" + str(n)
            self.assertEqual(reserve(request(rid), self.state, POLICY)["status"], "allow")
            self.assertEqual(settle(settlement(rid), self.state)["no_progress_turns"], n + 1)
        self.assertEqual(reserve(request("r-4"), self.state, POLICY)["reason"],
                         "no-progress-replan-required")
        with self.assertRaises(BudgetError):
            replan(self.state, "adk", "session-1", "bad-sha",
                   prior_plan_sha256="b" * 64, revised_plan_sha256="c" * 64)
        with self.assertRaises(BudgetError):
            replan(self.state, "adk", "session-1", DIGEST,
                   prior_plan_sha256="b" * 64, revised_plan_sha256="b" * 64)
        self.assertEqual(
            replan(self.state, "adk", "session-1", DIGEST,
                   prior_plan_sha256="b" * 64, revised_plan_sha256="c" * 64)["status"],
            "recorded",
        )
        self.assertEqual(reserve(request("r-4"), self.state, POLICY)["status"], "allow")
        self.assertEqual(settle(settlement("r-4", DIGEST), self.state)["no_progress_turns"], 0)

    def test_no_duplicate_goal_stop_when_canonical_host_progress_is_verified(self) -> None:
        def goal_request(rid: str, inp: int = 1200) -> dict:
            value = request(rid, inp=inp)
            value["goal_id"] = "goal-a"
            return value

        for i in range(3):
            rid = "stalled-" + str(i)
            self.assertEqual(reserve(goal_request(rid), self.state, POLICY)["status"], "allow")
            settle(settlement(rid), self.state)
        # Standalone provider-neutral budget guard keeps its original anti-stall gate.
        self.assertEqual(reserve(goal_request("standalone-next"), self.state, POLICY)["reason"],
                         "no-progress-replan-required")
        # Trusted host checks exact canonical Execution Policy before delegating
        # progress authority. This does NOT delegate safety/context/idempotency.
        allowed = reserve(goal_request("canonical-next"), self.state, POLICY,
                          verified_external_progress_gate=True)
        self.assertEqual(allowed["status"], "allow")
        self.assertEqual(allowed["progress_control"], "canonical-host-verified")
        self.assertTrue(allowed["root_no_progress_observed"])
        self.assertEqual(self.state["no_progress"]["adk|session-1|goal-a"], 3)
        long = goal_request("canonical-long", inp=200001)
        long["compaction_checked"] = True
        self.assertEqual(reserve(long, self.state, POLICY,
                                 verified_external_progress_gate=True)["reason"],
                         "hard-input-limit")
        with self.assertRaises(BudgetError):
            reserve(request("unattributed"), self.state, POLICY,
                    verified_external_progress_gate=True)
        with self.assertRaises(BudgetError):
            reserve(goal_request("invalid-flag"), self.state, POLICY,
                    verified_external_progress_gate=1)

    def test_canonical_progress_delegation_cannot_replay_identical_context(self) -> None:
        first = request("same-a")
        first.update(goal_id="goal-a", phase_id="phase-1", context_sha256="d" * 64)
        self.assertEqual(reserve(first, self.state, POLICY)["status"], "allow")
        again = request("same-b")
        again.update(goal_id="goal-a", phase_id="phase-1", context_sha256="d" * 64)
        self.assertEqual(reserve(again, self.state, POLICY,
                                 verified_external_progress_gate=True)["reason"],
                         "identical-goal-context")

    def test_progress_requires_valid_digest_and_success(self) -> None:
        reserve(request(), self.state, POLICY)
        data = settlement("r-1", "not-sha")
        with self.assertRaises(BudgetError):
            settle(data, self.state)
        data = settlement("r-1", DIGEST)
        data["outcome"] = "error"
        with self.assertRaises(BudgetError):
            settle(data, self.state)
        data = settlement("r-1")
        data["cached_input_tokens"] = 1500
        with self.assertRaises(BudgetError):
            settle(data, self.state)

    def test_atomic_private_ledger_and_symlink_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            state_path = Path(directory) / "ledger.json"
            with ledger(state_path) as current:
                reserve(request(), current, POLICY)
            self.assertEqual(state_path.stat().st_mode & 0o777, 0o600)
            with ledger(state_path, write=False) as current:
                self.assertEqual(len(current["calls"]), 1)
            alias = Path(directory) / "alias.json"
            alias.symlink_to(state_path)
            with self.assertRaises(BudgetError):
                with ledger(alias):
                    pass

    def test_cli_cannot_self_approve_high_cost_or_fabricate_replan(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = request(inp=300000)
            payload.update(compaction_checked=True, risk="high",
                           exception={"approval_id": "review-123", "reason_code": "incident"})
            req = root / "request.json"
            req.write_text(json.dumps(payload), encoding="utf-8")
            base = [
                sys.executable, "-m", "tools.codex_assets.model_call_budget",
                "--policy", str(DEFAULT_POLICY), "--state", str(root / "ledger.json"),
            ]
            denied = subprocess.run(base + ["reserve", "--request", str(req)],
                                    capture_output=True, text=True, check=False)
            self.assertEqual(denied.returncode, 2)
            self.assertEqual(json.loads(denied.stdout)["reason"], "hard-input-limit")
            bypass = subprocess.run(base + ["reserve", "--request", str(req),
                                             "--allow-reviewed-exception"],
                                    capture_output=True, text=True, check=False)
            self.assertNotEqual(bypass.returncode, 0)
            replan_attempt = subprocess.run(base + ["replan", "--workflow-id", "adk",
                                                     "--session-id", "session-1",
                                                     "--evidence-sha256", DIGEST],
                                            capture_output=True, text=True, check=False)
            self.assertNotEqual(replan_attempt.returncode, 0)
            self.assertFalse((root / "ledger.json").exists() and
                             json.loads((root / "ledger.json").read_text())["calls"])

    def test_cli_rejects_huge_request_before_dispatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "request.json"
            value = request(inp=450000)
            value["compaction_checked"] = True
            path.write_text(json.dumps(value), encoding="utf-8")
            command = [
                sys.executable, "-m", "tools.codex_assets.model_call_budget",
                "--policy", str(DEFAULT_POLICY), "--state", str(root / "state.json"),
                "reserve", "--request", str(path),
            ]
            done = subprocess.run(command, text=True, capture_output=True, check=False)
            self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
            self.assertEqual(json.loads(done.stdout)["reason"], "hard-input-limit")


if __name__ == "__main__":
    unittest.main()
