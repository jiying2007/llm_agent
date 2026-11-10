"""Provider-neutral, pre-dispatch LLM token/cost guard.

The host MUST call reserve before sending a model request and settle after receiving
provider usage. This module never sends prompts or invokes a provider.
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

SCHEMA = "llm-agent-model-call-budget/v1"
REQUEST_SCHEMA = "llm-agent-model-call/v1"
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
        "daily_calls_per_workflow", "daily_tokens_per_workflow",
        "daily_spend_fen_per_workflow", "no_progress_turns",
        "daily_calls_global", "daily_tokens_global", "daily_spend_fen_global",
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
    }
    if set(value) != fields or value["schema"] != REQUEST_SCHEMA:
        raise BudgetError("request-schema-invalid")
    for name in ("request_id", "workflow_id", "session_id", "model"):
        _identity(value[name], name)
    _integer(value["input_tokens_bound"], "input_tokens_bound", allow_zero=False)
    _integer(value["max_output_tokens"], "max_output_tokens", allow_zero=False)
    _integer(value["quoted_max_charge_fen"], "quoted_max_charge_fen", allow_zero=False)
    if type(value["compaction_checked"]) is not bool or value["risk"] not in {"normal", "high"}:
        raise BudgetError("request-classification-invalid")
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
        for name in ("input_tokens", "cached_input_tokens", "output_tokens", "billed_fen"):
            _integer(value[name], name)
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


def _session_key(workflow: str, session: str) -> str:
    return workflow + "|" + session


def _day(policy: dict[str, Any], now: datetime | None = None) -> str:
    instant = now or datetime.now(timezone.utc)
    return instant.astimezone(ZoneInfo(policy["timezone"])).date().isoformat()


def reserve(
    request: dict[str, Any], state: dict[str, Any], policy: dict[str, Any],
    *, allow_exception: bool = False, now: datetime | None = None,
) -> dict[str, Any]:
    """Make one bounded reservation. The caller MUST verify approval out-of-band."""
    caps = validate_policy(policy)["caps"]
    data = validate_request(request)
    _state(state)
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
    if inp >= caps["price_cliff_input_tokens"] and not exception:
        return _decision("blocked", "long-context-price-cliff", request_id=rid)
    if inp > caps["hard_input_tokens"] and not exception:
        return _decision("blocked", "hard-input-limit", request_id=rid)
    if inp > caps["soft_input_tokens"] and not exception:
        return _decision("hold", "review-long-context", request_id=rid)

    key = _session_key(data["workflow_id"], data["session_id"])
    if state["no_progress"].get(key, 0) >= caps["no_progress_turns"]:
        return _decision("hold", "no-progress-replan-required", request_id=rid)

    day = _day(policy, now)
    today = [x for x in state["calls"].values() if x["day"] == day]
    related = [x for x in today if x["workflow_id"] == data["workflow_id"]]
    tokens = sum(x["allocated_tokens"] for x in related)
    fen = sum(x["allocated_fen"] for x in related)
    requested_tokens = inp + data["max_output_tokens"]
    if len(today) >= caps["daily_calls_global"]:
        return _decision("blocked", "global-daily-call-budget", request_id=rid)
    if sum(x["allocated_tokens"] for x in today) + requested_tokens > caps["daily_tokens_global"]:
        return _decision("blocked", "global-daily-token-budget", request_id=rid)
    if sum(x["allocated_fen"] for x in today) + data["quoted_max_charge_fen"] > caps["daily_spend_fen_global"]:
        return _decision("blocked", "global-daily-charge-budget", request_id=rid)
    if len(related) >= caps["daily_calls_per_workflow"]:
        return _decision("blocked", "daily-call-budget", request_id=rid)
    if tokens + requested_tokens > caps["daily_tokens_per_workflow"]:
        return _decision("blocked", "daily-token-budget", request_id=rid)
    if fen + data["quoted_max_charge_fen"] > caps["daily_spend_fen_per_workflow"]:
        return _decision("blocked", "daily-charge-budget", request_id=rid)

    state["calls"][rid] = {
        "request_sha256": digest,
        "workflow_id": data["workflow_id"],
        "session_id": data["session_id"],
        "model": data["model"],
        "day": day,
        "status": "reserved",
        "allocated_tokens": requested_tokens,
        "allocated_fen": data["quoted_max_charge_fen"],
        "usage": None,
        "settlement_sha256": None,
    }
    return _decision(
        "allow", "reserved", request_id=rid, day=day,
        tokens_reserved=requested_tokens,
        charge_reserved_fen=data["quoted_max_charge_fen"],
        above_target=inp > caps["target_input_tokens"],
        exception=exception,
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
    entry["usage"] = usage
    entry["status"] = "settled"
    entry["settlement_sha256"] = digest
    entry["evidence_sha256"] = data["progress_evidence_sha256"]
    key = _session_key(entry["workflow_id"], entry["session_id"])
    previous = state["no_progress"].get(key, 0)
    state["no_progress"][key] = 0 if data["progress_evidence_sha256"] else previous + 1
    return _decision(
        "recorded", "settled", request_id=rid, usage_observed=observed,
        billing_verified=False, usage_reported=observed,
        no_progress_turns=state["no_progress"][key],
        budget_allocation_fen=entry["allocated_fen"],
    )


def replan(state: dict[str, Any], workflow: str, session: str, evidence_sha256: str) -> dict[str, Any]:
    """Requires a verified changed plan/evidence, not a heartbeat or retry."""
    _state(state)
    _identity(workflow, "workflow_id")
    _identity(session, "session_id")
    digest = _sha(evidence_sha256, "replan_evidence_sha256")
    key = _session_key(workflow, session)
    if key not in state["no_progress"]:
        raise BudgetError("replan-without-session-history")
    state["no_progress"][key] = 0
    return _decision("recorded", "replanned", evidence_sha256=digest)


def report(state: dict[str, Any], policy: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    _state(state)
    validate_policy(policy)
    day = _day(policy, now)
    by_workflow: dict[str, dict[str, Any]] = {}
    for entry in state["calls"].values():
        if entry["day"] != day:
            continue
        item = by_workflow.setdefault(entry["workflow_id"], {
            "requests": 0, "reserved": 0, "tokens_allocated": 0,
            "cny_fen_allocated": 0, "unknown_usage": 0, "cached_input_tokens_observed": 0,
        })
        item["requests"] += 1
        item["reserved"] += entry["status"] == "reserved"
        item["tokens_allocated"] += entry["allocated_tokens"]
        item["cny_fen_allocated"] += entry["allocated_fen"]
        item["unknown_usage"] += entry["status"] == "settled" and entry["usage"] is None
        if entry["usage"] is not None:
            item["cached_input_tokens_observed"] += entry["usage"]["cached_input_tokens"]
    overall = {
        "requests": sum(x["requests"] for x in by_workflow.values()),
        "tokens_allocated": sum(x["tokens_allocated"] for x in by_workflow.values()),
        "cny_fen_allocated": sum(x["cny_fen_allocated"] for x in by_workflow.values()),
        "unknown_usage": sum(x["unknown_usage"] for x in by_workflow.values()),
    }
    return {"schema": SCHEMA, "status": "observed-not-provider-certified", "day": day,
            "workflows": by_workflow, "global": overall, "contains_raw_prompts": False}


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
