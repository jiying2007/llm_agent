"""Bounded read-only Goal handoff and execution cost observation.

Consumes the existing ADK current-state and optional exact GitHub Actions jobs
and runtime usage. Never grants Goal completion, bills or production qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
from datetime import datetime
from pathlib import Path
from typing import Any, Sequence

SCHEMA = "llm-agent-goal-efficiency-observation/v1"
MAX_BYTES = 256 * 1024
SHA = re.compile(r"[0-9a-f]{40}\Z")


class ObservationError(ValueError):
    pass


def _pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in items:
        if key in result:
            raise ObservationError("duplicate JSON field")
        result[key] = value
    return result


def _read(path: Path) -> tuple[dict[str, Any], str]:
    current = path.absolute()
    while True:
        if current.is_symlink():
            raise ObservationError("symlink input")
        if current.parent == current:
            break
        current = current.parent
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                raise ObservationError("input not regular")
            raw = os.read(fd, MAX_BYTES + 1)
        finally:
            os.close(fd)
    except OSError as exc:
        raise ObservationError("unreadable input") from exc
    if not raw or len(raw) > MAX_BYTES:
        raise ObservationError("input empty or oversized")
    try:
        def reject_constant(_value: str) -> Any:
            raise ObservationError("invalid nonfinite number")
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=reject_constant)
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise ObservationError("invalid input JSON") from exc
    if not isinstance(value, dict):
        raise ObservationError("input JSON object required")
    return value, hashlib.sha256(raw).hexdigest()


def _int(value: Any, name: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise ObservationError(name + " invalid")
    return value


def _time(value: Any, name: str) -> datetime:
    if not isinstance(value, str):
        raise ObservationError(name + " missing")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ObservationError(name + " invalid") from exc
    if result.utcoffset() is None:
        raise ObservationError(name + " lacks timezone")
    return result


def _usage(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"status": "UNKNOWN", "reason": "no-runtime-usage-snapshot"}
    data, digest = _read(path)
    if data.get("schema_version") != "runtime_control.state/v1" or not isinstance(data.get("usage"), dict):
        raise ObservationError("runtime-state schema invalid")
    usage = data["usage"]
    if usage.get("observed_at") is None:
        return {"status": "UNKNOWN", "reason": "no-observed-usage", "input_sha256": digest}
    _time(usage["observed_at"], "usage time")
    keys = ("input_tokens", "output_tokens", "cached_input_tokens", "reasoning_tokens", "total_tokens")
    counters = {key: _int(usage.get(key), key) for key in keys}
    if counters["cached_input_tokens"] > counters["input_tokens"]:
        raise ObservationError("cached input exceeds input")
    if counters["total_tokens"] < counters["input_tokens"] + counters["output_tokens"]:
        raise ObservationError("total usage contradicts input/output")
    return {"status": "REPORTED_UNVERIFIED", "input_sha256": digest,
            "tokens": counters, "billing_verified": False}


def _jobs(path: Path | None, run_id: int | None, attempt: int | None,
          head_sha: str | None) -> dict[str, Any]:
    if path is None:
        if any(x is not None for x in (run_id, attempt, head_sha)):
            raise ObservationError("job identity without input")
        return {"status": "UNKNOWN", "reason": "no-GitHub-jobs"}
    if run_id is None or attempt is None or head_sha is None or not SHA.fullmatch(head_sha):
        raise ObservationError("run ID, attempt, and exact head SHA required")
    _int(run_id, "run ID", 1)
    _int(attempt, "attempt", 1)
    data, digest = _read(path)
    jobs = data.get("jobs")
    if (type(data.get("total_count")) is not int or not isinstance(jobs, list)
            or not 0 < len(jobs) == data["total_count"] <= 100):
        raise ObservationError("incomplete GitHub jobs page")
    seen: set[int] = set()
    secs = 0.0
    first: datetime | None = None
    last: datetime | None = None
    finished = failed = 0
    for job in jobs:
        if not isinstance(job, dict):
            raise ObservationError("malformed job")
        id_ = _int(job.get("id"), "job ID", 1)
        if id_ in seen:
            raise ObservationError("duplicate job ID")
        seen.add(id_)
        if (job.get("run_id") != run_id or job.get("run_attempt") != attempt
                or job.get("head_sha") != head_sha):
            raise ObservationError("job source/attempt drift")
        status = job.get("status")
        if status not in ("completed", "queued", "in_progress", "waiting", "pending"):
            raise ObservationError("unsupported job status")
        if status != "completed":
            if job.get("conclusion") is not None:
                raise ObservationError("unfinished job carries conclusion")
            continue
        if job.get("conclusion") not in ("success", "failure", "cancelled", "timed_out", "skipped",
                                         "neutral", "action_required", "stale"):
            raise ObservationError("completed job conclusion invalid")
        start = _time(job.get("started_at"), "job start")
        end = _time(job.get("completed_at"), "job end")
        duration = (end - start).total_seconds()
        if not 0 <= duration <= 86400:
            raise ObservationError("invalid job duration")
        secs += duration
        first = start if first is None or start < first else first
        last = end if last is None or end > last else last
        finished += 1
        if job["conclusion"] in ("failure", "cancelled", "timed_out", "action_required", "stale"):
            failed += 1
    return {"status": "COMPLETE" if finished == len(jobs) else "PARTIAL",
            "run_id": run_id, "run_attempt": attempt, "head_sha": head_sha,
            "input_sha256": digest, "jobs_total": len(jobs), "jobs_completed": finished,
            "jobs_failed": failed, "job_seconds_sum": round(secs, 3),
            "observed_wall_seconds": round((last - first).total_seconds(), 3) if first and last else None,
            "is_billing_measurement": False}


def observe(current_state: Path, *, runtime_state: Path | None = None,
            jobs: Path | None = None, run_id: int | None = None,
            attempt: int | None = None, head_sha: str | None = None) -> dict[str, Any]:
    from agent_dev_kit.planning_state import check_current_state

    state, digest = _read(current_state)
    validation = check_current_state(current_state)
    if validation["status"] != "pass" or validation["state_sha256"] != digest:
        raise ObservationError("invalid or changed ADK current-state")
    if len(state["evidence_refs"]) > 64 or len(state["history_refs"]) > 64 or len(state["blockers"]) > 32:
        raise ObservationError("unbounded current-state")
    return {
        "schema_version": SCHEMA, "status": "OBSERVED_NOT_CERTIFIED",
        "current_state": {"schema_version": "adk.current-state/v1",
                          "input_sha256": digest, "goal_ref": state["goal_ref"],
                          "milestone": state["milestone"], "blockers": state["blockers"],
                          "next_actions": state["next_actions"],
                          "evidence_count": len(state["evidence_refs"]),
                          "history_count": len(state["history_refs"])},
        "runtime_tokens": _usage(runtime_state),
        "github_job_cost": _jobs(jobs, run_id, attempt, head_sha),
        "goal_completion_verified": False, "production_qualified": False,
        "limitations": ["Input provenance must be independently checked",
                        "No live Goal or billing access; no completion inferred from CI"],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current-state", required=True, type=Path)
    parser.add_argument("--runtime-state", type=Path)
    parser.add_argument("--jobs", type=Path)
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--attempt", type=int)
    parser.add_argument("--head-sha")
    args = parser.parse_args(argv)
    try:
        result = observe(args.current_state, runtime_state=args.runtime_state,
                         jobs=args.jobs, run_id=args.run_id,
                         attempt=args.attempt, head_sha=args.head_sha)
    except (ObservationError, ValueError, OSError, KeyError) as exc:
        print(json.dumps({"schema_version": SCHEMA, "status": "REJECTED",
                          "reason": str(exc), "goal_completion_verified": False,
                          "production_qualified": False}))
        return 1
    print(json.dumps(result, sort_keys=True, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
