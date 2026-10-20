from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from collections.abc import Iterator, Mapping
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from .adk_interface import validate_delegated_review
from .evidence_paths import resolve_regular_evidence_path

LTA_SCHEMA = "llm-agent-long-term-asset-qualification/v2"
LEDGER_SCHEMA = "llm-agent-software-m5-pilot-ledger/v1"
EVENT_SCHEMA = "llm-agent-software-field-event/v1"
EVIDENCE_SCHEMA = "llm-agent-longitudinal-operation-evidence/v2"
CHECK_SCHEMA = "llm-agent-longitudinal-operation-check/v1"
ZERO_HASH = "0" * 64
MAX_JSON_DOCUMENT_BYTES = 1024 * 1024
MAX_EVENT_LOG_BYTES = 32 * 1024 * 1024
MAX_EVENT_LINE_BYTES = 128 * 1024
MAX_EVENT_COUNT = 50000
MAX_EVENT_EVIDENCE_REFS = 32
MAX_FIELD_EVIDENCE_BYTES = 16 * 1024 * 1024
MAX_UNIQUE_FIELD_EVIDENCE_FILES = 8192
MAX_TOTAL_FIELD_EVIDENCE_BYTES = 512 * 1024 * 1024


class LongitudinalError(RuntimeError):
    """Tracked evidence exists but violates the LTA-04 contract."""


class LongitudinalBlocked(RuntimeError):
    """The 30-day window or required real summary evidence is not complete."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _unique_json_fields(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Reject duplicate fields at *all* nesting levels before hashing evidence.

    Ordinary json.loads silently selects the last occurrence, allowing human
    review tools and the machine digest to interpret the same bytes differently.
    """
    document: dict[str, Any] = {}
    for key, value in pairs:
        if key in document:
            raise LongitudinalError(f"duplicate JSON object key: {key}")
        document[key] = value
    return document


def _reject_nonfinite_json(value: str) -> Any:
    raise LongitudinalError(f"non-finite JSON number is forbidden: {value}")


def _finite_json_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed):
        raise LongitudinalError("non-finite JSON number is forbidden")
    return parsed


def _strict_json_loads(raw: str) -> Any:
    return json.loads(
        raw, object_pairs_hook=_unique_json_fields,
        parse_constant=_reject_nonfinite_json, parse_float=_finite_json_float,
    )


def _bounded_event_lines(path: Path) -> Iterator[tuple[int, str]]:
    """Stream an append-only event log with hard byte/line/count budgets."""
    try:
        if path.stat().st_size > MAX_EVENT_LOG_BYTES:
            raise LongitudinalError("event log exceeds byte budget")
        with path.open("r", encoding="utf-8") as stream:
            for sequence, raw in enumerate(stream, start=1):
                if sequence > MAX_EVENT_COUNT:
                    raise LongitudinalError("event log exceeds event-count budget")
                if len(raw.encode("utf-8")) > MAX_EVENT_LINE_BYTES:
                    raise LongitudinalError("event log line exceeds byte budget")
                yield sequence, raw
    except (OSError, UnicodeError) as exc:
        raise LongitudinalError(f"cannot read field event log: {path}") from exc


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
    return parsed.astimezone(UTC)


