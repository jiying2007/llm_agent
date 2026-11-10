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
        "schema": "llm-agent-model-call/v1", "request_id": rid,
        "workflow_id": workflow, "session_id": session, "model": "gpt-6.1-sol",
        "input_tokens_bound": inp, "max_output_tokens": 2048,
        "quoted_max_charge_fen": charge, "compaction_checked": False,
        "risk": "normal", "exception": None,
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

    def test_high_risk_exception_requires_host_override(self) -> None:
        value = request(inp=300000)
        value.update(compaction_checked=True, risk="high",
                     exception={"approval_id": "review-123", "reason_code": "incident"})
        self.assertEqual(reserve(value, self.state, POLICY)["status"], "blocked")
        self.assertEqual(reserve(value, self.state, POLICY, allow_exception=True)["status"], "allow")
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

    def test_daily_limits_and_scope_isolation(self) -> None:
        reserve(request(), self.state, POLICY)
        p = copy.deepcopy(POLICY)
        p["caps"]["daily_calls_per_workflow"] = 1
        self.assertEqual(reserve(request("r-2"), self.state, p)["reason"], "daily-call-budget")
        self.assertEqual(reserve(request("r-3", workflow="other"), self.state, p)["status"], "allow")
        p = copy.deepcopy(POLICY)
        p["caps"]["daily_tokens_per_workflow"] = 5000
        self.assertEqual(reserve(request("r-4"), self.state, p)["reason"], "daily-token-budget")
        p = copy.deepcopy(POLICY)
        p["caps"]["daily_spend_fen_per_workflow"] = 110
        self.assertEqual(reserve(request("r-5", charge=20), self.state, p)["reason"], "daily-charge-budget")

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
            replan(self.state, "adk", "session-1", "bad-sha")
        self.assertEqual(replan(self.state, "adk", "session-1", DIGEST)["status"], "recorded")
        self.assertEqual(reserve(request("r-4"), self.state, POLICY)["status"], "allow")
        self.assertEqual(settle(settlement("r-4", DIGEST), self.state)["no_progress_turns"], 0)

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
