"""Provider-neutral Goal/Loop token efficiency advisory and request guard.

No daily monetary, call-count or token-volume quota: long-running work is
governed by context quality, repeated work, verifiable progress and host gates.
The trusted host must reserve before dispatch and settle observed usage after.
No prompt, provider call or tool output is handled by this module.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import stat
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator
from zoneinfo import ZoneInfo

SCHEMA = "llm-agent-model-call-budget/v2"
REQUEST_SCHEMA = "llm-agent-model-call/v2"
SETTLEMENT_SCHEMA = "llm-agent-model-call-settlement/v1"
STATE_SCHEMA = "llm-agent-model-call-ledger/v1"
ID = re.compile(r"[A-Za-z0-9_.:/-]{1,96}\Z")
SHA256 = re.compile(r"[a-f0-9]{64}\Z")
MAX_JSON_BYTES = 32 * 1024
MAX_STATE_BYTES = 4 * 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_POLICY = ROOT / "manifests/model_call_budget.json"


class BudgetError(ValueError):
    """A malformed request, unsafe state, or unverifiable cost estimate."""


def _pairs(values: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in values:
        if key in result:
            raise BudgetError("duplicate-json-field")
        result[key] = value
    return result


def _read(path: Path, max_size: int = MAX_JSON_BYTES) -> dict[str, Any]:
    if path.is_symlink():
        raise BudgetError("symlink-input")
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(fd, "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise BudgetError("non-regular-input")
            raw = stream.read(max_size + 1)
    except OSError as exc:
        raise BudgetError("unreadable-input") from exc
    if not raw or len(raw) > max_size:
        raise BudgetError("input-size-invalid")
    try:
        result = json.loads(
            raw.decode("utf-8"), object_pairs_hook=_pairs,
            parse_constant=lambda _: (_ for _ in ()).throw(BudgetError("invalid-number")),
        )
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise BudgetError("invalid-json") from exc
    if not isinstance(result, dict):
        raise BudgetError("object-required")
    return result


def _integer(value: Any, name: str, *, allow_zero: bool = True) -> int:
    if type(value) is not int or value < (0 if allow_zero else 1):
        raise BudgetError(name + "-invalid")
    return value


def _identity(value: Any, name: str) -> str:
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise BudgetError(name + "-invalid")
    return value


def _sha(value: Any, name: str) -> str:
    if not isinstance(value, str) or not SHA256.fullmatch(value):
        raise BudgetError(name + "-invalid")
    return value


def _fingerprint(value: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_policy(value: dict[str, Any]) -> dict[str, Any]:
    if set(value) != {"schema", "timezone", "caps", "status"} or value["schema"] != SCHEMA:
        raise BudgetError("policy-schema-invalid")
    if value["status"] != "requires-host-integration":
        raise BudgetError("policy-status-invalid")
    if value["timezone"] != "Asia/Shanghai":
        raise BudgetError("policy-timezone-invalid")
    caps = value["caps"]
    names = {
        "target_input_tokens", "compact_input_tokens", "soft_input_tokens",
        "hard_input_tokens", "price_cliff_input_tokens",
        "no_progress_turns",
    }
    if not isinstance(caps, dict) or set(caps) != names:
        raise BudgetError("policy-caps-invalid")
    for name in names:
        _integer(caps[name], name, allow_zero=False)
    if not (caps["target_input_tokens"] < caps["compact_input_tokens"] <
            caps["soft_input_tokens"] < caps["hard_input_tokens"] <
            caps["price_cliff_input_tokens"]):
        raise BudgetError("policy-threshold-order-invalid")
    return value


def validate_request(value: dict[str, Any]) -> dict[str, Any]:
    fields = {
        "schema", "request_id", "workflow_id", "session_id", "model",
        "input_tokens_bound", "max_output_tokens", "quoted_max_charge_fen",
        "compaction_checked", "risk", "exception",
        "goal_id", "phase_id", "context_sha256",
    }
    if set(value) != fields or value["schema"] != REQUEST_SCHEMA:
        raise BudgetError("request-schema-invalid")
    for name in ("request_id", "workflow_id", "session_id", "model"):
        _identity(value[name], name)
    _integer(value["input_tokens_bound"], "input_tokens_bound", allow_zero=False)
    _integer(value["max_output_tokens"], "max_output_tokens", allow_zero=False)
    # Prices are telemetry, not permission or a daily limit. Missing/zero is valid.
    if value["quoted_max_charge_fen"] is not None:
        _integer(value["quoted_max_charge_fen"], "quoted_max_charge_fen")
    if type(value["compaction_checked"]) is not bool or value["risk"] not in {"normal", "high"}:
        raise BudgetError("request-classification-invalid")
    for name in ("goal_id", "phase_id"):
        if value[name] is not None:
            _identity(value[name], name)
    if value["context_sha256"] is not None:
        _sha(value["context_sha256"], "context_sha256")
    exception = value["exception"]
    if exception is not None:
        if (not isinstance(exception, dict) or set(exception) != {"approval_id", "reason_code"}
                or value["risk"] != "high"):
            raise BudgetError("exception-invalid")
        _identity(exception["approval_id"], "approval_id")
        _identity(exception["reason_code"], "reason_code")
    return value


def validate_settlement(value: dict[str, Any]) -> dict[str, Any]:
    fields = {
        "schema", "request_id", "outcome", "input_tokens", "cached_input_tokens",
        "output_tokens", "billed_fen", "progress_evidence_sha256",
    }
    if set(value) != fields or value["schema"] != SETTLEMENT_SCHEMA:
        raise BudgetError("settlement-schema-invalid")
    _identity(value["request_id"], "request_id")
    if value["outcome"] not in {"success", "error", "unavailable"}:
        raise BudgetError("outcome-invalid")
    if value["outcome"] == "unavailable":
        if any(value[name] is not None for name in (
            "input_tokens", "cached_input_tokens", "output_tokens", "billed_fen"
        )):
            raise BudgetError("unavailable-usage-must-be-null")
    else:
        for name in ("input_tokens", "cached_input_tokens", "output_tokens"):
            _integer(value[name], name)
        if value["billed_fen"] is not None:
            _integer(value["billed_fen"], "billed_fen")
        if value["cached_input_tokens"] > value["input_tokens"]:
            raise BudgetError("cached-exceeds-input")
    if value["progress_evidence_sha256"] is not None:
        _sha(value["progress_evidence_sha256"], "progress_evidence_sha256")
        if value["outcome"] != "success":
            raise BudgetError("failed-call-cannot-record-progress")
    return value


def empty_state() -> dict[str, Any]:
    return {"schema": STATE_SCHEMA, "calls": {}, "no_progress": {}}


def _state(value: dict[str, Any]) -> dict[str, Any]:
    if (set(value) != {"schema", "calls", "no_progress"} or value["schema"] != STATE_SCHEMA
            or not isinstance(value["calls"], dict) or not isinstance(value["no_progress"], dict)):
        raise BudgetError("state-schema-invalid")
    return value


@contextmanager
def ledger(path: Path, *, write: bool = True) -> Iterator[dict[str, Any]]:
    """Serialize reservations and settlements; never follow state/lock symlinks."""
    if path.is_symlink() or path.parent.is_symlink():
        raise BudgetError("symlink-state-path")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock_path = path.with_name(path.name + ".lock")
    if lock_path.is_symlink():
        raise BudgetError("symlink-lock-path")
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "r+b") as lock:
        if not stat.S_ISREG(os.fstat(lock.fileno()).st_mode):
            raise BudgetError("non-regular-lock")
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        value = _state(_read(path, MAX_STATE_BYTES)) if path.exists() else empty_state()
        yield value
        if write:
            if path.is_symlink():
                raise BudgetError("symlink-state-path")
            temp_name = ""
            try:
                with tempfile.NamedTemporaryFile(
                    mode="w", encoding="utf-8", dir=path.parent,
                    prefix=".model-call-", delete=False,
                ) as temp:
                    temp_name = temp.name
                    os.fchmod(temp.fileno(), 0o600)
                    json.dump(value, temp, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
                    temp.flush()
                    os.fsync(temp.fileno())
                os.replace(temp_name, path)
            finally:
                if temp_name and os.path.exists(temp_name):
                    os.unlink(temp_name)


def _decision(status: str, reason: str, **data: Any) -> dict[str, Any]:
    return {"schema": SCHEMA, "status": status, "reason": reason, **data}


def _session_key(workflow: str, session: str, goal_id: str | None = None) -> str:
    return workflow + "|" + session + "|" + (goal_id or "unattributed")


def _day(policy: dict[str, Any], now: datetime | None = None) -> str:
    instant = now or datetime.now(timezone.utc)
    return instant.astimezone(ZoneInfo(policy["timezone"])).date().isoformat()


def reserve(
    request: dict[str, Any], state: dict[str, Any], policy: dict[str, Any],
    *, allow_exception: bool = False, now: datetime | None = None,
    verified_external_progress_gate: bool = False,
) -> dict[str, Any]:
    """Reserve once. Host must verify any external approval/progress gate out of band.

    A positive verified_external_progress_gate is only legitimate AFTER the
    trusted host checks the canonical Execution Policy for this exact Goal.
    CLI callers cannot set it; this module never trusts model-generated claims.
    """
    caps = validate_policy(policy)["caps"]
    data = validate_request(request)
    _state(state)
    if type(verified_external_progress_gate) is not bool:
        raise BudgetError("external-progress-gate-flag-invalid")
    if verified_external_progress_gate and data["goal_id"] is None:
        raise BudgetError("external-progress-gate-requires-goal-id")
    rid = data["request_id"]
    digest = _fingerprint(data)
    if rid in state["calls"]:
        existing = state["calls"][rid]
        if existing["request_sha256"] != digest:
            raise BudgetError("request-id-reused-with-different-payload")
        return _decision("blocked", "request-id-already-used", request_id=rid)

    inp = data["input_tokens_bound"]
    exception = data["exception"] is not None and allow_exception
    if inp >= caps["compact_input_tokens"] and not data["compaction_checked"]:
        return _decision("hold", "compact-first", request_id=rid)
    if inp > caps["hard_input_tokens"] and not exception:
        return _decision("blocked", "hard-input-limit", request_id=rid)
    if inp > caps["soft_input_tokens"] and not exception:
        return _decision("hold", "review-long-context", request_id=rid)

    key = _session_key(data["workflow_id"], data["session_id"], data["goal_id"])
    stalled = state["no_progress"].get(key, 0) >= caps["no_progress_turns"]
    if stalled and not verified_external_progress_gate:
        return _decision("hold", "no-progress-replan-required", request_id=rid)
    # When canonical Goal progress has already been VERIFIED by the host,
    # do not impose a second independent Goal stop. All per-request safety,
    # context deduplication and explicit exception checks stay in force.

    # Repeat prevention is based on the trusted host's full-context digest,
    # never on similar token counts or model names. The field is optional so
    # uninstrumented hosts retain the usual contextual safety checks.
    if data["context_sha256"] is not None:
        for previous in state["calls"].values():
            if (previous.get("workflow_id") == data["workflow_id"]
                    and previous.get("session_id") == data["session_id"]
                    and previous.get("goal_id") == data["goal_id"]
                    and previous.get("phase_id") == data["phase_id"]
                    and previous.get("context_sha256") == data["context_sha256"]):
                return _decision("hold", "identical-goal-context", request_id=rid)

    day = _day(policy, now)
    requested_tokens = inp + data["max_output_tokens"]

    state["calls"][rid] = {
        "request_sha256": digest,
        "workflow_id": data["workflow_id"],
        "session_id": data["session_id"],
        "model": data["model"],
        "day": day,
        "status": "reserved",
        "allocated_tokens": requested_tokens,
        "allocated_fen": data["quoted_max_charge_fen"],
        "input_tokens_bound": inp,
        "max_output_tokens": data["max_output_tokens"],
        "goal_id": data["goal_id"],
        "phase_id": data["phase_id"],
        "context_sha256": data["context_sha256"],
        "usage": None,
        "settlement_sha256": None,
    }
    return _decision(
        "allow", "reserved", request_id=rid, day=day,
        tokens_reserved=requested_tokens,
        charge_reserved_fen=data["quoted_max_charge_fen"],
        above_target=inp > caps["target_input_tokens"],
        long_context_price_advisory=inp >= caps["price_cliff_input_tokens"],
        exception=exception,
        progress_control="canonical-host-verified" if verified_external_progress_gate else "fallback-standalone",
        root_no_progress_observed=stalled,
    )


def settle(value: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    data = validate_settlement(value)
    _state(state)
    rid = data["request_id"]
    if rid not in state["calls"]:
        raise BudgetError("settlement-without-reservation")
    entry = state["calls"][rid]
    digest = _fingerprint(data)
    if entry["status"] == "settled":
        if entry["settlement_sha256"] != digest:
            raise BudgetError("settlement-id-reused-with-different-payload")
        return _decision("duplicate", "settlement-already-recorded", request_id=rid)
    if data["outcome"] == "unavailable":
        # Preserve the conservative reservation; never treat unknown billing as zero.
        observed = False
        usage = None
    else:
        observed = True
        usage = {
            "input_tokens": data["input_tokens"],
            "cached_input_tokens": data["cached_input_tokens"],
            "output_tokens": data["output_tokens"],
            "billed_fen": data["billed_fen"],
        }
        entry["allocated_tokens"] = data["input_tokens"] + data["output_tokens"]
        entry["allocated_fen"] = data["billed_fen"]
    evidence = data["progress_evidence_sha256"]
    new_evidence = bool(evidence) and not any(
        other.get("workflow_id") == entry["workflow_id"]
        and other.get("session_id") == entry["session_id"]
        and other.get("goal_id") == entry.get("goal_id")
        and other.get("evidence_sha256") == evidence
        for other_id, other in state["calls"].items() if other_id != rid
    )
    entry["usage"] = usage
    entry["status"] = "settled"
    entry["settlement_sha256"] = digest
    entry["evidence_sha256"] = evidence
    entry["new_progress"] = bool(new_evidence)
    key = _session_key(entry["workflow_id"], entry["session_id"], entry.get("goal_id"))
    previous = state["no_progress"].get(key, 0)
    state["no_progress"][key] = 0 if new_evidence else previous + 1
    return _decision(
        "recorded", "settled", request_id=rid, usage_observed=observed,
        billing_verified=False, usage_reported=observed,
        new_progress=bool(new_evidence),
        no_progress_turns=state["no_progress"][key],
        budget_allocation_fen=entry["allocated_fen"],
    )


def replan(
    state: dict[str, Any], workflow: str, session: str, evidence_sha256: str,
    *, goal_id: str | None = None, prior_plan_sha256: str,
    revised_plan_sha256: str,
) -> dict[str, Any]:
    """Trusted-host API; only a changed plan plus evidence can reset a stalled Goal."""
    _state(state)
    _identity(workflow, "workflow_id")
    _identity(session, "session_id")
    if goal_id is not None:
        _identity(goal_id, "goal_id")
    digest = _sha(evidence_sha256, "replan_evidence_sha256")
    before = _sha(prior_plan_sha256, "prior_plan_sha256")
    after = _sha(revised_plan_sha256, "revised_plan_sha256")
    if before == after or digest in (before, after):
        raise BudgetError("replan-must-change-plan-with-independent-evidence")
    key = _session_key(workflow, session, goal_id)
    if key not in state["no_progress"]:
        raise BudgetError("replan-without-goal-history")
    state["no_progress"][key] = 0
    return _decision("recorded", "replanned", evidence_sha256=digest,
                     plan_changed=True)


def report(state: dict[str, Any], policy: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    _state(state)
    validate_policy(policy)
    day = _day(policy, now)
    by_workflow: dict[str, dict[str, Any]] = {}
    by_goal: dict[str, dict[str, Any]] = {}
    for entry in state["calls"].values():
        if entry["day"] != day:
            continue
        workflow = entry["workflow_id"]
        item = by_workflow.setdefault(workflow, {
            "requests": 0, "reserved": 0, "tokens_allocated": 0,
            "cny_fen_allocated": 0, "unpriced_calls": 0,
            "unknown_usage": 0, "cached_input_tokens_observed": 0,
        })
        item["requests"] += 1
        item["reserved"] += entry["status"] == "reserved"
        item["tokens_allocated"] += entry["allocated_tokens"]
        item["cny_fen_allocated"] += entry["allocated_fen"] or 0
        item["unpriced_calls"] += entry["allocated_fen"] is None
        item["unknown_usage"] += entry["status"] == "settled" and entry["usage"] is None
        if entry["usage"] is not None:
            item["cached_input_tokens_observed"] += entry["usage"]["cached_input_tokens"]
        # Do not mistake missing progress evidence for completion. Both goal
        # and phase identities are optional, and raw context never appears here.
        goal_key = workflow + "/" + (entry.get("goal_id") or "unattributed")
        goal = by_goal.setdefault(goal_key, {
            "calls": 0, "input_tokens_observed": 0, "unknown_usage": 0,
            "new_progress_events": 0, "nonclosing_calls": 0,
        })
        goal["calls"] += 1
        usage = entry.get("usage")
        if usage is not None:
            goal["input_tokens_observed"] += usage["input_tokens"]
        else:
            goal["unknown_usage"] += 1
        if entry.get("status") == "settled":
            goal["new_progress_events"] += bool(entry.get("new_progress", False))
            goal["nonclosing_calls"] += not entry.get("new_progress", False)

    for goal in by_goal.values():
        count = goal["new_progress_events"]
        goal["input_tokens_per_progress"] = (
            round(goal["input_tokens_observed"] / count)
            if count and not goal["unknown_usage"] else None
        )
    overall = {
        "requests": sum(x["requests"] for x in by_workflow.values()),
        "tokens_allocated": sum(x["tokens_allocated"] for x in by_workflow.values()),
        "cny_fen_allocated": sum(x["cny_fen_allocated"] for x in by_workflow.values()),
        "unpriced_calls": sum(x["unpriced_calls"] for x in by_workflow.values()),
        "unknown_usage": sum(x["unknown_usage"] for x in by_workflow.values()),
    }
    # Bound this human/agent summary; the complete ledger remains external.
    top_goals = sorted(by_goal.items(), key=lambda x: (-x[1]["input_tokens_observed"], x[0]))[:10]
    return {"schema": SCHEMA, "status": "observed-not-provider-certified", "day": day,
            "workflows": by_workflow, "global": overall,
            "goals": dict(top_goals), "goals_total": len(by_goal),
            "truncated_goal_summaries": max(0, len(by_goal) - len(top_goals)),
            "contains_raw_prompts": False, "hard_daily_limits": False}


def _main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--state", type=Path, required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    reserve_cli = sub.add_parser("reserve", help="Atomic pre-dispatch budget reservation")
    reserve_cli.add_argument("--request", type=Path, required=True)
    settle_cli = sub.add_parser("settle", help="Post-dispatch usage settlement")
    settle_cli.add_argument("--usage", type=Path, required=True)
    sub.add_parser("report", help="Bounded daily accounting by workflow")
    args = parser.parse_args()
    try:
        policy = validate_policy(_read(args.policy))
        with ledger(args.state, write=args.command != "report") as current:
            if args.command == "reserve":
                result = reserve(_read(args.request), current, policy)
            elif args.command == "settle":
                result = settle(_read(args.usage), current)
            else:
                result = report(current, policy)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0 if result["status"] in {"allow", "recorded", "duplicate", "observed-not-provider-certified"} else 2
    except (BudgetError, OSError) as exc:
        print(json.dumps(_decision("error", str(exc)), ensure_ascii=False, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(_main())
