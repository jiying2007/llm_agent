from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

LTA_SCHEMA = "llm-agent-long-term-asset-qualification/v1"
LEDGER_SCHEMA = "llm-agent-software-m5-pilot-ledger/v1"
EVENT_SCHEMA = "llm-agent-software-field-event/v1"
EVIDENCE_SCHEMA = "llm-agent-longitudinal-operation-evidence/v1"
CHECK_SCHEMA = "llm-agent-longitudinal-operation-check/v1"
ZERO_HASH = "0" * 64


class LongitudinalError(RuntimeError):
    """Tracked evidence exists but violates the LTA-04 contract."""


class LongitudinalBlocked(RuntimeError):
    """The 30-day window or required real summary evidence is not complete."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise LongitudinalError(f"{label} must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise LongitudinalError(f"{label} is invalid") from exc
    return parsed.astimezone(timezone.utc)


def _format_time(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LongitudinalError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise LongitudinalError(f"{label} must be a JSON object")
    return value


def _inside(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _repo_file(root: Path, value: Any, label: str, *, required: bool = True) -> Path:
    if not isinstance(value, str) or not value:
        raise LongitudinalError(f"{label} must be a non-empty repository-relative path")
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise LongitudinalError(f"{label} must stay inside the repository")
    path = (root / relative).resolve()
    if not _inside(path, root):
        raise LongitudinalError(f"{label} resolves outside the repository")
    if required and (not path.is_file() or path.is_symlink()):
        raise LongitudinalError(f"{label} must reference a regular tracked file: {value}")
    return path


def _require_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise LongitudinalError(f"{label} must be a non-empty string")
    return value.strip()


def _lta04(root: Path) -> dict[str, Any]:
    contract = _load_object(root / "manifests/long_term_asset_qualification.json", "long-term asset contract")
    if contract.get("schema") != LTA_SCHEMA:
        raise LongitudinalError("long-term asset contract schema is unsupported")
    requirements = {
        item.get("id"): item
        for item in contract.get("blocking_requirements", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    requirement = requirements.get("LTA-04")
    if not isinstance(requirement, dict):
        raise LongitudinalError("LTA-04 requirement is missing")
    if requirement.get("status") != "blocked_time_evidence":
        raise LongitudinalError("LTA-04 must remain blocked_time_evidence until real qualification evidence is ratcheted")
    if requirement.get("implementation_status") != "certifier-ready":
        raise LongitudinalError("LTA-04 implementation_status must be certifier-ready")
    if requirement.get("minimum_calendar_days") != 30:
        raise LongitudinalError("LTA-04 minimum_calendar_days must remain 30")
    return requirement


def _read_events(root: Path, path: Path, as_of: datetime) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    previous_hash = ZERO_HASH
    previous_recorded: datetime | None = None
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise LongitudinalError(f"cannot read field event log: {path}") from exc
    for sequence, raw in enumerate(lines, start=1):
        if not raw.strip():
            raise LongitudinalError(f"event log contains a blank line at sequence {sequence}")
        try:
            event = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise LongitudinalError(f"event log contains invalid JSON at sequence {sequence}") from exc
        if not isinstance(event, dict) or event.get("schema") != EVENT_SCHEMA:
            raise LongitudinalError(f"event log contains unsupported event schema at sequence {sequence}")
        if event.get("sequence") != sequence:
            raise LongitudinalError("event log sequence is not contiguous")
        if event.get("previous_hash") != previous_hash:
            raise LongitudinalError("event log previous_hash chain is broken")
        stored = event.get("event_hash")
        unsigned = dict(event)
        unsigned.pop("event_hash", None)
        if not isinstance(stored, str) or stored != _digest(unsigned):
            raise LongitudinalError("event log event_hash does not match content")
        occurred = _parse_time(event.get("occurred_at"), "event occurred_at")
        recorded = _parse_time(event.get("recorded_at"), "event recorded_at")
        if occurred > recorded or recorded > as_of:
            raise LongitudinalError("event timestamps are future-dated or inconsistent")
        if previous_recorded is not None and recorded < previous_recorded:
            raise LongitudinalError("event recorded_at timestamps are not monotonic")
        previous_recorded = recorded
        evidence = event.get("evidence")
        digests = event.get("evidence_sha256")
        if not isinstance(evidence, list) or not evidence or not isinstance(digests, dict):
            raise LongitudinalError("event evidence references are incomplete")
        for relative in evidence:
            evidence_path = _repo_file(root, relative, "event evidence")
            if digests.get(relative) != _sha256_file(evidence_path):
                raise LongitudinalError(f"event evidence digest drift: {relative}")
        events.append(event)
        previous_hash = stored
    return events


def _ledger_state(root: Path, requirement: Mapping[str, Any], as_of: datetime) -> tuple[dict[str, Any], Path, list[dict[str, Any]], datetime]:
    ledger = _load_object(root / "manifests/software_m5_pilot_ledger.json", "Software M5 pilot ledger")
    if ledger.get("schema") != LEDGER_SCHEMA:
        raise LongitudinalError("Software M5 pilot ledger schema is unsupported")
    pilot_id = _require_text(requirement.get("pilot_id"), "LTA-04 pilot_id")
    repository_id = _require_text(requirement.get("repository_id"), "LTA-04 repository_id")
    pilots = {item.get("id"): item for item in ledger.get("pilots", []) if isinstance(item, dict)}
    repositories = {item.get("id"): item for item in ledger.get("repositories", []) if isinstance(item, dict)}
    operators = {item.get("id"): item for item in ledger.get("operators", []) if isinstance(item, dict)}
    pilot = pilots.get(pilot_id)
    repository = repositories.get(repository_id)
    if not isinstance(pilot, dict) or not isinstance(repository, dict):
        raise LongitudinalError("LTA-04 pilot/repository is not present in the Software M5 ledger")
    if pilot.get("environment_class") != "independent" or pilot.get("status") not in {"active", "completed"}:
        raise LongitudinalError("LTA-04 requires an active/completed independent pilot")
    if repository.get("classification") != "independent" or repository.get("real_software") is not True:
        raise LongitudinalError("LTA-04 repository must remain independent real software")
    if repository_id not in pilot.get("repositories", []):
        raise LongitudinalError("LTA-04 repository is not registered to the configured pilot")
    if not any(operators.get(value, {}).get("operator_type") == "human" for value in pilot.get("operators", [])):
        raise LongitudinalError("LTA-04 pilot must retain at least one human operator")
    started = _parse_time(pilot.get("started_at"), "pilot started_at")
    event_log = _repo_file(root, ledger.get("event_log"), "field event log")
    events = _read_events(root, event_log, as_of)
    starts = [
        event
        for event in events
        if event.get("pilot_id") == pilot_id
        and event.get("repository_id") == repository_id
        and event.get("event_type") == "pilot_started"
        and event.get("evidence_layer") == "field"
    ]
    if len(starts) != 1:
        raise LongitudinalError("LTA-04 requires exactly one canonical pilot_started field event")
    if _parse_time(starts[0].get("occurred_at"), "pilot_started occurred_at") != started:
        raise LongitudinalError("pilot_started event does not match ledger started_at")
    return ledger, event_log, events, started


def _validate_category(
    name: str,
    value: Any,
    events_by_id: Mapping[str, Mapping[str, Any]],
    allowed_types: set[str],
    started: datetime,
    observed_through: datetime,
) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise LongitudinalError(f"outcomes.{name} must be an object")
    count = value.get("count")
    event_ids = value.get("event_ids")
    if isinstance(count, bool) or not isinstance(count, int) or count < 0:
        raise LongitudinalError(f"outcomes.{name}.count must be a non-negative integer")
    if not isinstance(event_ids, list) or len(set(event_ids)) != len(event_ids) or count != len(event_ids):
        raise LongitudinalError(f"outcomes.{name} count/event_ids are inconsistent")
    for event_id in event_ids:
        if not isinstance(event_id, str) or event_id not in events_by_id:
            raise LongitudinalError(f"outcomes.{name} references an unknown event_id")
        event = events_by_id[event_id]
        if event.get("event_type") not in allowed_types:
            raise LongitudinalError(f"outcomes.{name} references the wrong event type")
        occurred = _parse_time(event.get("occurred_at"), f"{event_id} occurred_at")
        if occurred < started or occurred > observed_through:
            raise LongitudinalError(f"outcomes.{name} references an event outside the observation window")
    return {"count": count, "event_ids": event_ids}


def _validate_summary(
    root: Path,
    summary_path: Path,
    requirement: Mapping[str, Any],
    event_log: Path,
    events: list[dict[str, Any]],
    started: datetime,
    eligible_after: datetime,
    as_of: datetime,
) -> dict[str, Any]:
    summary = _load_object(summary_path, "LTA-04 longitudinal summary")
    if summary.get("schema") != EVIDENCE_SCHEMA or summary.get("qualification") != "LTA-04" or summary.get("status") != "complete":
        raise LongitudinalError("LTA-04 longitudinal summary schema/qualification/status is invalid")
    if summary.get("pilot_id") != requirement.get("pilot_id") or summary.get("repository_id") != requirement.get("repository_id"):
        raise LongitudinalError("LTA-04 longitudinal summary pilot/repository identity drifted")
    observed = summary.get("observation")
    if not isinstance(observed, dict):
        raise LongitudinalError("LTA-04 observation window is missing")
    if _parse_time(observed.get("started_at"), "observation.started_at") != started:
        raise LongitudinalError("LTA-04 observation start does not match the pilot")
    observed_through = _parse_time(observed.get("observed_through"), "observation.observed_through")
    if observed_through < eligible_after:
        raise LongitudinalError("LTA-04 summary does not cover the full 30-day observation window")
    if observed_through > as_of:
        raise LongitudinalError("LTA-04 summary is future-dated")

    source = summary.get("source")
    if not isinstance(source, dict):
        raise LongitudinalError("LTA-04 summary source binding is missing")
    relative_event_log = event_log.relative_to(root).as_posix()
    if source.get("event_log") != relative_event_log:
        raise LongitudinalError("LTA-04 summary event_log path drifted")
    if source.get("event_log_sha256") != _sha256_file(event_log):
        raise LongitudinalError("LTA-04 summary event_log digest does not match current content")
    chain_head = events[-1]["event_hash"] if events else ZERO_HASH
    if source.get("event_chain_head") != chain_head or source.get("event_count") != len(events):
        raise LongitudinalError("LTA-04 summary is not bound to the current event-chain head")

    relevant = [
        event
        for event in events
        if event.get("pilot_id") == requirement.get("pilot_id")
        and event.get("repository_id") == requirement.get("repository_id")
        and started <= _parse_time(event.get("occurred_at"), "event occurred_at") <= observed_through
    ]
    events_by_id = {str(event.get("event_id")): event for event in relevant if isinstance(event.get("event_id"), str)}
    outcomes = summary.get("outcomes")
    if not isinstance(outcomes, dict):
        raise LongitudinalError("LTA-04 outcomes are missing")
    incidents = _validate_category("incidents", outcomes.get("incidents"), events_by_id, {"fault_observed"}, started, observed_through)
    regressions = _validate_category("regressions", outcomes.get("regressions"), events_by_id, {"regression_observed"}, started, observed_through)
    recoveries = _validate_category("recoveries", outcomes.get("recoveries"), events_by_id, {"recovery_completed"}, started, observed_through)

    risks = outcomes.get("unresolved_risks")
    if not isinstance(risks, list):
        raise LongitudinalError("outcomes.unresolved_risks must be an array, including an explicit empty array when none remain")
    seen: set[str] = set()
    blocking: list[str] = []
    for risk in risks:
        if not isinstance(risk, dict):
            raise LongitudinalError("unresolved risk entries must be objects")
        risk_id = _require_text(risk.get("id"), "unresolved risk id")
        if risk_id in seen:
            raise LongitudinalError("unresolved risk ids must be unique")
        seen.add(risk_id)
        if risk.get("severity") not in {"low", "medium", "high", "critical"}:
            raise LongitudinalError("unresolved risk severity is invalid")
        if risk.get("disposition") not in {"accepted", "mitigated", "blocking"}:
            raise LongitudinalError("unresolved risk disposition is invalid")
        _require_text(risk.get("summary"), "unresolved risk summary")
        if risk.get("disposition") == "blocking":
            blocking.append(risk_id)

    review = summary.get("review")
    if not isinstance(review, dict):
        raise LongitudinalError("LTA-04 review is missing")
    reviewer = _require_text(review.get("operator_id"), "review.operator_id")
    ledger = _load_object(root / "manifests/software_m5_pilot_ledger.json", "Software M5 pilot ledger")
    operators = {item.get("id"): item for item in ledger.get("operators", []) if isinstance(item, dict)}
    pilot = next((item for item in ledger.get("pilots", []) if isinstance(item, dict) and item.get("id") == requirement.get("pilot_id")), None)
    if reviewer not in operators or operators[reviewer].get("operator_type") != "human" or not isinstance(pilot, dict) or reviewer not in pilot.get("operators", []):
        raise LongitudinalError("LTA-04 review must be performed by a human operator registered to the pilot")
    if review.get("standard") != "solo-maintainer-long-term-asset-v1":
        raise LongitudinalError("LTA-04 review standard is invalid")
    decision = review.get("decision")
    if decision not in {"approve", "hold"}:
        raise LongitudinalError("LTA-04 review decision must be approve or hold")
    reviewed_at = _parse_time(review.get("reviewed_at"), "review.reviewed_at")
    if reviewed_at < eligible_after or reviewed_at > as_of:
        raise LongitudinalError("LTA-04 review must occur after the 30-day window and not in the future")

    stored = summary.get("summary_sha256")
    unsigned = dict(summary)
    unsigned.pop("summary_sha256", None)
    if not isinstance(stored, str) or stored != _digest(unsigned):
        raise LongitudinalError("LTA-04 summary_sha256 does not match content")
    if blocking or decision == "hold":
        reason = "unresolved-blocking-risks" if blocking else "review-hold"
        raise LongitudinalBlocked(reason)
    return {
        "summary_sha256": stored,
        "observed_through": _format_time(observed_through),
        "incidents": incidents["count"],
        "regressions": regressions["count"],
        "recoveries": recoveries["count"],
        "unresolved_risks": len(risks),
        "event_chain_head": chain_head,
    }


def check(root: Path, *, evidence_path: Path | None = None, as_of: datetime | None = None) -> dict[str, Any]:
    root = root.resolve()
    now = (as_of or datetime.now(timezone.utc)).astimezone(timezone.utc).replace(microsecond=0)
    requirement = _lta04(root)
    _, event_log, events, started = _ledger_state(root, requirement, now)
    minimum_days = int(requirement["minimum_calendar_days"])
    eligible_after = started + timedelta(days=minimum_days)
    base = {
        "schema": CHECK_SCHEMA,
        "qualification": "LTA-04",
        "pilot_id": requirement["pilot_id"],
        "repository_id": requirement["repository_id"],
        "minimum_calendar_days": minimum_days,
        "started_at": _format_time(started),
        "eligible_after": _format_time(eligible_after),
        "as_of": _format_time(now),
        "observed_days": max(0, int((now - started).total_seconds() // 86400)),
        "event_count": len(events),
        "event_chain_head": events[-1]["event_hash"] if events else ZERO_HASH,
    }
    if now < eligible_after:
        raise LongitudinalBlocked(json.dumps({**base, "reason": "observation-window-not-complete"}, ensure_ascii=False, sort_keys=True))

    relative = evidence_path or Path(str(requirement.get("default_evidence_path")))
    summary_path = relative if relative.is_absolute() else (root / relative)
    summary_path = summary_path.resolve()
    if not _inside(summary_path, root):
        raise LongitudinalError("LTA-04 evidence path must stay inside the repository")
    if not summary_path.is_file():
        raise LongitudinalBlocked(json.dumps({**base, "reason": "summary-evidence-missing", "expected_evidence": summary_path.relative_to(root).as_posix()}, ensure_ascii=False, sort_keys=True))
    detail = _validate_summary(root, summary_path, requirement, event_log, events, started, eligible_after, now)
    return {**base, "status": "pass", "evidence": summary_path.relative_to(root).as_posix(), **detail}


def _blocked_payload(message: str) -> dict[str, Any]:
    try:
        detail = json.loads(message)
    except json.JSONDecodeError:
        detail = {"reason": message}
    if not isinstance(detail, dict):
        detail = {"reason": str(detail)}
    return {"schema": CHECK_SCHEMA, "status": "blocked", **detail}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fail-closed LTA-04 30-day longitudinal-operation certifier")
    parser.add_argument("--root", default=".")
    parser.add_argument("--evidence")
    parser.add_argument("--as-of", help="ISO-8601 UTC timestamp ending in Z; intended for deterministic verification/tests")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        as_of = _parse_time(args.as_of, "--as-of") if args.as_of else None
        result = check(Path(args.root), evidence_path=Path(args.evidence) if args.evidence else None, as_of=as_of)
    except LongitudinalBlocked as exc:
        result = _blocked_payload(str(exc))
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[BLOCKED] {result.get('reason', 'LTA-04 is not yet qualified')}")
        return 2
    except (LongitudinalError, OSError, ValueError) as exc:
        result = {"schema": CHECK_SCHEMA, "status": "fail", "error": str(exc)}
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print("[PASS] LTA-04 longitudinal operation evidence is qualified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
