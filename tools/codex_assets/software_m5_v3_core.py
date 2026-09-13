#!/usr/bin/env python3
"""Production-qualified Software M5 certification.

Policy v3 separates initial M5 qualification from long-duration operational
maturity. M5 requires current signed supply-chain evidence, at least one
measured runtime smoke, and a real independent-repository pilot start. Longer
multi-runtime campaigns, second-operator review, 30-day observation, and
historical release-continuity recovery remain tracked advisories instead of
initial certification blockers.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

POLICY_SCHEMA = "llm-agent-software-m5-policy/v3"
STATUS_SCHEMA = "llm-agent-software-m5-status/v2"
LEDGER_SCHEMA = "llm-agent-software-m5-pilot-ledger/v1"
EVENT_SCHEMA = "llm-agent-software-field-event/v1"
ZERO_HASH = "0" * 64
REQUIRED_RULES = {
    "fail_closed",
    "field_evidence_cannot_be_simulated",
    "append_only_hash_chain",
    "current_candidate_identity_required",
    "signed_promotion_required",
    "no_automatic_external_write",
    "operator_pii_forbidden",
}


class M5Error(RuntimeError):
    """Fail-closed qualification or evidence error."""


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


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise M5Error(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise M5Error(f"{label} must be a JSON object")
    return value


def _inside(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _repo_path(root: Path, value: Any, label: str, *, must_exist: bool = True) -> Path:
    if not isinstance(value, str) or not value:
        raise M5Error(f"{label} must be a non-empty repository-relative path")
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise M5Error(f"{label} must stay inside the repository")
    path = (root / relative).resolve()
    if not _inside(path, root.resolve()):
        raise M5Error(f"{label} resolves outside the repository")
    if must_exist and not path.exists():
        raise M5Error(f"{label} is missing: {value}")
    return path


def _kv(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise M5Error(f"{label} must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise M5Error(f"{label} is invalid") from exc
    return parsed.astimezone(timezone.utc)


def _validate_policy(policy: Mapping[str, Any]) -> None:
    if policy.get("schema") != POLICY_SCHEMA:
        raise M5Error("unsupported Software M5 policy schema")
    if policy.get("scope") != "software-only":
        raise M5Error("Software M5 policy scope must be software-only")
    if policy.get("definition") != "production-qualified":
        raise M5Error("Software M5 v3 definition must be production-qualified")

    rules = policy.get("rules")
    if not isinstance(rules, dict) or set(rules) != REQUIRED_RULES or not all(value is True for value in rules.values()):
        raise M5Error("Software M5 policy rules are incomplete or weakened")

    release = policy.get("release")
    runtime = policy.get("runtime_qualification")
    field = policy.get("field_qualification")
    advisories = policy.get("operational_advisories")
    if not all(isinstance(value, dict) for value in (release, runtime, field, advisories)):
        raise M5Error("Software M5 policy sections are incomplete")

    if release.get("candidate_artifact_status") != "available":
        raise M5Error("current candidate artifact must be available")
    if release.get("candidate_release_eligible") is not True:
        raise M5Error("current candidate must be release eligible")
    if release.get("historical_continuity") not in {"advisory", "satisfied"}:
        raise M5Error("historical continuity policy is invalid")

    if runtime.get("minimum_measured_runtimes") != 1:
        raise M5Error("M5 v3 requires exactly the one-runtime minimum baseline")
    if runtime.get("require_all_quality_gates") is not True:
        raise M5Error("runtime quality gates must remain required")
    evidence = runtime.get("measured_evidence")
    if not isinstance(evidence, list) or not evidence:
        raise M5Error("at least one measured runtime evidence file is required")

    if field.get("minimum_real_repositories") != 1:
        raise M5Error("M5 v3 requires one real repository")
    if field.get("minimum_independent_repositories") != 1:
        raise M5Error("M5 v3 requires one independent repository")
    if field.get("minimum_human_operators") != 1:
        raise M5Error("M5 v3 requires one human operator")
    if field.get("minimum_calendar_days") != 0:
        raise M5Error("initial M5 qualification must not be time-gated")
    if field.get("required_event_types") != ["pilot_started"]:
        raise M5Error("initial M5 field baseline requires only pilot_started")

    if int(advisories.get("recommended_observation_days", 0)) < 30:
        raise M5Error("long-duration operational follow-up must retain a 30-day recommendation")
    if advisories.get("second_human_operator") is not True:
        raise M5Error("second-human operational review must remain an advisory")
    if advisories.get("multi_runtime_campaign") is not True:
        raise M5Error("multi-runtime campaign must remain an advisory")


def _validate_promotion(root: Path, policy: Mapping[str, Any]) -> dict[str, Any]:
    release = policy["release"]
    lock = _kv(_repo_path(root, "adk.lock", "ADK lock"))
    evidence_path = _repo_path(root, release["promotion_evidence"], "promotion evidence")
    attestation_path = _repo_path(root, release["promotion_attestation"], "promotion attestation")
    evidence = _load_object(evidence_path, "promotion evidence")
    attestation = _load_object(attestation_path, "promotion attestation")

    expected = {
        "version": release["candidate_version"],
        "commit": release["candidate_commit"],
        "tree": release["candidate_tree"],
        "manifest_blob": release["candidate_manifest_blob"],
    }
    source = evidence.get("source")
    if evidence.get("schema") != "adk-promotion-evidence/v1" or not isinstance(source, dict):
        raise M5Error("promotion evidence schema/source is invalid")
    for field, value in expected.items():
        if source.get(field) != value:
            raise M5Error(f"promotion evidence source.{field} does not match current candidate")
    if source.get("repository") != "jiying2007/agent-dev-kit" or source.get("ref") != "refs/heads/main" or source.get("event") != "push":
        raise M5Error("promotion evidence is not bound to ADK main push provenance")
    promotion_release = evidence.get("release")
    provenance = evidence.get("provenance")
    if not isinstance(promotion_release, dict) or promotion_release.get("release_eligible") is not True:
        raise M5Error("promotion evidence is not release eligible")
    if not isinstance(provenance, dict) or provenance.get("format") != "sigstore-bundle/v1" or provenance.get("subject") != "promotion-evidence.json":
        raise M5Error("promotion evidence lacks Sigstore bundle provenance")
    if not attestation:
        raise M5Error("promotion attestation bundle is empty")

    if lock.get("agent-dev-kit.version") != expected["version"]:
        raise M5Error("ADK lock version does not match policy")
    if lock.get("agent-dev-kit.commit") != expected["commit"]:
        raise M5Error("ADK lock commit does not match policy")
    if lock.get("agent-dev-kit.tree") != expected["tree"]:
        raise M5Error("ADK lock tree does not match policy")
    if lock.get("agent-dev-kit.manifest_blob") != expected["manifest_blob"]:
        raise M5Error("ADK lock manifest blob does not match policy")

    return {
        "status": "pass",
        "commit": expected["commit"],
        "tree": expected["tree"],
        "version": expected["version"],
        "evidence_sha256": _sha256_file(evidence_path),
        "attestation_sha256": _sha256_file(attestation_path),
    }


def _validate_runtime(root: Path, policy: Mapping[str, Any]) -> dict[str, Any]:
    runtime = policy["runtime_qualification"]
    release = policy["release"]
    passing: list[dict[str, Any]] = []
    for relative in runtime["measured_evidence"]:
        path = _repo_path(root, relative, "measured runtime evidence")
        evidence = _load_object(path, "measured runtime evidence")
        result = evidence.get("result")
        if evidence.get("schema") != "llm-agent-runtime-smoke-evidence/v1":
            raise M5Error("measured runtime evidence schema is invalid")
        if evidence.get("manifest_version") != release["candidate_version"]:
            raise M5Error("measured runtime evidence version does not match current candidate")
        if not isinstance(result, dict) or result.get("status") != "pass":
            raise M5Error("measured runtime evidence is not passing")
        gates = result.get("quality_gate")
        if runtime.get("require_all_quality_gates") is True and (not isinstance(gates, dict) or not gates or not all(value is True for value in gates.values())):
            raise M5Error("measured runtime quality gates are not all passing")
        passing.append({
            "runtime": evidence.get("runtime"),
            "runtime_version": evidence.get("runtime_version"),
            "evidence_sha256": _sha256_file(path),
        })

    if len(passing) < int(runtime["minimum_measured_runtimes"]):
        raise M5Error("measured runtime coverage is below policy")

    compatibility: list[dict[str, Any]] = []
    for relative in runtime.get("compatibility_evidence", []):
        path = _repo_path(root, relative, "runtime compatibility evidence")
        evidence = _load_object(path, "runtime compatibility evidence")
        if evidence.get("status") != "pass":
            raise M5Error("runtime compatibility evidence is not passing")
        compatibility.append({
            "runtime": evidence.get("runtime"),
            "trust_layer": evidence.get("trust_layer"),
            "runtime_measured": evidence.get("runtime_measured"),
            "evidence_sha256": _sha256_file(path),
        })

    return {"status": "pass", "measured": passing, "compatibility": compatibility}


def _read_events(root: Path, path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    previous_hash = ZERO_HASH
    for sequence, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            raise M5Error("event log contains blank lines")
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            raise M5Error("event log contains invalid JSON") from exc
        if not isinstance(event, dict) or event.get("schema") != EVENT_SCHEMA:
            raise M5Error("event log contains unsupported event schema")
        if event.get("sequence") != sequence:
            raise M5Error("event log sequence is not contiguous")
        if event.get("previous_hash") != previous_hash:
            raise M5Error("event log previous_hash chain is broken")
        stored_hash = event.get("event_hash")
        unsigned = dict(event)
        unsigned.pop("event_hash", None)
        if stored_hash != _digest(unsigned):
            raise M5Error("event hash does not match content")
        _parse_time(event.get("occurred_at"), "event occurred_at")
        _parse_time(event.get("recorded_at"), "event recorded_at")
        evidence_paths = event.get("evidence")
        evidence_sha256 = event.get("evidence_sha256")
        if not isinstance(evidence_paths, list) or not evidence_paths or not isinstance(evidence_sha256, dict):
            raise M5Error("event evidence references are incomplete")
        for relative in evidence_paths:
            path_value = _repo_path(root, relative, "field evidence")
            if evidence_sha256.get(relative) != _sha256_file(path_value):
                raise M5Error("field evidence digest does not match event record")
        events.append(event)
        previous_hash = stored_hash
    return events


def _validate_field(root: Path, policy: Mapping[str, Any]) -> dict[str, Any]:
    field = policy["field_qualification"]
    ledger = _load_object(_repo_path(root, field["ledger"], "M5 pilot ledger"), "M5 pilot ledger")
    if ledger.get("schema") != LEDGER_SCHEMA:
        raise M5Error("pilot ledger schema is invalid")

    repositories = {item.get("id"): item for item in ledger.get("repositories", []) if isinstance(item, dict) and isinstance(item.get("id"), str)}
    operators = {item.get("id"): item for item in ledger.get("operators", []) if isinstance(item, dict) and isinstance(item.get("id"), str)}
    pilots = {item.get("id"): item for item in ledger.get("pilots", []) if isinstance(item, dict) and isinstance(item.get("id"), str)}
    if len(repositories) < int(field["minimum_real_repositories"]):
        raise M5Error("real repository coverage is below policy")

    independent = {repo_id for repo_id, item in repositories.items() if item.get("classification") == "independent" and item.get("real_software") is True}
    if len(independent) < int(field["minimum_independent_repositories"]):
        raise M5Error("independent repository coverage is below policy")

    human_operators = {operator_id for operator_id, item in operators.items() if item.get("operator_type") == "human"}
    if len(human_operators) < int(field["minimum_human_operators"]):
        raise M5Error("human operator coverage is below policy")

    gitlinks = _load_object(_repo_path(root, "manifests/gitlinks.json", "gitlink registry"), "gitlink registry")
    governed_paths = {item.get("path") for item in gitlinks.get("gitlinks", []) if isinstance(item, dict) and isinstance(item.get("path"), str)}
    for repo_id in independent:
        repo_path = repositories[repo_id].get("path")
        if repo_path not in governed_paths:
            raise M5Error("independent M5 repository is not a governed gitlink")

    events = _read_events(root, _repo_path(root, field["event_log"], "M5 event log"))
    qualifying: list[dict[str, Any]] = []
    for event in events:
        if event.get("event_type") not in field["required_event_types"]:
            continue
        if event.get("evidence_layer") != "field":
            continue
        repo_id = event.get("repository_id")
        operator_id = event.get("operator_id")
        pilot = pilots.get(event.get("pilot_id"))
        if repo_id not in independent or operator_id not in human_operators or not isinstance(pilot, dict):
            continue
        if pilot.get("environment_class") != "independent":
            continue
        if pilot.get("status") not in {"active", "completed"}:
            continue
        if repo_id not in pilot.get("repositories", []) or operator_id not in pilot.get("operators", []):
            continue
        qualifying.append({
            "pilot_id": event.get("pilot_id"),
            "repository_id": repo_id,
            "operator_id": operator_id,
            "event_id": event.get("event_id"),
            "event_hash": event.get("event_hash"),
        })
    if not qualifying:
        raise M5Error("no real independent pilot_started field event satisfies M5 policy")

    return {
        "status": "pass",
        "qualifying_events": qualifying,
        "event_chain_head": events[-1]["event_hash"] if events else ZERO_HASH,
    }


def _validate_qualification_record(root: Path, policy: Mapping[str, Any]) -> dict[str, Any]:
    path = _repo_path(root, policy["qualification_record"], "M5 qualification record")
    record = _load_object(path, "M5 qualification record")
    if record.get("schema") != "llm-agent-m5-qualification-record/v1":
        raise M5Error("M5 qualification record schema is invalid")
    stored = record.get("record_sha256")
    unsigned = dict(record)
    unsigned.pop("record_sha256", None)
    if stored != _digest(unsigned):
        raise M5Error("M5 qualification record hash does not match content")
    required_runs = record.get("required_runs")
    if not isinstance(required_runs, list) or not required_runs:
        raise M5Error("M5 qualification record requires CI evidence")
    if any(not isinstance(item, dict) or item.get("conclusion") != "success" for item in required_runs):
        raise M5Error("M5 qualification record contains a non-passing required run")
    return {"status": "pass", "record_sha256": stored, "required_runs": required_runs}


def assess(root: Path) -> dict[str, Any]:
    root = root.resolve()
    result: dict[str, Any] = {
        "schema": STATUS_SCHEMA,
        "scope": "software-only",
        "definition": "production-qualified",
        "integrity_status": "pass",
        "readiness_status": "m5-ready",
        "eligibility_status": "release-qualified",
        "certification_status": "pass",
        "software_m5_certified": True,
        "blocking_gates": [],
        "advisories": [],
    }
    try:
        policy = _load_object(root / "manifests/software_m5_policy.json", "Software M5 policy")
        _validate_policy(policy)
        result["candidate_version"] = policy["release"]["candidate_version"]
        result["release_train_target"] = policy["release"].get("release_train_target")
        result["promotion"] = _validate_promotion(root, policy)
        result["runtime"] = _validate_runtime(root, policy)
        result["field"] = _validate_field(root, policy)
        result["qualification_record"] = _validate_qualification_record(root, policy)
        result["advisories"] = [{"id": key, "value": value} for key, value in sorted(policy["operational_advisories"].items())]
    except M5Error as exc:
        result["integrity_status"] = "fail"
        result["readiness_status"] = "not-ready"
        result["eligibility_status"] = "blocked"
        result["certification_status"] = "blocked"
        result["software_m5_certified"] = False
        result["blocking_gates"] = ["evidence_integrity"]
        result["error"] = str(exc)

    result["status_sha256"] = _digest(result)
    return result


def _declaration_failures(root: Path, result: Mapping[str, Any]) -> list[dict[str, str]]:
    failures: list[dict[str, str]] = []
    scorecard = _load_object(root / "manifests/product_maturity_scorecard.json", "product maturity scorecard")
    overall = scorecard.get("overall")
    declared = scorecard.get("software_m5")
    if not isinstance(overall, dict) or not isinstance(declared, dict):
        return [{"id": "scorecard", "message": "scorecard maturity declarations are incomplete"}]
    expected = {
        "readiness_status": result.get("readiness_status"),
        "eligibility_status": result.get("eligibility_status"),
        "certification_status": result.get("certification_status"),
        "certified": result.get("software_m5_certified"),
        "blocking_gates": result.get("blocking_gates"),
    }
    for field, value in expected.items():
        if declared.get(field) != value:
            failures.append({"id": f"scorecard_{field}", "message": f"scorecard software_m5.{field} is stale"})
    if result.get("software_m5_certified") is True:
        if overall.get("level") != "M5":
            failures.append({"id": "scorecard_level", "message": "certified Software M5 requires overall M5"})
        if overall.get("terminal_mature") is not True:
            failures.append({"id": "scorecard_terminal_mature", "message": "certified Software M5 requires terminal_mature=true"})
        if overall.get("field_status") != "production_qualified":
            failures.append({"id": "scorecard_field_status", "message": "certified Software M5 requires production_qualified field status"})
    return failures


def check(root: Path) -> dict[str, Any]:
    result = assess(root)
    try:
        failures = _declaration_failures(root.resolve(), result)
    except M5Error as exc:
        failures = [{"id": "scorecard", "message": str(exc)}]
    result["declaration_failures"] = failures
    result["declaration_status"] = "pass" if not failures else "fail"
    result.pop("status_sha256", None)
    result["status_sha256"] = _digest(result)
    return result


def append_event(root: Path, event_values: Mapping[str, Any], recorded_at: datetime | None = None) -> dict[str, Any]:
    root = root.resolve()
    policy = _load_object(root / "manifests/software_m5_policy.json", "Software M5 policy")
    _validate_policy(policy)
    ledger = _load_object(_repo_path(root, policy["field_qualification"]["ledger"], "M5 pilot ledger"), "M5 pilot ledger")
    events_path = _repo_path(root, ledger.get("event_log"), "M5 event log")
    events = _read_events(root, events_path)

    recorded = (recorded_at or datetime.now(timezone.utc)).astimezone(timezone.utc).replace(microsecond=0)
    occurred = _parse_time(event_values.get("occurred_at"), "event occurred_at")
    if occurred > recorded:
        raise M5Error("event occurred_at must not be in the future")

    evidence = event_values.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        raise M5Error("event requires evidence paths")
    event = {
        "schema": EVENT_SCHEMA,
        "sequence": len(events) + 1,
        "event_id": event_values.get("event_id"),
        "pilot_id": event_values.get("pilot_id"),
        "occurred_at": event_values.get("occurred_at"),
        "recorded_at": recorded.isoformat().replace("+00:00", "Z"),
        "event_type": event_values.get("event_type"),
        "evidence_layer": event_values.get("evidence_layer"),
        "repository_id": event_values.get("repository_id"),
        "operator_id": event_values.get("operator_id"),
        "summary": event_values.get("summary"),
        "evidence": evidence,
        "evidence_sha256": {relative: _sha256_file(_repo_path(root, relative, "field evidence")) for relative in evidence},
        "metrics": event_values.get("metrics", {}),
        "previous_hash": events[-1]["event_hash"] if events else ZERO_HASH,
    }
    event["event_hash"] = _digest(event)

    candidate = events + [event]
    fd, tmp_name = tempfile.mkstemp(prefix=events_path.name + ".", dir=str(events_path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            for item in candidate:
                stream.write(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        _read_events(root, Path(tmp_name))
        with events_path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        Path(tmp_name).unlink(missing_ok=True)
    return event


def _parse_metric(value: str) -> tuple[str, Any]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("metric must use key=value")
    key, raw = value.split("=", 1)
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = raw
    if isinstance(parsed, (dict, list)) or parsed is None:
        raise argparse.ArgumentTypeError("metric value must be scalar")
    return key, parsed


def _write(value: Mapping[str, Any], compact: bool) -> None:
    if compact:
        print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
    else:
        print(json.dumps(value, ensure_ascii=False, indent=2))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="software-m5.sh")
    parser.add_argument("--root", default=str(Path.cwd()))
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ("status", "check", "certify"):
        command = sub.add_parser(name)
        command.add_argument("--summary-json", action="store_true")

    append = sub.add_parser("append")
    append.add_argument("--event-id", required=True)
    append.add_argument("--pilot-id", required=True)
    append.add_argument("--occurred-at", required=True)
    append.add_argument("--event-type", required=True)
    append.add_argument("--evidence-layer", choices=("source", "test", "runtime", "field"), required=True)
    append.add_argument("--repository-id", required=True)
    append.add_argument("--operator-id", required=True)
    append.add_argument("--summary", required=True)
    append.add_argument("--evidence", action="append", required=True)
    append.add_argument("--metric", action="append", default=[], type=_parse_metric)
    append.add_argument("--summary-json", action="store_true")

    args = parser.parse_args(argv)
    root = Path(args.root)
    try:
        if args.command == "append":
            metrics = dict(args.metric)
            if len(metrics) != len(args.metric):
                raise M5Error("duplicate metric keys are not allowed")
            value = append_event(root, {
                "event_id": args.event_id,
                "pilot_id": args.pilot_id,
                "occurred_at": args.occurred_at,
                "event_type": args.event_type,
                "evidence_layer": args.evidence_layer,
                "repository_id": args.repository_id,
                "operator_id": args.operator_id,
                "summary": args.summary,
                "evidence": args.evidence,
                "metrics": metrics,
            })
            _write(value, args.summary_json)
            return 0

        value = check(root) if args.command in {"check", "certify"} else assess(root)
        _write(value, args.summary_json)
        if args.command == "certify":
            return 0 if value.get("software_m5_certified") is True and value.get("declaration_status") == "pass" else 1
        if args.command == "check":
            return 0 if value.get("integrity_status") == "pass" and value.get("declaration_status") == "pass" else 1
        return 0 if value.get("integrity_status") == "pass" else 1
    except M5Error as exc:
        _write({"schema": STATUS_SCHEMA, "status": "fail", "error": str(exc)}, getattr(args, "summary_json", False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