def _format_time(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        if path.is_symlink() or not path.is_file():
            raise LongitudinalError(f"{label} must be a regular file")
        if path.stat().st_size > MAX_JSON_DOCUMENT_BYTES:
            raise LongitudinalError(f"{label} exceeds JSON byte budget")
        value = _strict_json_loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as exc:
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
    try:
        path = resolve_regular_evidence_path(root, relative, label=label)
    except ValueError as exc:
        raise LongitudinalError(str(exc)) from exc
    if required and (not path.is_file() or path.is_symlink()):
        raise LongitudinalError(f"{label} must reference a regular tracked file: {value}")
    return path


def _verify_committed_evidence(root: Path, files: set[Path]) -> None:
    """Bind every terminal file to the raw Git HEAD blob, index, and worktree.

    Git status is advisory: assume-unchanged/skip-worktree can hide modified
    worktree bytes from porcelain status. Compare the actual unfiltered blob
    hash to HEAD, and compare the index blob/mode separately to reject staging.
    Neither Git consistency nor a digest is real-world field provenance.
    """
    relative_paths = sorted(path.relative_to(root).as_posix() for path in files)
    if not relative_paths:
        raise LongitudinalError("terminal evidence file inventory is empty")
    for offset in range(0, len(relative_paths), 128):
        chunk = relative_paths[offset:offset + 128]
        # Explicit literal pathspecs prevent [], *, and ? from widening scope.
        pathspecs = [":(literal)" + path for path in chunk]
        commands = (
            ("git", "-C", str(root), "ls-tree", "-r", "-z", "--full-tree", "HEAD", "--", *pathspecs),
            ("git", "-C", str(root), "ls-files", "--stage", "-z", "--", *pathspecs),
            ("git", "-C", str(root), "hash-object", "--no-filters", "--", *chunk),
        )
        try:
            responses = [
                subprocess.run(command, check=False, capture_output=True, timeout=30)
                for command in commands
            ]
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise LongitudinalError("cannot inspect terminal evidence Git identity") from exc
        if any(response.returncode != 0 for response in responses):
            raise LongitudinalError("cannot inspect terminal evidence Git identity")

        head: dict[str, tuple[bytes, bytes]] = {}
        index: dict[str, tuple[bytes, bytes]] = {}
        try:
            for entry in responses[0].stdout.split(b"\0"):
                if not entry:
                    continue
                metadata, filename = entry.split(b"\t", 1)
                mode, kind, blob = metadata.split(b" ", 2)
                if kind != b"blob" or mode not in {b"100644", b"100755"}:
                    raise LongitudinalError("terminal HEAD evidence is not a regular file")
                name = filename.decode("utf-8")
                if name in head:
                    raise LongitudinalError("terminal HEAD evidence has duplicate paths")
                head[name] = (mode, blob)
            for entry in responses[1].stdout.split(b"\0"):
                if not entry:
                    continue
                metadata, filename = entry.split(b"\t", 1)
                mode, blob, stage = metadata.split(b" ", 2)
                name = filename.decode("utf-8")
                if stage != b"0" or name in index:
                    raise LongitudinalBlocked("terminal-evidence-worktree-drift")
                index[name] = (mode, blob)
        except (ValueError, UnicodeError) as exc:
            raise LongitudinalError("cannot decode terminal evidence Git identity") from exc
        if set(head) != set(chunk) or set(index) != set(chunk):
            raise LongitudinalBlocked("terminal-evidence-not-committed")
        if head != index:
            raise LongitudinalBlocked("terminal-evidence-worktree-drift")

        actual_blobs = responses[2].stdout.splitlines()
        if len(actual_blobs) != len(chunk):
            raise LongitudinalError("terminal evidence raw blob inventory is incomplete")
        for name, raw_blob in zip(chunk, actual_blobs, strict=True):
            if raw_blob != head[name][1]:
                raise LongitudinalBlocked("terminal-evidence-worktree-drift")


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
        for item in contract.get("qualification_requirements", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    requirement = requirements.get("LTA-04")
    if not isinstance(requirement, dict):
        raise LongitudinalError("LTA-04 requirement is missing")
    if requirement.get("status") != "observation_window_in_progress":
        raise LongitudinalError("LTA-04 must remain observation_window_in_progress until real qualification evidence is ratcheted")
    if requirement.get("implementation_status") != "certifier-ready":
        raise LongitudinalError("LTA-04 implementation_status must be certifier-ready")
    if requirement.get("minimum_calendar_days") != 30:
        raise LongitudinalError("LTA-04 minimum_calendar_days must remain 30")
    return requirement


def _read_events(root: Path, path: Path, as_of: datetime) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    previous_hash = ZERO_HASH
    previous_recorded: datetime | None = None
    seen_event_ids: set[str] = set()
    # Path-normalized references across different events must not cause
    # repeated full-file hashing or unbounded cumulative repository I/O.
    validated_evidence: dict[Path, str] = {}
    total_evidence_bytes = 0
    for sequence, raw in _bounded_event_lines(path):
        if not raw.strip():
            raise LongitudinalError(f"event log contains a blank line at sequence {sequence}")
        try:
            event = _strict_json_loads(raw)
        except json.JSONDecodeError as exc:
            raise LongitudinalError(f"event log contains invalid JSON at sequence {sequence}") from exc
        if not isinstance(event, dict) or event.get("schema") != EVENT_SCHEMA:
            raise LongitudinalError(f"event log contains unsupported event schema at sequence {sequence}")
        if event.get("sequence") != sequence:
            raise LongitudinalError("event log sequence is not contiguous")
        event_id = _require_text(event.get("event_id"), "event_id")
        if event_id in seen_event_ids:
            raise LongitudinalError(f"duplicate event_id in event log: {event_id}")
        seen_event_ids.add(event_id)
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
        if len(evidence) > MAX_EVENT_EVIDENCE_REFS:
            raise LongitudinalError("event evidence reference count exceeds budget")
        if not all(isinstance(relative, str) and relative for relative in evidence):
            raise LongitudinalError("event evidence references must be nonempty paths")
        if len(set(evidence)) != len(evidence):
            raise LongitudinalError("event evidence references must be unique")
        if set(digests) != set(evidence):
            raise LongitudinalError("event evidence digest keys do not match references")
        for relative in evidence:
            evidence_path = _repo_file(root, relative, "event evidence")
            if relative != evidence_path.relative_to(root).as_posix():
                raise LongitudinalError("event evidence path must be canonical repository-relative")
            if evidence_path not in validated_evidence:
                if len(validated_evidence) >= MAX_UNIQUE_FIELD_EVIDENCE_FILES:
                    raise LongitudinalError("event evidence unique-file budget exceeded")
                size = evidence_path.stat().st_size
                if size > MAX_FIELD_EVIDENCE_BYTES:
                    raise LongitudinalError("event evidence exceeds byte budget")
                if total_evidence_bytes + size > MAX_TOTAL_FIELD_EVIDENCE_BYTES:
                    raise LongitudinalError("event evidence cumulative byte budget exceeded")
                verified_sha = _sha256_file(evidence_path)
                validated_evidence[evidence_path] = verified_sha
                total_evidence_bytes += size
            if digests.get(relative) != validated_evidence[evidence_path]:
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
    start_operator = starts[0].get("operator_id")
    if start_operator not in pilot.get("operators", []) or operators.get(start_operator, {}).get("operator_type") != "human":
        raise LongitudinalError("pilot_started must be attributed to a registered human operator")
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
    if not isinstance(event_ids, list) or any(not isinstance(item, str) for item in event_ids):
        raise LongitudinalError(f"outcomes.{name}.event_ids must contain strings")
    if len(set(event_ids)) != len(event_ids) or count != len(event_ids):
        raise LongitudinalError(f"outcomes.{name} count/event_ids are inconsistent")
    expected_ids = {
        event_id
        for event_id, event in events_by_id.items()
        if event.get("event_type") in allowed_types
        and started <= _parse_time(event.get("occurred_at"), f"{event_id} occurred_at") <= observed_through
    }
    if set(event_ids) != expected_ids:
        raise LongitudinalError(f"outcomes.{name} must exactly cover all matching field events")
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
    # Only real field-layer events may enter a terminal longitudinal summary.
    # Checking types and digests alone permits a rehashed synthetic/rehearsal
    # event to masquerade as a real incident, regression, or recovery.
    non_field_ids = [
        str(event["event_id"]) for event in relevant
        if event.get("evidence_layer") != "field"
    ]
    if non_field_ids:
        raise LongitudinalError(
            "LTA-04 terminal outcomes require field-only evidence; non-field event(s): "
            + ", ".join(non_field_ids)
        )
    # The calendar alone does not prove that the independent pilot continued.
    # Requiring a digest-bound *real field* observation at the end prevents a
    # start-only ledger plus a backfilled 30-day summary from being certified.
    # Both the event evidence and its SHA-256 are verified by _read_events.
    terminal_observation_from = max(eligible_after, observed_through - timedelta(hours=24))
    terminal_observations = [
        event for event in relevant
        if event.get("event_type") == "pilot_observed"
        and event.get("evidence_layer") == "field"
        and terminal_observation_from <= _parse_time(event.get("occurred_at"), "pilot_observed occurred_at") <= observed_through
        and _parse_time(event.get("recorded_at"), "pilot_observed recorded_at") >= eligible_after
    ]
    if not terminal_observations:
        raise LongitudinalBlocked("end-window-field-evidence-missing")
    ledger = _load_object(root / "manifests/software_m5_pilot_ledger.json", "Software M5 pilot ledger")
    operators = {item.get("id"): item for item in ledger.get("operators", []) if isinstance(item, dict)}
    pilot = next((item for item in ledger.get("pilots", []) if isinstance(item, dict) and item.get("id") == requirement.get("pilot_id")), None)
    if not isinstance(pilot, dict):
        raise LongitudinalError("LTA-04 registered pilot is missing")
    # Every incident/regression/recovery/event included in the 30-day field
    # summary needs the same declared human operator authority as pilot start
    # and the terminal observation. Rehashing the chain does not grant an
    # unregistered actor permission to contribute terminal field outcomes.
    registered_operators = pilot.get("operators", [])
    if not isinstance(registered_operators, list):
        raise LongitudinalError("LTA-04 pilot registered operators must be an array")
    for event in relevant:
        actor = event.get("operator_id")
        if (
            not isinstance(actor, str)
            or actor not in registered_operators
            or operators.get(actor, {}).get("operator_type") != "human"
        ):
            raise LongitudinalError("LTA-04 field event requires registered human operator")
    # _read_events enforces global unique IDs before this scoped index is made.
    events_by_id = {str(event["event_id"]): event for event in relevant}
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
    mode = review.get("mode")
    if mode == "registered-human":
        if set(review) != {"mode", "operator_id", "standard", "decision", "reviewed_at"}:
            raise LongitudinalError("LTA-04 registered human review fields are invalid")
        reviewer = _require_text(review.get("operator_id"), "review.operator_id")
        if reviewer not in operators or operators[reviewer].get("operator_type") != "human" or reviewer not in pilot.get("operators", []):
            raise LongitudinalError("LTA-04 review must be performed by a human operator registered to the pilot")
        if review.get("standard") != "solo-maintainer-long-term-asset-v1":
            raise LongitudinalError("LTA-04 review standard is invalid")
    elif mode == "owner-delegated-ai":
        if set(review) != {"mode", "reviewer_id", "standard", "decision", "reviewed_at", "evidence_path"}:
            raise LongitudinalError("LTA-04 delegated review fields are invalid")
        reviewer = _require_text(review.get("reviewer_id"), "review.reviewer_id")
        if review.get("standard") != "owner-delegated-ai-review-v1":
            raise LongitudinalError("LTA-04 delegated review standard is invalid")
    else:
        raise LongitudinalError("LTA-04 review mode is invalid")
    decision = review.get("decision")
    if decision not in {"approve", "hold"}:
        raise LongitudinalError("LTA-04 review decision must be approve or hold")
    reviewed_at = _parse_time(review.get("reviewed_at"), "review.reviewed_at")
    if reviewed_at < max(eligible_after, observed_through) or reviewed_at > as_of:
        raise LongitudinalError("LTA-04 review must occur after the observed window and not in the future")
    # The summary binds the entire append-only ledger (digest/count/head), not
    # merely event occurrence times. A late recorded/recovered entry must be
    # reviewed after its material is on record, never retroactively approved.
    last_recorded = max(_parse_time(event.get("recorded_at"), "event recorded_at") for event in events)
    if reviewed_at < last_recorded:
        raise LongitudinalError("LTA-04 owner review predates latest recorded field event")

    review_evidence_files: list[str] = []
    review_record_sha256 = None
    if mode == "owner-delegated-ai":
        # Delegation replaces the summary reviewer only. Registered human field
        # actors, genuine event material and the complete observation window are
        # still checked above. The record binds this summary (including outcomes
        # and its event-log digest); the summary references its path, not its
        # hash, so the two artifacts do not contain a circular digest dependency.
        record_path = _repo_file(root, review["evidence_path"], "LTA-04 delegated review")
        try:
            delegated = validate_delegated_review(root, record_path, policy_root=root / "agent-dev-kit",
                                                  expected_subject="lta-04/" + str(requirement["pilot_id"]),
                                                  expected_scope="longitudinal-review", now=as_of)
        except ValueError as exc:
            raise LongitudinalError("LTA-04 delegated review evidence is invalid") from exc
        if delegated["reviewer"]["id"] != reviewer or delegated["reviewed_at"] != review["reviewed_at"]:
            raise LongitudinalError("LTA-04 review identity or time differs from delegated record")
        if _parse_time(delegated["evidence_completed_at"], "delegated evidence completion") < max(observed_through, last_recorded):
            raise LongitudinalError("LTA-04 delegated review predates completed field evidence")
        bound = {
            ((root if ref["base"] == "repository" else record_path.parent) / ref["path"]).resolve(): ref["sha256"]
            for ref in delegated["sources"] + delegated["evidence"]
        }
        for source_path in (summary_path, root / "manifests/software_m5_pilot_ledger.json",
                            root / "manifests/long_term_asset_qualification.json"):
            if bound.get(source_path.resolve()) != _sha256_file(source_path):
                raise LongitudinalError("LTA-04 delegated review omits its summary or source contracts")
        review_record_sha256 = delegated["record_sha256"]
        review_evidence_files = sorted(path.relative_to(root).as_posix() for path in {record_path, *bound})

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
        "review_mode": mode,
        "reviewer_id": reviewer,
        "review_record_sha256": review_record_sha256,
        "review_evidence_files": review_evidence_files,
    }


def check(root: Path, *, evidence_path: Path | None = None, as_of: datetime | None = None) -> dict[str, Any]:
    root = root.resolve()
    now = (as_of or datetime.now(UTC)).astimezone(UTC).replace(microsecond=0)
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

    canonical_relative = Path(str(requirement.get("default_evidence_path")))
    relative = evidence_path or canonical_relative
    try:
        summary_path = resolve_regular_evidence_path(root, relative, label="LTA-04 summary evidence")
        canonical_path = resolve_regular_evidence_path(root, canonical_relative, label="canonical LTA-04 summary")
    except ValueError as exc:
        raise LongitudinalError(str(exc)) from exc
    if not summary_path.is_file():
        raise LongitudinalBlocked(json.dumps({**base, "reason": "summary-evidence-missing", "expected_evidence": summary_path.relative_to(root).as_posix()}, ensure_ascii=False, sort_keys=True))
    if as_of is None and summary_path != canonical_path:
        raise LongitudinalBlocked("noncanonical-summary-review-only")
    detail = _validate_summary(root, summary_path, requirement, event_log, events, started, eligible_after, now)
    if as_of is None:
        if detail["review_mode"] == "owner-delegated-ai":
            from .adk_interface import validate as validate_adk_interface

            if validate_adk_interface(root, require_worktree=True).get("status") != "pass":
                raise LongitudinalError("LTA-04 delegated review requires the exact pinned ADK policy")
        committed = {
            root / "manifests/long_term_asset_qualification.json",
            root / "manifests/software_m5_pilot_ledger.json",
            event_log, summary_path,
        }
        for event in events:
            for relative in event["evidence"]:
                committed.add(_repo_file(root, relative, "terminal event evidence"))
        for relative in detail["review_evidence_files"]:
            committed.add(_repo_file(root, relative, "terminal delegated review evidence"))
        _verify_committed_evidence(root, committed)
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
        if args.as_of:
            # Test-time time travel can prove a code path but cannot issue a
            # real long-term qualification receipt.
            result = {**result, "status": "simulated_pass", "simulated": True,
                      "terminal_qualified": False}
    except LongitudinalBlocked as exc:
        result = _blocked_payload(str(exc))
        if args.as_of:
            result.update(simulated=True, terminal_qualified=False)
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[BLOCKED] {result.get('reason', 'LTA-04 is not yet qualified')}")
        return 2
    except (LongitudinalError, OSError, ValueError) as exc:
        result = {"schema": CHECK_SCHEMA, "status": "fail", "error": str(exc)}
        if args.as_of:
            result.update(simulated=True, terminal_qualified=False)
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        if args.as_of:
            print("[SIMULATED PASS] test-time LTA-04 validation; NOT terminally qualified")
        else:
            print("[PASS] LTA-04 longitudinal operation evidence is qualified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
