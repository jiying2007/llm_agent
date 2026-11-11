"""Bounded Goal/Loop event preflight and paired efficiency evaluation.

No model calls, daemon, scheduler, raw messages, autonomous approval, or Goal
completion authority. A trusted host supplies versioned event/usage metadata.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import stat
from pathlib import Path
from typing import Any, Mapping, Sequence

SNAPSHOT_SCHEMA = "llm-agent-goal-loop-snapshot/v1"
CURSOR_SCHEMA = "llm-agent-goal-loop-cursor/v1"
PLAN_SCHEMA = "llm-agent-goal-loop-context-plan/v1"
EXPERIMENT_SCHEMA = "llm-agent-goal-loop-comparison-set/v1"
REPORT_SCHEMA = "llm-agent-goal-loop-comparison/v1"
TRACE_SCHEMA = "llm-agent-goal-loop-usage-trace/v1"
TRACE_REPORT_SCHEMA = "llm-agent-goal-loop-attribution/v1"
MAX_TRACE_BYTES = 4 * 1024 * 1024
ID = re.compile(r"[A-Za-z0-9_.:/-]{1,96}\Z")
SHA40 = re.compile(r"[0-9a-f]{40}\Z")
SHA64 = re.compile(r"[0-9a-f]{64}\Z")
REL_REF = re.compile(r"[A-Za-z0-9_./:-]{1,180}\Z")
MAX_FILE = 128 * 1024
MAX_EVIDENCE = 64
MAX_PACKET = 8


class PreflightError(ValueError):
    """Malformed or untrusted metadata must not become a no-model decision."""


def _pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in items:
        if key in out:
            raise PreflightError("duplicate-field")
        out[key] = value
    return out


def _read(path: Path, *, max_bytes: int = MAX_FILE) -> dict[str, Any]:
    if path.is_symlink():
        raise PreflightError("symlink-input")
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        with os.fdopen(fd, "rb") as handle:
            if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
                raise PreflightError("non-regular-input")
            raw = handle.read(max_bytes + 1)
    except OSError as exc:
        raise PreflightError("unreadable-input") from exc
    if not raw or len(raw) > max_bytes:
        raise PreflightError("input-size-invalid")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_constant=lambda _: (_ for _ in ()).throw(PreflightError("nonfinite")))
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise PreflightError("invalid-json") from exc
    if not isinstance(value, dict):
        raise PreflightError("object-required")
    return value


def _fields(obj: Any, fields: set[str], name: str) -> dict[str, Any]:
    if not isinstance(obj, dict) or set(obj) != fields:
        raise PreflightError(name + "-fields-invalid")
    return obj


def _id(value: Any, name: str) -> str:
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise PreflightError(name + "-invalid")
    return value


def _sha(value: Any, name: str, length: int = 64) -> str:
    if not isinstance(value, str) or not (SHA40 if length == 40 else SHA64).fullmatch(value):
        raise PreflightError(name + "-invalid")
    return value


def _int(value: Any, name: str) -> int:
    if type(value) is not int or value < 0:
        raise PreflightError(name + "-invalid")
    return value


def _ref(value: Any) -> str:
    """Opaque reproducible source locator, not an instruction or credential."""
    if (not isinstance(value, str) or not REL_REF.fullmatch(value)
            or value.startswith("/") or value.startswith(".")
            or any(part in {".", ".."} for part in value.split("/"))
            or "://" in value and not value.startswith("https://github.com/")):
        raise PreflightError("raw-ref-invalid")
    return value


def _hash(obj: Any) -> str:
    return hashlib.sha256(
        json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    ).hexdigest()


def _evidence(items: Any, *, cursor: bool = False) -> list[dict[str, Any]]:
    if not isinstance(items, list) or len(items) > MAX_EVIDENCE:
        raise PreflightError("evidence-count-invalid")
    seen: set[str] = set()
    result = []
    for entry in items:
        obj = _fields(
            entry,
            {"id", "sha256"} if cursor else {"id", "sha256", "raw_ref", "priority"},
            "evidence",
        )
        name = _id(obj["id"], "evidence-id")
        if name in seen:
            raise PreflightError("duplicate-evidence-id")
        seen.add(name)
        digest = _sha(obj["sha256"], "evidence-sha256")
        if cursor:
            result.append({"id": name, "sha256": digest})
        else:
            if obj["priority"] not in ("normal", "critical"):
                raise PreflightError("evidence-priority-invalid")
            result.append({"id": name, "sha256": digest, "raw_ref": _ref(obj["raw_ref"]),
                           "priority": obj["priority"]})
    return result


def _snapshot(value: Mapping[str, Any]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    fields = {
        "schema", "workflow_id", "goal_id", "phase_id", "risk", "source_sha",
        "plan_sha256", "state_sha256", "event_sha256", "event_kind",
        "pending_action", "observation_complete", "evidence",
    }
    if not isinstance(value, dict):
        raise PreflightError("snapshot-object-required")
    data = _fields(value, fields, "snapshot")
    if data["schema"] != SNAPSHOT_SCHEMA:
        raise PreflightError("snapshot-schema-invalid")
    for field in ("workflow_id", "goal_id", "phase_id"):
        _id(data[field], field)
    _sha(data["source_sha"], "source-sha", 40)
    for field in ("plan_sha256", "state_sha256", "event_sha256"):
        _sha(data[field], field)
    if data["risk"] not in ("normal", "high"):
        raise PreflightError("risk-invalid")
    if data["event_kind"] not in (
        "heartbeat", "ci_pending", "ci_completed", "ci_failed", "source_changed",
        "user_updated", "tool_result", "review_required",
    ):
        raise PreflightError("event-kind-invalid")
    if data["pending_action"] not in ("none", "tool", "verify", "model"):
        raise PreflightError("pending-action-invalid")
    if type(data["observation_complete"]) is not bool:
        raise PreflightError("observation-completeness-invalid")
    evidence = _evidence(data["evidence"])
    tracked = {key: data[key] for key in fields - {"schema", "evidence"}}
    tracked["evidence"] = sorted(
        ({"id": e["id"], "sha256": e["sha256"]} for e in evidence),
        key=lambda e: e["id"],
    )
    return tracked, evidence


def _cursor(value: Any, workflow: str, goal: str, phase: str) -> dict[str, Any] | None:
    if value is None:
        return None
    current = _fields(value, {"schema", "workflow_id", "goal_id", "phase_id",
                              "fingerprint", "evidence"}, "cursor")
    if (current["schema"] != CURSOR_SCHEMA
            or current["workflow_id"] != workflow
            or current["goal_id"] != goal or current["phase_id"] != phase):
        raise PreflightError("cursor-scope-mismatch")
    _sha(current["fingerprint"], "cursor-fingerprint")
    _evidence(current["evidence"], cursor=True)
    return current


def build_plan(snapshot: dict[str, Any], prior: dict[str, Any] | None = None) -> dict[str, Any]:
    """Return an advisory decision and tiny context, with lossless external cursor."""
    tracked, evidence = _snapshot(snapshot)
    cursor = _cursor(prior, snapshot["workflow_id"], snapshot["goal_id"], snapshot["phase_id"])
    fingerprint = _hash(tracked)
    prior_evidence = {item["id"]: item["sha256"] for item in cursor["evidence"]} if cursor else {}
    changed = [entry for entry in evidence if prior_evidence.get(entry["id"]) != entry["sha256"]]
    changed.sort(key=lambda e: (e["priority"] != "critical", e["id"]))
    deferred = max(0, len(changed) - MAX_PACKET)
    unshown_critical = any(e["priority"] == "critical" for e in changed[MAX_PACKET:])
    complete = snapshot["observation_complete"]
    # A fingerprint cannot be treated as an execution receipt if its evidence
    # index contradicts the current snapshot. The trusted host still owns
    # receipt verification before persisting next_cursor.
    same_evidence = bool(cursor and sorted(cursor["evidence"], key=lambda e: e["id"]) == tracked["evidence"])
    repeated = bool(cursor and cursor["fingerprint"] == fingerprint and same_evidence)

    action = "skip-model"
    reason = "no-model-action"
    if not complete:
        action, reason = "needs-review", "incomplete-state-observation"
    elif (snapshot["event_kind"] == "review_required"
          and snapshot["pending_action"] in ("tool", "verify")):
        # A review gate is not a tool-execution authorization. Do not let an
        # old queued deterministic action silently bypass a fresh review.
        action, reason = "needs-review", "review-before-deterministic-action"
    elif (snapshot["event_kind"] in ("heartbeat", "ci_pending")
          and snapshot["pending_action"] == "model"):
        # A stale queued model action is not evidence of new work. A changing
        # heartbeat/event SHA must never turn CI waiting into LLM polling.
        # High-risk inconsistency remains visible rather than auto-skipped.
        if snapshot["risk"] == "high" or any(
            entry["priority"] == "critical" for entry in changed
        ):
            action, reason = "needs-review", "wait-event-requires-review"
        else:
            action, reason = "skip-model", "awaiting-material-event"
    elif snapshot["pending_action"] in ("tool", "verify"):
        # The caller is only allowed to persist a previous cursor AFTER the
        # corresponding tool/verification receipt has been checked. A repeated
        # cursor is therefore an acknowledged deterministic action, not a new
        # job that must run again. Do not skip high-risk review.
        if repeated and snapshot["risk"] == "high":
            action, reason = "needs-review", "high-risk-repeated-deterministic-action"
        elif repeated:
            action, reason = "skip-model", "previously-acknowledged-unchanged-action"
        elif snapshot["pending_action"] == "tool":
            action, reason = "run-tool", "deterministic-tool-action"
        else:
            action, reason = "run-verification", "deterministic-verification"
    elif snapshot["pending_action"] == "model" or snapshot["event_kind"] in (
        "user_updated", "ci_failed", "source_changed", "review_required",
    ):
        if repeated and snapshot["risk"] == "normal":
            action, reason = "skip-model", "unchanged-model-decision-input"
        elif repeated:
            action, reason = "needs-review", "high-risk-repeated-decision"
        else:
            action, reason = "invoke-model", "material-decision-request"
    elif snapshot["event_kind"] in ("ci_completed", "tool_result") and not repeated:
        action, reason = "needs-review", "new-event-without-action-routing"

    # Never send a model an incomplete evidence packet without review.
    if unshown_critical or (deferred and action == "invoke-model"):
        action, reason = "needs-review", "unreviewed-evidence-overflow"

    brief = {
        "workflow_id": snapshot["workflow_id"], "goal_id": snapshot["goal_id"],
        "phase_id": snapshot["phase_id"], "risk": snapshot["risk"],
        "source_sha": snapshot["source_sha"],
        "state_sha256": snapshot["state_sha256"],
        "plan_sha256": snapshot["plan_sha256"],
        "event_kind": snapshot["event_kind"],
        "evidence": [
            {"id": e["id"], "sha256": e["sha256"], "raw_ref": e["raw_ref"]}
            for e in changed[:MAX_PACKET]
        ],
        "deferred_evidence_count": deferred,
        "full_evidence_index_sha256": _hash(tracked["evidence"]),
    }
    next_cursor = {
        "schema": CURSOR_SCHEMA, "workflow_id": snapshot["workflow_id"],
        "goal_id": snapshot["goal_id"], "phase_id": snapshot["phase_id"],
        "fingerprint": fingerprint, "evidence": tracked["evidence"],
    }
    return {
        "schema": PLAN_SCHEMA, "status": "observed-not-host-certified",
        "action": action, "reason": reason, "fingerprint": fingerprint,
        "model_invocation_required": action == "invoke-model",
        "llm_packet": brief, "next_cursor": next_cursor,
        "raw_prompt_included": False, "owns_goal_completion": False,
        "cursor_commit_condition": (
            "after-model-or-tool-receipt" if action in {"invoke-model", "run-tool", "run-verification"}
            else "after-reviewed-escalation" if action == "needs-review" else "read-only-observation"
        ),
        "suggested_effort": (
            "none" if action != "invoke-model"
            else "high" if snapshot["risk"] == "high"
            or snapshot["event_kind"] in ("ci_failed", "review_required")
            else "balanced"
        ),
    }


def _experiment(value: dict[str, Any]) -> tuple[str, dict[str, dict[str, Any]]]:
    data = _fields(value, {"schema", "task_set_sha256", "source_sha", "tasks"}, "experiment")
    if data["schema"] != EXPERIMENT_SCHEMA:
        raise PreflightError("experiment-schema-invalid")
    _sha(data["task_set_sha256"], "task-set-sha")
    _sha(data["source_sha"], "experiment-source-sha", 40)
    if not isinstance(data["tasks"], list) or len(data["tasks"]) > 1000:
        raise PreflightError("experiment-task-count-invalid")
    seen: dict[str, dict[str, Any]] = {}
    fields = {"task_id", "completed", "verified_milestones",
              "input_tokens", "cached_input_tokens", "output_tokens",
              "nonclosing_calls", "repeated_context_calls", "first_useful_action_ms"}
    for task in data["tasks"]:
        item = _fields(task, fields, "task")
        task_id = _id(item["task_id"], "task-id")
        if task_id in seen or type(item["completed"]) is not bool:
            raise PreflightError("duplicate-or-malformed-task")
        for key in ("verified_milestones", "nonclosing_calls", "repeated_context_calls"):
            _int(item[key], key)
        for key in ("input_tokens", "cached_input_tokens", "output_tokens", "first_useful_action_ms"):
            if item[key] is not None:
                _int(item[key], key)
        if (item["input_tokens"] is not None and item["cached_input_tokens"] is not None
                and item["cached_input_tokens"] > item["input_tokens"]):
            raise PreflightError("cached-input-exceeds-total-input")
        seen[task_id] = item
    return data["task_set_sha256"], seen


def compare_trials(baseline: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    """Paired observed metrics only. Never promote a candidate or certify a Goal."""
    source_a, base = _experiment(baseline)
    source_b, cand = _experiment(candidate)
    if source_a != source_b or set(base) != set(cand):
        raise PreflightError("paired-task-set-identity-drift")
    complete = len(base) >= 10 and all(
        task[key] is not None for task in list(base.values()) + list(cand.values())
        for key in ("input_tokens", "output_tokens", "cached_input_tokens")
    )
    if complete:
        before_tokens = sum(t["input_tokens"] + t["output_tokens"] for t in base.values())
        after_tokens = sum(t["input_tokens"] + t["output_tokens"] for t in cand.values())
        before_milestones = sum(t["verified_milestones"] for t in base.values())
        after_milestones = sum(t["verified_milestones"] for t in cand.values())
        complete = bool(before_milestones and after_milestones)
    else:
        before_tokens = after_tokens = before_milestones = after_milestones = 0
    no_regressions = all(
        (cand[key]["completed"] or not base[key]["completed"])
        and cand[key]["verified_milestones"] >= base[key]["verified_milestones"]
        for key in base
    )
    savings = round(100 * (1 - (after_tokens / after_milestones) /
                           (before_tokens / before_milestones)), 2) if complete else None
    base_nonclosing = sum(t["nonclosing_calls"] for t in base.values())
    cand_nonclosing = sum(t["nonclosing_calls"] for t in cand.values())
    base_repeated = sum(t["repeated_context_calls"] for t in base.values())
    cand_repeated = sum(t["repeated_context_calls"] for t in cand.values())
    latency_complete = all(
        t["first_useful_action_ms"] is not None for t in list(base.values()) + list(cand.values())
    )
    avg_before_ms = (round(sum(t["first_useful_action_ms"] for t in base.values()) / len(base), 2)
                     if latency_complete and base else None)
    avg_after_ms = (round(sum(t["first_useful_action_ms"] for t in cand.values()) / len(cand), 2)
                    if latency_complete and cand else None)
    no_efficiency_regression = (
        cand_nonclosing <= base_nonclosing and cand_repeated <= base_repeated
        and (not latency_complete or avg_after_ms <= avg_before_ms * 1.10)
    )
    return {
        "schema": REPORT_SCHEMA, "status": "observed-not-provider-certified",
        "evidence_status": "PAIRED" if complete else "INSUFFICIENT",
        "task_set_sha256": source_a, "tasks_paired": len(base),
        "completed_baseline": sum(t["completed"] for t in base.values()),
        "completed_candidate": sum(t["completed"] for t in cand.values()),
        "quality_regression": not no_regressions,
        "baseline_tokens_per_verified_milestone": (
            round(before_tokens / before_milestones, 2) if complete else None
        ),
        "candidate_tokens_per_verified_milestone": (
            round(after_tokens / after_milestones, 2) if complete else None
        ),
        "tokens_per_milestone_saving_pct": savings,
        "baseline_nonclosing_calls": base_nonclosing,
        "candidate_nonclosing_calls": cand_nonclosing,
        "baseline_repeated_context_calls": base_repeated,
        "candidate_repeated_context_calls": cand_repeated,
        "baseline_mean_first_useful_action_ms": avg_before_ms,
        "candidate_mean_first_useful_action_ms": avg_after_ms,
        "efficiency_regression": not no_efficiency_regression,
        "candidate_for_review": bool(
            complete and no_regressions and no_efficiency_regression
            and savings is not None and savings > 0
        ),
        "owns_goal_completion": False,
    }



def attribute_usage(value: dict[str, Any]) -> dict[str, Any]:
    """Reconcile host-tokenized segments to provider-reported input tokens.

    This is observational. Provider hidden tokens and tokenizer mismatch remain
    explicit unattributed input rather than fabricated category savings.
    """
    data = _fields(value, {"schema", "source", "tokenizer_verified", "requests"}, "usage-trace")
    if data["schema"] != TRACE_SCHEMA or data["source"] != "provider-usage":
        raise PreflightError("usage-source-invalid")
    if type(data["tokenizer_verified"]) is not bool:
        raise PreflightError("tokenizer-trust-invalid")
    rows = data["requests"]
    if not isinstance(rows, list) or not 0 < len(rows) <= 10000:
        raise PreflightError("usage-requests-count-invalid")
    allowed = {"rules", "tool_schemas", "history", "tool_results",
               "project_source", "goal_state", "current_delta", "other"}
    count: dict[str, int] = {key: 0 for key in allowed}
    seen: set[str] = set()
    workflow_counts: dict[str, dict[str, int]] = {}
    inputs: list[int] = []
    total_input = total_cached = total_output = unknown = zero_output = 0
    for entry in rows:
        r = _fields(entry, {"request_id", "workflow_id", "goal_id", "input_tokens",
                            "cached_input_tokens", "output_tokens", "segments"}, "usage-request")
        req_id = _id(r["request_id"], "request-id")
        workflow = _id(r["workflow_id"], "workflow-id")
        if r["goal_id"] is not None:
            _id(r["goal_id"], "goal-id")
        if req_id in seen:
            raise PreflightError("duplicate-request-id")
        seen.add(req_id)
        inp = _int(r["input_tokens"], "input_tokens")
        cached = _int(r["cached_input_tokens"], "cached_input_tokens")
        output = _int(r["output_tokens"], "output_tokens")
        if not 0 < inp or cached > inp:
            raise PreflightError("usage-counters-invalid")
        if not isinstance(r["segments"], list) or len(r["segments"]) > len(allowed):
            raise PreflightError("usage-segments-invalid")
        subtotal = 0
        kinds: set[str] = set()
        for piece in r["segments"]:
            part = _fields(piece, {"kind", "tokens"}, "usage-segment")
            kind = part["kind"]
            if kind not in allowed or kind in kinds:
                raise PreflightError("usage-segment-kind-invalid")
            kinds.add(kind)
            n = _int(part["tokens"], "segment-tokens")
            count[kind] += n
            subtotal += n
        if subtotal > inp:
            raise PreflightError("segments-exceed-provider-input")
        unknown += inp - subtotal
        total_input += inp
        total_cached += cached
        total_output += output
        zero_output += (output == 0)
        inputs.append(inp)
        item = workflow_counts.setdefault(workflow, {"calls": 0, "input_tokens": 0, "output_tokens": 0})
        item["calls"] += 1
        item["input_tokens"] += inp
        item["output_tokens"] += output
    ordered = sorted(inputs)
    def percentile(fraction: float) -> int:
        return ordered[max(0, math.ceil(fraction * len(ordered)) - 1)]
    by_type = [
        {"category": key, "tokens": val, "share_of_input_pct": round(val * 100 / total_input, 2)}
        for key, val in sorted(count.items(), key=lambda pair: (-pair[1], pair[0]))
    ]
    top = [
        {"workflow_id": key, **item}
        for key, item in sorted(workflow_counts.items(), key=lambda pair: (-pair[1]["input_tokens"], pair[0]))[:10]
    ]
    return {
        "schema": TRACE_REPORT_SCHEMA, "status": "observed-not-provider-certified",
        "attribution_status": "COMPLETE" if data["tokenizer_verified"] and unknown == 0 else "PARTIAL",
        "requests": len(rows), "input_tokens": total_input,
        "cached_input_tokens": total_cached, "output_tokens": total_output,
        "cache_hit_pct": round(100 * total_cached / total_input, 2),
        "mean_input_tokens": round(total_input / len(rows), 2),
        "median_input_tokens": percentile(0.5), "p95_input_tokens": percentile(0.95),
        "over_272k_calls": sum(1 for x in inputs if x > 272000),
        "zero_output_calls": zero_output, "unattributed_input_tokens": unknown,
        "input_breakdown": by_type, "top_workflows": top,
        "workflow_count": len(workflow_counts), "raw_messages_included": False,
        "daily_cost_hard_limit": False, "owns_goal_completion": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    choices = parser.add_subparsers(dest="command", required=True)
    preflight = choices.add_parser("preflight")
    preflight.add_argument("--snapshot", type=Path, required=True)
    preflight.add_argument("--previous", type=Path)
    trace = choices.add_parser("attribute")
    trace.add_argument("--trace", type=Path, required=True)
    comparison = choices.add_parser("compare")
    comparison.add_argument("--baseline", type=Path, required=True)
    comparison.add_argument("--candidate", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            response = build_plan(_read(args.snapshot), _read(args.previous) if args.previous else None)
        elif args.command == "attribute":
            response = attribute_usage(_read(args.trace, max_bytes=MAX_TRACE_BYTES))
        else:
            response = compare_trials(_read(args.baseline), _read(args.candidate))
    except (PreflightError, OSError, ValueError, KeyError) as exc:
        print(json.dumps({"status": "REJECTED", "reason": str(exc), "owns_goal_completion": False}))
        return 2
    print(json.dumps(response, ensure_ascii=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
