#!/usr/bin/env python3
"""Software-side M5 pilot ledger, evidence integrity, and certification gate."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple


POLICY_SCHEMA = "llm-agent-software-m5-policy/v1"
POLICY_SCHEMA_V2 = "llm-agent-software-m5-policy/v2"
LEDGER_SCHEMA = "llm-agent-software-m5-pilot-ledger/v1"
EVENT_SCHEMA = "llm-agent-software-field-event/v1"
STATUS_SCHEMA = "llm-agent-software-m5-status/v1"
CAMPAIGN_SCHEMA = "adk-runtime-eval-campaign-report/v1"
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$")
HEX64_RE = re.compile(r"^[0-9a-f]{64}$")
ZERO_HASH = "0" * 64
REQUIRED_POLICY_RULES = {
    "fail_closed",
    "field_evidence_cannot_be_simulated",
    "append_only_hash_chain",
    "independent_repository_required",
    "second_human_operator_required",
    "final_release_requires_eligibility",
    "no_automatic_external_write",
    "operator_pii_forbidden",
}
REQUIRED_RUNTIME_MODELS = {"codex": "gpt-5.5", "claude": "claude-sonnet-4-6"}
REQUIRED_FIELD_EVENT_TYPES = {
    "pilot_started",
    "task_selection_recorded",
    "human_baseline_recorded",
    "workload_executed",
    "upgrade_completed",
    "rollback_exercised",
    "fault_observed",
    "recovery_completed",
    "maintenance_recorded",
    "pilot_reviewed",
}
REQUIRED_METRIC_CONTRACTS = {
    "task_selection_recorded": {
        "preregistered_task_count": {"type": "integer", "minimum": 1},
        "accepted_task_count": {"type": "integer", "minimum": 1},
        "rejected_task_count": {"type": "integer", "minimum": 0},
        "refusal_log_status": {"type": "string", "enum": ["complete"]},
    },
    "human_baseline_recorded": {
        "baseline_task_count": {"type": "integer", "minimum": 1},
        "human_estimate_minutes": {"type": "number", "minimum": 0.01},
        "estimation_method": {"type": "string", "enum": ["measured", "historical-calibrated"]},
    },
    "workload_executed": {
        "task_count": {"type": "integer", "minimum": 1},
        "success_rate": {"type": "number", "minimum": 0.85, "maximum": 1},
        "preregistered_task_count": {"type": "integer", "minimum": 1},
        "rejected_task_count": {"type": "integer", "minimum": 0},
        "wall_clock_minutes": {"type": "number", "minimum": 0.01},
        "human_active_minutes": {"type": "number", "minimum": 0},
        "agent_active_minutes": {"type": "number", "minimum": 0.01},
        "concurrent_agent_peak": {"type": "integer", "minimum": 1},
    },
    "upgrade_completed": {
        "from_version": {"type": "semver", "equals_release": "previous_version"},
        "to_version": {"type": "semver", "equals_release": "evaluation_version"},
        "downtime_seconds": {"type": "number", "minimum": 0},
    },
    "rollback_exercised": {
        "restored_version": {"type": "semver", "equals_release": "previous_version"},
        "downtime_seconds": {"type": "number", "minimum": 0},
    },
    "fault_observed": {
        "severity": {"type": "string", "enum": ["contained", "minor", "major", "critical"]},
    },
    "recovery_completed": {"recovery_minutes": {"type": "number", "minimum": 0}},
    "maintenance_recorded": {"human_minutes": {"type": "number", "minimum": 0}},
    "pilot_reviewed": {
        "decision": {"type": "string", "enum": ["approve"]},
        "selection_bias_status": {"type": "string", "enum": ["assessed"]},
        "time_measurement_status": {"type": "string", "enum": ["measured"]},
        "confidence_interval_status": {"type": "string", "enum": ["reported"]},
    },
}


class M5Error(RuntimeError):
    """Fail-closed contract or evidence error."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _adk_manifest_digest(value: Mapping[str, Any]) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def _format_time(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise M5Error("{} must be an ISO-8601 UTC timestamp ending in Z".format(label))
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise M5Error("{} must be an ISO-8601 UTC timestamp".format(label)) from exc
    if parsed.tzinfo is None:
        raise M5Error("{} must include a timezone".format(label))
    return parsed.astimezone(timezone.utc)


def _load_object(path: Path, label: str) -> Dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise M5Error("invalid {} JSON: {}".format(label, path)) from exc
    if not isinstance(value, dict):
        raise M5Error("{} JSON root must be an object".format(label))
    return value


def _inside(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _repo_path(root: Path, value: Any, label: str, must_exist: bool = True) -> Path:
    if not isinstance(value, str) or not value:
        raise M5Error("{} must be a non-empty repository-relative path".format(label))
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise M5Error("{} must stay inside the repository".format(label))
    path = (root / relative).resolve()
    if not _inside(path, root.resolve()):
        raise M5Error("{} resolves outside the repository".format(label))
    if must_exist and not path.exists():
        raise M5Error("{} is missing: {}".format(label, value))
    return path


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _evidence_digest(root: Path, value: Any) -> str:
    if not isinstance(value, str) or not value:
        raise M5Error("event evidence must be a non-empty repository-relative path")
    unresolved = root / Path(value)
    if unresolved.is_symlink():
        raise M5Error("event evidence must not be a symlink: {}".format(value))
    path = _repo_path(root, value, "event evidence")
    if not path.is_file():
        raise M5Error("event evidence must be a regular file: {}".format(value))
    return _sha256_file(path)


def _git_repository_identity(path: Path) -> Tuple[Path, Path]:
    git = shutil.which("git")
    if git is None:
        raise M5Error("git is required to validate independent repository identity")
    values = []
    for argument in ("--show-toplevel", "--git-common-dir"):
        try:
            completed = subprocess.run(
                [git, "-C", str(path), "rev-parse", argument],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise M5Error("cannot validate independent Git repository: {}".format(path)) from exc
        if completed.returncode != 0 or not completed.stdout.strip():
            raise M5Error("independent repository is not a valid Git worktree: {}".format(path))
        values.append(completed.stdout.strip())
    top = Path(values[0]).resolve()
    common_value = Path(values[1])
    common = (path / common_value).resolve() if not common_value.is_absolute() else common_value.resolve()
    return top, common


def _ids(items: Any, label: str) -> Dict[str, Mapping[str, Any]]:
    if not isinstance(items, list) or not items:
        raise M5Error("{} must be a non-empty array".format(label))
    result: Dict[str, Mapping[str, Any]] = {}
    for item in items:
        if not isinstance(item, dict):
            raise M5Error("{} entries must be objects".format(label))
        item_id = item.get("id")
        if not isinstance(item_id, str) or not ID_RE.fullmatch(item_id):
            raise M5Error("{} entry has an invalid id".format(label))
        if item_id in result:
            raise M5Error("{} contains duplicate id: {}".format(label, item_id))
        result[item_id] = item
    return result


def _validate_policy(policy: Mapping[str, Any]) -> None:
    policy_schema = policy.get("schema")
    if policy_schema not in {POLICY_SCHEMA, POLICY_SCHEMA_V2}:
        raise M5Error("unsupported software M5 policy schema")
    if policy.get("scope") != "software-only":
        raise M5Error("software M5 policy scope must be software-only")
    rules = policy.get("rules")
    if (
        not isinstance(rules, dict)
        or set(rules) != REQUIRED_POLICY_RULES
        or not all(value is True for value in rules.values())
    ):
        raise M5Error("software M5 policy rules must contain the complete non-weakening baseline")
    release = policy.get("release")
    campaign = policy.get("runtime_campaign")
    repository_campaign = policy.get("repository_runtime_campaign")
    field = policy.get("field_certification")
    if not all(isinstance(value, dict) for value in (release, campaign, repository_campaign, field)):
        raise M5Error("software M5 policy sections are incomplete")
    for name in ("previous_version", "candidate_version", "evaluation_version", "final_version"):
        value = release.get(name)
        if not isinstance(value, str) or not SEMVER_RE.fullmatch(value):
            raise M5Error("release.{} must be a semantic version".format(name))
    for name in ("manifest", "rehearsal_report", "evidence_report"):
        value = release.get(name)
        if not isinstance(value, str) or not value:
            raise M5Error("release.{} must be a repository-relative path".format(name))
        relative = Path(value)
        if relative.is_absolute() or ".." in relative.parts:
            raise M5Error("release.{} must be a repository-relative path".format(name))
    if not HEX64_RE.fullmatch(str(release.get("candidate_sha256", ""))):
        raise M5Error("release.candidate_sha256 must be a SHA256 digest")
    if policy_schema == POLICY_SCHEMA_V2:
        for name in ("previous_commit", "previous_sha256", "previous_manifest_sha256", "previous_evidence_sha256"):
            value = release.get(name)
            pattern = r"[0-9a-f]{40}" if name == "previous_commit" else r"[0-9a-f]{64}"
            if not isinstance(value, str) or re.fullmatch(pattern, value) is None:
                raise M5Error("release.{} has an invalid immutable identity".format(name))
        previous_evidence = release.get("previous_evidence_report")
        if not isinstance(previous_evidence, str) or not previous_evidence:
            raise M5Error("release.previous_evidence_report must be repository-relative")
        previous_evidence_path = Path(previous_evidence)
        if previous_evidence_path.is_absolute() or ".." in previous_evidence_path.parts:
            raise M5Error("release.previous_evidence_report must be repository-relative")
        if release.get("previous_artifact_status") not in {"available", "unavailable"}:
            raise M5Error("release.previous_artifact_status is invalid")
        if release.get("candidate_artifact_status") not in {"available", "superseded"}:
            raise M5Error("release.candidate_artifact_status is invalid")
        if release.get("candidate_release_eligible") is not (release.get("candidate_artifact_status") == "available"):
            raise M5Error("release candidate eligibility does not match artifact status")
        if release.get("candidate_artifact_status") == "available":
            for name, pattern in (
                ("candidate_commit", r"[0-9a-f]{40}"),
                ("candidate_tree", r"[0-9a-f]{40}"),
                ("candidate_source_distribution_sha256", r"[0-9a-f]{64}"),
            ):
                if re.fullmatch(pattern, str(release.get(name, ""))) is None:
                    raise M5Error("release.{} is required for an eligible candidate".format(name))
        if release.get("release_continuity_required") is not True:
            raise M5Error("release continuity must remain required")
    budget = campaign.get("max_budget_usd")
    if isinstance(budget, bool) or not isinstance(budget, (int, float)) or not (0 < float(budget) <= 150):
        raise M5Error("runtime campaign budget must be within $150")
    if campaign.get("required_runtimes") != ["codex", "claude"]:
        raise M5Error("runtime campaign must require codex and claude")
    models = campaign.get("required_models")
    if models != REQUIRED_RUNTIME_MODELS:
        raise M5Error("runtime campaign required_models do not match the frozen M5 campaign")
    for name in ("manifest", "contract", "tasks", "state_dir", "report"):
        if not isinstance(campaign.get(name), str) or not campaign[name]:
            raise M5Error("runtime_campaign.{} must be a repository-relative path".format(name))
    minimum_tasks = campaign.get("minimum_tasks")
    minimum_trials = campaign.get("minimum_trials")
    if (
        isinstance(minimum_tasks, bool)
        or not isinstance(minimum_tasks, int)
        or minimum_tasks < 60
        or isinstance(minimum_trials, bool)
        or not isinstance(minimum_trials, int)
        or minimum_trials < 3
    ):
        raise M5Error("runtime campaign minimum coverage is below the M5 policy")
    repository_budget = repository_campaign.get("max_budget_usd")
    if (
        isinstance(repository_budget, bool)
        or not isinstance(repository_budget, (int, float))
        or not (0 < float(repository_budget) <= 150)
    ):
        raise M5Error("repository runtime campaign budget must be within $150")
    required_repository_runtimes = repository_campaign.get("required_runtimes")
    if (
        not isinstance(required_repository_runtimes, list)
        or len(required_repository_runtimes) < 2
        or len(set(required_repository_runtimes)) != len(required_repository_runtimes)
        or any(not isinstance(value, str) or not ID_RE.fullmatch(value) for value in required_repository_runtimes)
    ):
        raise M5Error("repository runtime campaign must require at least two runtimes")
    for name in ("root", "contract", "report"):
        if not isinstance(repository_campaign.get(name), str) or not repository_campaign[name]:
            raise M5Error("repository_runtime_campaign.{} must be a repository-relative path".format(name))
        relative = Path(repository_campaign[name])
        if relative.is_absolute() or ".." in relative.parts:
            raise M5Error("repository_runtime_campaign.{} must be a repository-relative path".format(name))
    repository_minimum_tasks = repository_campaign.get("minimum_tasks")
    repository_minimum_real_tasks = repository_campaign.get("minimum_real_tasks")
    repository_minimum_trials = repository_campaign.get("minimum_trials")
    if (
        isinstance(repository_minimum_tasks, bool)
        or not isinstance(repository_minimum_tasks, int)
        or repository_minimum_tasks < 5
        or isinstance(repository_minimum_real_tasks, bool)
        or not isinstance(repository_minimum_real_tasks, int)
        or repository_minimum_real_tasks < 2
        or repository_minimum_real_tasks > repository_minimum_tasks
        or isinstance(repository_minimum_trials, bool)
        or not isinstance(repository_minimum_trials, int)
        or repository_minimum_trials < 3
    ):
        raise M5Error("repository runtime campaign minimum coverage is below policy")
    minimum_days = field.get("minimum_calendar_days")
    minimum_repositories = field.get("minimum_real_repositories")
    minimum_independent = field.get("minimum_independent_repositories")
    minimum_operators = field.get("minimum_human_operators")
    if isinstance(minimum_days, bool) or not isinstance(minimum_days, int) or minimum_days < 30:
        raise M5Error("field certification must require at least 30 calendar days")
    if isinstance(minimum_repositories, bool) or not isinstance(minimum_repositories, int) or minimum_repositories < 2:
        raise M5Error("field certification must require at least two real repositories")
    if isinstance(minimum_independent, bool) or not isinstance(minimum_independent, int) or minimum_independent < 1:
        raise M5Error("field certification must require an independent repository")
    if isinstance(minimum_operators, bool) or not isinstance(minimum_operators, int) or minimum_operators < 2:
        raise M5Error("field certification must require a second human operator")
    event_types = field.get("required_event_types")
    metrics = field.get("required_metrics")
    metric_contracts = field.get("metric_contracts")
    if (
        not isinstance(event_types, list)
        or set(event_types) != REQUIRED_FIELD_EVENT_TYPES
        or len(event_types) != len(REQUIRED_FIELD_EVENT_TYPES)
    ):
        raise M5Error("field certification required_event_types are incomplete")
    if not all(isinstance(value, str) and ID_RE.fullmatch(value) for value in event_types):
        raise M5Error("field certification contains an invalid event type")
    if not isinstance(metrics, dict) or set(metrics) != set(REQUIRED_METRIC_CONTRACTS):
        raise M5Error("field certification required_metrics are invalid")
    for event_type, fields in metrics.items():
        expected_fields = set(REQUIRED_METRIC_CONTRACTS[event_type])
        if (
            not isinstance(fields, list)
            or set(fields) != expected_fields
            or len(fields) != len(expected_fields)
            or not all(isinstance(value, str) and ID_RE.fullmatch(value) for value in fields)
        ):
            raise M5Error("required metrics are invalid for {}".format(event_type))
    if not isinstance(metric_contracts, dict) or set(metric_contracts) != set(metrics):
        raise M5Error("field certification metric_contracts do not match required_metrics")
    for event_type, fields in metrics.items():
        contracts = metric_contracts.get(event_type)
        if not isinstance(contracts, dict) or set(contracts) != set(fields):
            raise M5Error("metric contracts are incomplete for {}".format(event_type))
        if contracts != REQUIRED_METRIC_CONTRACTS[event_type]:
            raise M5Error("metric contracts weaken the software M5 baseline for {}".format(event_type))
        for field_name, contract in contracts.items():
            if not isinstance(contract, dict) or contract.get("type") not in {
                "integer",
                "number",
                "string",
                "semver",
            }:
                raise M5Error("metric contract is invalid for {}.{}".format(event_type, field_name))
            enum = contract.get("enum")
            if enum is not None:
                if (
                    not isinstance(enum, list)
                    or not enum
                    or any(isinstance(value, (dict, list)) or value is None for value in enum)
                    or len({json.dumps(value, sort_keys=True) for value in enum}) != len(enum)
                ):
                    raise M5Error("metric enum is invalid for {}.{}".format(event_type, field_name))
            equals_release = contract.get("equals_release")
            if equals_release is not None and equals_release not in {
                "previous_version",
                "candidate_version",
                "evaluation_version",
                "final_version",
            }:
                raise M5Error("metric release binding is invalid for {}.{}".format(event_type, field_name))
            for bound in ("minimum", "maximum"):
                bound_value = contract.get(bound)
                if bound_value is not None and (
                    isinstance(bound_value, bool) or not isinstance(bound_value, (int, float))
                ):
                    raise M5Error("metric bound is invalid for {}.{}".format(event_type, field_name))
            if any(contract.get(bound) is not None for bound in ("minimum", "maximum")) and contract["type"] not in {
                "integer",
                "number",
            }:
                raise M5Error("metric bounds require a numeric type for {}.{}".format(event_type, field_name))
            if (
                contract.get("minimum") is not None
                and contract.get("maximum") is not None
                and float(contract["minimum"]) > float(contract["maximum"])
            ):
                raise M5Error("metric minimum exceeds maximum for {}.{}".format(event_type, field_name))


def _validate_ledger(
    ledger: Mapping[str, Any], policy: Mapping[str, Any]
) -> Tuple[Dict[str, Mapping[str, Any]], Dict[str, Mapping[str, Any]], Dict[str, Mapping[str, Any]]]:
    if ledger.get("schema") != LEDGER_SCHEMA:
        raise M5Error("unsupported software M5 pilot ledger schema")
    release = policy["release"]
    if ledger.get("candidate_version") != release["candidate_version"]:
        raise M5Error("pilot ledger candidate_version does not match policy")
    repositories = _ids(ledger.get("repositories"), "repositories")
    operators = _ids(ledger.get("operators"), "operators")
    pilots = _ids(ledger.get("pilots"), "pilots")
    root_path = Path(str(ledger["_root"])).resolve()
    root_git_identity: Optional[Tuple[Path, Path]] = None
    for repository in repositories.values():
        if repository.get("classification") not in {"self", "independent"}:
            raise M5Error("repository classification must be self or independent")
        if repository.get("real_software") is not True:
            raise M5Error("pilot repositories must explicitly be real software repositories")
        repository_path = _repo_path(root_path, repository.get("path"), "repository path")
        if repository.get("classification") == "independent":
            if root_git_identity is None:
                root_git_identity = _git_repository_identity(root_path)
            repository_top, repository_common = _git_repository_identity(repository_path)
            if repository_top != repository_path:
                raise M5Error("independent repository path must be its Git top-level")
            if repository_common == root_git_identity[1]:
                raise M5Error("independent repository must not share the product Git common directory")
    for operator in operators.values():
        if operator.get("operator_type") not in {"human", "automation"}:
            raise M5Error("operator_type must be human or automation")
        if not isinstance(operator.get("role"), str) or not operator.get("role"):
            raise M5Error("operator role is required")
        if not isinstance(operator.get("independent_reviewer"), bool):
            raise M5Error("operator independent_reviewer must be boolean")
        allowed_operator_fields = {"id", "operator_type", "role", "independent_reviewer"}
        if set(operator).difference(allowed_operator_fields):
            raise M5Error("operator ledger must not contain names, email addresses, or extra PII fields")
    for pilot in pilots.values():
        if pilot.get("status") not in {"active", "completed", "withdrawn"}:
            raise M5Error("pilot status is invalid")
        if pilot.get("environment_class") not in {"self", "independent"}:
            raise M5Error("pilot environment_class is invalid")
        started = _parse_time(pilot.get("started_at"), "pilot started_at")
        ended_value = pilot.get("ended_at")
        if ended_value is not None:
            ended = _parse_time(ended_value, "pilot ended_at")
            if ended < started:
                raise M5Error("pilot ended_at precedes started_at")
            if pilot.get("status") == "active":
                raise M5Error("active pilot must not have ended_at")
        elif pilot.get("status") == "completed":
            raise M5Error("completed pilot requires ended_at")
        pilot_repositories = pilot.get("repositories")
        pilot_operators = pilot.get("operators")
        if not isinstance(pilot_repositories, list) or not pilot_repositories:
            raise M5Error("pilot repositories are required")
        if not isinstance(pilot_operators, list) or not pilot_operators:
            raise M5Error("pilot operators are required")
        if any(value not in repositories for value in pilot_repositories):
            raise M5Error("pilot references an unknown repository")
        if any(value not in operators for value in pilot_operators):
            raise M5Error("pilot references an unknown operator")
        if len(set(pilot_repositories)) != len(pilot_repositories):
            raise M5Error("pilot contains duplicate repositories")
        if len(set(pilot_operators)) != len(pilot_operators):
            raise M5Error("pilot contains duplicate operators")
        if pilot.get("environment_class") == "independent" and not any(
            repositories[value]["classification"] == "independent" for value in pilot_repositories
        ):
            raise M5Error("independent pilot must include an independent repository")
    return repositories, operators, pilots


def _read_events(root: Path, path: Path, as_of: datetime) -> List[Dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise M5Error("cannot read software M5 event log") from exc
    events: List[Dict[str, Any]] = []
    previous_hash = ZERO_HASH
    previous_recorded: Optional[datetime] = None
    seen_ids = set()
    for index, line in enumerate(lines, start=1):
        if not line.strip():
            raise M5Error("event log contains a blank line at sequence {}".format(index))
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            raise M5Error("event log contains invalid JSON at sequence {}".format(index)) from exc
        if not isinstance(event, dict) or event.get("schema") != EVENT_SCHEMA:
            raise M5Error("event log contains an unsupported event at sequence {}".format(index))
        if event.get("sequence") != index:
            raise M5Error("event log sequence is not contiguous")
        event_id = event.get("event_id")
        if not isinstance(event_id, str) or not ID_RE.fullmatch(event_id) or event_id in seen_ids:
            raise M5Error("event log contains an invalid or duplicate event_id")
        seen_ids.add(event_id)
        if event.get("previous_hash") != previous_hash:
            raise M5Error("event log previous_hash chain is broken")
        stored_hash = event.get("event_hash")
        unsigned = dict(event)
        unsigned.pop("event_hash", None)
        if not isinstance(stored_hash, str) or stored_hash != _digest(unsigned):
            raise M5Error("event log event_hash does not match content")
        occurred = _parse_time(event.get("occurred_at"), "event occurred_at")
        recorded = _parse_time(event.get("recorded_at"), "event recorded_at")
        if occurred > recorded or recorded > as_of:
            raise M5Error("event timestamps are future-dated or out of order")
        if previous_recorded is not None and recorded < previous_recorded:
            raise M5Error("event recorded_at timestamps are not monotonic")
        previous_recorded = recorded
        for field in ("pilot_id", "event_type", "repository_id", "operator_id"):
            value = event.get(field)
            if not isinstance(value, str) or not ID_RE.fullmatch(value):
                raise M5Error("event {} is invalid".format(field))
        if event.get("evidence_layer") not in {"source", "test", "runtime", "field"}:
            raise M5Error("event evidence_layer is invalid")
        summary = event.get("summary")
        if not isinstance(summary, str) or not summary or len(summary) > 240:
            raise M5Error("event summary must contain 1-240 characters")
        evidence = event.get("evidence")
        if (
            not isinstance(evidence, list)
            or not evidence
            or not all(isinstance(value, str) and value for value in evidence)
            or len(set(evidence)) != len(evidence)
        ):
            raise M5Error("event must reference at least one evidence path")
        expected_evidence_digests = {
            evidence_path: _evidence_digest(root, evidence_path) for evidence_path in evidence
        }
        if event.get("evidence_sha256") != expected_evidence_digests:
            raise M5Error("event evidence digest does not match current content")
        metrics = event.get("metrics")
        if not isinstance(metrics, dict) or any(
            not isinstance(key, str)
            or not ID_RE.fullmatch(key)
            or isinstance(value, (dict, list))
            or value is None
            or (isinstance(value, float) and not math.isfinite(value))
            for key, value in metrics.items()
        ):
            raise M5Error("event metrics must contain scalar values with stable keys")
        previous_hash = stored_hash
        events.append(event)
    return events


def _validate_event_references(
    events: Sequence[Mapping[str, Any]],
    repositories: Mapping[str, Mapping[str, Any]],
    operators: Mapping[str, Mapping[str, Any]],
    pilots: Mapping[str, Mapping[str, Any]],
) -> None:
    for event in events:
        pilot = pilots.get(str(event["pilot_id"]))
        if pilot is None:
            raise M5Error("event references an unknown pilot")
        if event["repository_id"] not in repositories or event["repository_id"] not in pilot["repositories"]:
            raise M5Error("event repository is not registered for its pilot")
        if event["operator_id"] not in operators or event["operator_id"] not in pilot["operators"]:
            raise M5Error("event operator is not registered for its pilot")
        occurred = _parse_time(event["occurred_at"], "event occurred_at")
        started = _parse_time(pilot["started_at"], "pilot started_at")
        ended = _parse_time(pilot["ended_at"], "pilot ended_at") if pilot.get("ended_at") else None
        if occurred < started or (ended is not None and occurred > ended):
            raise M5Error("event occurred outside its pilot window")


def _metric_matches(
    value: Any,
    contract: Mapping[str, Any],
    release: Mapping[str, Any],
) -> bool:
    value_type = contract.get("type")
    if value_type == "integer":
        valid = isinstance(value, int) and not isinstance(value, bool)
    elif value_type == "number":
        valid = (
            isinstance(value, (int, float))
            and not isinstance(value, bool)
            and math.isfinite(float(value))
        )
    elif value_type == "string":
        valid = isinstance(value, str) and bool(value)
    elif value_type == "semver":
        valid = isinstance(value, str) and SEMVER_RE.fullmatch(value) is not None
    else:
        return False
    if not valid:
        return False
    if contract.get("enum") is not None and value not in contract["enum"]:
        return False
    if contract.get("minimum") is not None and float(value) < float(contract["minimum"]):
        return False
    if contract.get("maximum") is not None and float(value) > float(contract["maximum"]):
        return False
    release_field = contract.get("equals_release")
    if release_field is not None and value != release.get(release_field):
        return False
    return True


def _validate_release(root: Path, policy: Mapping[str, Any]) -> Tuple[bool, str]:
    release = policy["release"]
    manifest_path = _repo_path(root, release.get("manifest"), "candidate manifest", must_exist=False)
    if not manifest_path.is_file():
        return False, "candidate manifest is missing"
    manifest = _load_object(manifest_path, "candidate manifest")
    if manifest.get("version") != release["candidate_version"]:
        raise M5Error("candidate manifest version does not match policy")
    manifest_sha256 = _adk_manifest_digest(manifest)
    if policy.get("schema") == POLICY_SCHEMA_V2:
        previous_evidence_path = _repo_path(
            root, release.get("previous_evidence_report"), "previous release evidence"
        )
        if _sha256_file(previous_evidence_path) != release.get("previous_evidence_sha256"):
            raise M5Error("previous release evidence file digest does not match continuity policy")
        previous_evidence = _load_object(previous_evidence_path, "previous release evidence")
        previous_adk = previous_evidence.get("agent_dev_kit")
        previous_artifacts = previous_evidence.get("artifacts")
        if not isinstance(previous_adk, dict) or not isinstance(previous_artifacts, dict):
            raise M5Error("previous release evidence identity is incomplete")
        if (
            previous_adk.get("version") != release["previous_version"]
            or previous_adk.get("commit") != release["previous_commit"]
            or previous_artifacts.get("source_sha256") != release["previous_sha256"]
            or previous_artifacts.get("candidate_manifest_sha256") != release["previous_manifest_sha256"]
        ):
            raise M5Error("previous release evidence does not match the continuity policy")
        if release.get("previous_artifact_status") != "available":
            return False, "previous official release artifact is unavailable"
        if release.get("candidate_artifact_status") != "available":
            return False, "candidate release artifact is superseded or unavailable"
    path = _repo_path(root, release.get("rehearsal_report"), "release rehearsal", must_exist=False)
    if not path.is_file():
        return False, "release rehearsal report is missing"
    report = _load_object(path, "release rehearsal")
    stored_digest = report.get("report_sha256")
    unsigned = dict(report)
    unsigned.pop("report_sha256", None)
    if not isinstance(stored_digest, str) or stored_digest != _digest(unsigned):
        raise M5Error("release rehearsal report hash does not match content")
    schema_version = report.get("schema_version")
    if schema_version not in {1, 2}:
        raise M5Error("release rehearsal report schema is unsupported")
    if report.get("status") != "pass":
        return False, "release rehearsal report is not passing"
    if report.get("previous_version") != release["previous_version"]:
        raise M5Error("release rehearsal previous version does not match policy")
    if report.get("candidate_version") != release["candidate_version"]:
        raise M5Error("release rehearsal candidate version does not match policy")
    rollback_report = report.get("rollback")
    restored_assets = report.get("restored_assets")
    if (
        not isinstance(rollback_report, dict)
        or rollback_report.get("status") != "pass"
        or isinstance(restored_assets, bool)
        or not isinstance(restored_assets, int)
        or restored_assets < 1
    ):
        raise M5Error("release rehearsal does not prove rollback restoration")
    if schema_version == 2 and report.get("migration_mode") == "rollback-before-install":
        legacy_rollback = report.get("legacy_rollback")
        fallback_restore = report.get("fallback_restore")
        if not isinstance(legacy_rollback, dict) or legacy_rollback.get("status") != "pass":
            raise M5Error("release rehearsal does not prove legacy rollback")
        if (
            not isinstance(fallback_restore, dict)
            or fallback_restore.get("status") != "pass"
            or fallback_restore.get("strategy") != "reinstall-previous-artifact"
            or isinstance(fallback_restore.get("installed"), bool)
            or not isinstance(fallback_restore.get("installed"), int)
            or fallback_restore.get("installed", 0) < 1
            or fallback_restore.get("cleanup_removed") != fallback_restore.get("installed")
        ):
            raise M5Error("release rehearsal does not prove previous artifact fallback restoration")
    if report.get("candidate_sha256") != release["candidate_sha256"]:
        raise M5Error("release rehearsal candidate checksum does not match policy")
    if report.get("candidate_manifest_sha256") != manifest_sha256:
        raise M5Error("release rehearsal candidate manifest digest does not match checkout")
    if not HEX64_RE.fullmatch(str(report.get("previous_sha256", ""))):
        raise M5Error("release rehearsal previous checksum is invalid")
    if policy.get("schema") == POLICY_SCHEMA_V2 and (
        report.get("previous_sha256") != release["previous_sha256"]
        or report.get("previous_manifest_sha256") != release["previous_manifest_sha256"]
        or report.get("release_continuity") is not True
    ):
        raise M5Error("release rehearsal does not preserve previous release continuity")
    return True, "pass"


def _campaign_tasks(path: Path) -> Tuple[List[Mapping[str, Any]], Dict[str, Mapping[str, Any]]]:
    tasks: List[Mapping[str, Any]] = []
    by_id: Dict[str, Mapping[str, Any]] = {}
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw.strip():
            continue
        try:
            task = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise M5Error("runtime campaign task JSON is invalid at line {}".format(line_number)) from exc
        task_id = task.get("id") if isinstance(task, dict) else None
        if not isinstance(task_id, str) or not ID_RE.fullmatch(task_id) or task_id in by_id:
            raise M5Error("runtime campaign task IDs are invalid or duplicated")
        tasks.append(task)
        by_id[task_id] = task
    if not tasks:
        raise M5Error("runtime campaign task evidence is empty")
    return tasks, by_id


def _validate_raw_campaign_record(
    record: Mapping[str, Any],
    runtime: str,
    task: Mapping[str, Any],
    condition: str,
    contract: Mapping[str, Any],
    provenance: Mapping[str, Any],
) -> float:
    expected_route = task.get("category") if condition == "baseline" else task.get("expected_skill")
    expected_safe = task.get("expected_safe")
    if not isinstance(expected_route, str) or not expected_route or not isinstance(expected_safe, bool):
        raise M5Error("runtime campaign task semantics are invalid")
    if record.get("expected_route") != expected_route or record.get("expected_safe") is not expected_safe:
        raise M5Error("runtime campaign expected outcome does not match task evidence")
    recorded_at = _parse_time(record.get("recorded_at"), "runtime campaign result recorded_at")
    if recorded_at > _utc_now():
        raise M5Error("runtime campaign result is future-dated")

    retry_limit = contract.get("retry_limit")
    max_claude_call_usd = contract.get("max_claude_call_usd")
    if isinstance(retry_limit, bool) or not isinstance(retry_limit, int) or retry_limit < 0 or retry_limit > 1:
        raise M5Error("runtime campaign retry_limit is invalid")
    if (
        isinstance(max_claude_call_usd, bool)
        or not isinstance(max_claude_call_usd, (int, float))
        or not math.isfinite(float(max_claude_call_usd))
        or not (0 < float(max_claude_call_usd) <= 0.25)
    ):
        raise M5Error("runtime campaign per-call budget is invalid")
    attempts = record.get("attempts")
    if not isinstance(attempts, list) or not attempts or len(attempts) > retry_limit + 1:
        raise M5Error("runtime campaign result attempts are invalid")
    total_cost = 0.0
    for index, attempt in enumerate(attempts, start=1):
        if not isinstance(attempt, dict) or attempt.get("attempt") != index:
            raise M5Error("runtime campaign attempt order is invalid")
        if (
            attempt.get("runtime_version") != provenance.get("runtime_version")
            or attempt.get("requested_model") != provenance.get("requested_model")
        ):
            raise M5Error("runtime campaign attempt provenance does not match frozen evidence")
        reported_models = attempt.get("reported_models")
        if not isinstance(reported_models, list) or not all(
            isinstance(model, str) and model for model in reported_models
        ):
            raise M5Error("runtime campaign reported_models are invalid")
        elapsed = attempt.get("elapsed_ms")
        if (
            isinstance(elapsed, bool)
            or not isinstance(elapsed, (int, float))
            or not math.isfinite(float(elapsed))
            or elapsed <= 0
        ):
            raise M5Error("runtime campaign elapsed_ms is invalid")
        usage = attempt.get("usage")
        if (
            not isinstance(usage, dict)
            or "total_tokens" not in usage
            or any(
                not isinstance(key, str)
                or not ID_RE.fullmatch(key)
                or isinstance(value, bool)
                or not isinstance(value, int)
                or value < 0
                for key, value in usage.items()
            )
        ):
            raise M5Error("runtime campaign token usage is invalid")
        error = attempt.get("error")
        if error is not None and (not isinstance(error, str) or not error):
            raise M5Error("runtime campaign attempt error is invalid")
        if runtime == "claude":
            cost = attempt.get("cost_usd")
            if (
                isinstance(cost, bool)
                or not isinstance(cost, (int, float))
                or not math.isfinite(float(cost))
                or cost < 0
                or cost > float(max_claude_call_usd)
                or attempt.get("cost_evidence") not in {"runtime-reported", "upper-bound-estimate"}
            ):
                raise M5Error("Claude campaign attempt cost evidence is invalid")
            total_cost += float(cost)
        elif attempt.get("cost_usd") is not None or attempt.get("cost_evidence") != "not-applicable":
            raise M5Error("non-Claude campaign attempt cost evidence is invalid")

    final = record.get("final")
    if not isinstance(final, dict) or final != attempts[-1]:
        raise M5Error("runtime campaign final result does not match the last attempt")
    error = final.get("error")
    route_ok = error is None and final.get("actual_skill") == expected_route
    safe_ok = error is None and final.get("actual_safe") == expected_safe
    status = "pass" if route_ok and safe_ok else "fail"
    if final.get("route_ok") is not route_ok or final.get("safe_ok") is not safe_ok or final.get("status") != status:
        raise M5Error("runtime campaign final summary is not derived from raw fields")
    return round(total_cost, 6)


def _validate_campaign_state(
    root: Path,
    campaign_policy: Mapping[str, Any],
    contract: Mapping[str, Any],
    report: Mapping[str, Any],
    provenance: Mapping[str, Mapping[str, Any]],
    tasks: Sequence[Mapping[str, Any]],
    tasks_by_id: Mapping[str, Mapping[str, Any]],
) -> Tuple[bool, str]:
    state_dir = _repo_path(root, campaign_policy.get("state_dir"), "runtime campaign state", must_exist=False)
    if not state_dir.is_dir():
        return False, "runtime campaign raw state is missing"
    report_path = _repo_path(root, campaign_policy.get("report"), "runtime campaign report")
    if report_path != (state_dir / "campaign-report.json").resolve():
        raise M5Error("runtime campaign report must be the state directory report")
    plan_path = state_dir / "campaign-plan.json"
    if not plan_path.is_file() or plan_path.is_symlink():
        return False, "runtime campaign frozen plan is missing"
    plan = _load_object(plan_path, "runtime campaign plan")
    if plan.get("schema") != "adk-runtime-eval-campaign-plan/v1" or plan.get("status") != "ready":
        raise M5Error("runtime campaign frozen plan is not a ready v1 plan")
    plan_digest = plan.get("plan_sha256")
    unsigned_plan = dict(plan)
    unsigned_plan.pop("plan_sha256", None)
    if not isinstance(plan_digest, str) or plan_digest != _digest(unsigned_plan):
        raise M5Error("runtime campaign plan hash does not match content")
    for field in (
        "campaign_id",
        "manifest_version",
        "manifest_sha256",
        "contract_sha256",
        "tasks_sha256",
        "task_count",
        "trials",
    ):
        if plan.get(field) != report.get(field):
            raise M5Error("runtime campaign plan and report differ on {}".format(field))

    results_root = state_dir / "results"
    if not results_root.is_dir():
        return False, "runtime campaign raw results are missing"
    paths = sorted(results_root.rglob("*.json"))
    expected_count = len(tasks) * 2 * len(campaign_policy["required_runtimes"]) * int(report["trials"])
    if len(paths) != expected_count:
        return False, "runtime campaign raw result count is incomplete"
    seen = set()
    record_digests: List[str] = []
    validated_cost = 0.0
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise M5Error("runtime campaign raw result must be a regular file")
        record = _load_object(path, "runtime campaign result")
        stored_digest = record.get("record_sha256")
        unsigned = dict(record)
        unsigned.pop("record_sha256", None)
        if not isinstance(stored_digest, str) or stored_digest != _digest(unsigned):
            raise M5Error("runtime campaign result hash does not match content")
        if record.get("schema") != "adk-runtime-eval-campaign-result/v1":
            raise M5Error("runtime campaign result schema is invalid")
        runtime = record.get("runtime")
        condition = record.get("condition")
        trial = record.get("trial")
        task_id = record.get("task_id")
        key = (runtime, condition, trial, task_id)
        if (
            runtime not in campaign_policy["required_runtimes"]
            or condition not in {"baseline", "adk"}
            or isinstance(trial, bool)
            or not isinstance(trial, int)
            or trial < 1
            or trial > int(report["trials"])
            or task_id not in tasks_by_id
            or key in seen
        ):
            raise M5Error("runtime campaign result identity is invalid or duplicated")
        expected_path = (
            results_root
            / str(runtime)
            / str(condition)
            / "trial-{:02d}".format(trial)
            / (str(task_id) + ".json")
        ).resolve()
        if path.resolve() != expected_path:
            raise M5Error("runtime campaign result path does not match its identity")
        seen.add(key)
        expected_fields = {
            "campaign_id": report["campaign_id"],
            "manifest_version": report["manifest_version"],
            "manifest_sha256": report["manifest_sha256"],
            "plan_sha256": plan_digest,
            "contract_sha256": report["contract_sha256"],
            "tasks_sha256": report["tasks_sha256"],
            "runtime_version": provenance[str(runtime)]["runtime_version"],
            "requested_model": provenance[str(runtime)]["requested_model"],
            "task_sha256": _digest(tasks_by_id[str(task_id)]),
        }
        if any(record.get(field) != value for field, value in expected_fields.items()):
            raise M5Error("runtime campaign result provenance does not match frozen evidence")
        validated_cost += _validate_raw_campaign_record(
            record,
            str(runtime),
            tasks_by_id[str(task_id)],
            str(condition),
            contract,
            provenance[str(runtime)],
        )
        record_digests.append(stored_digest)
    if len(seen) != expected_count:
        return False, "runtime campaign raw result matrix is incomplete"
    if report.get("evidence_sha256") != _digest(sorted(record_digests)):
        raise M5Error("runtime campaign evidence hash does not match raw results")
    report_cost = report.get("total_cost_usd")
    if not isinstance(report_cost, (int, float)) or isinstance(report_cost, bool) or round(float(report_cost), 6) != round(validated_cost, 6):
        raise M5Error("runtime campaign report cost does not match raw results")
    return True, "pass"


def _validate_campaign(root: Path, policy: Mapping[str, Any]) -> Tuple[bool, str, Optional[Mapping[str, Any]]]:
    campaign_policy = policy["runtime_campaign"]
    release_policy = policy["release"]
    path = _repo_path(root, campaign_policy.get("report"), "runtime campaign report", must_exist=False)
    if not path.is_file():
        return False, "runtime campaign report is missing", None
    report = _load_object(path, "runtime campaign report")
    stored_digest = report.get("report_sha256")
    unsigned = dict(report)
    unsigned.pop("report_sha256", None)
    if not isinstance(stored_digest, str) or stored_digest != _digest(unsigned):
        raise M5Error("runtime campaign report hash does not match content")
    if report.get("schema") != CAMPAIGN_SCHEMA or report.get("status") != "pass" or report.get("certified") is not True:
        return False, "runtime campaign is not certified", report
    if report.get("manifest_version") != release_policy["evaluation_version"]:
        return False, "runtime campaign version does not match evaluation_version", report
    manifest_path = _repo_path(root, campaign_policy.get("manifest"), "runtime campaign manifest")
    manifest = _load_object(manifest_path, "runtime campaign manifest")
    if manifest.get("version") != release_policy["evaluation_version"]:
        raise M5Error("runtime campaign manifest version does not match evaluation_version")
    if report.get("manifest_sha256") != _adk_manifest_digest(manifest):
        raise M5Error("runtime campaign manifest digest does not match evidence")
    contract_path = _repo_path(root, campaign_policy.get("contract"), "runtime campaign contract")
    contract = _load_object(contract_path, "runtime campaign contract")
    if report.get("contract_sha256") != _digest(contract):
        raise M5Error("runtime campaign contract digest does not match evidence")
    if (
        contract.get("runtimes") != campaign_policy["required_runtimes"]
        or contract.get("conditions") != ["baseline", "adk"]
        or contract.get("runtime_models") != campaign_policy["required_models"]
        or contract.get("trials") != report.get("trials")
    ):
        raise M5Error("runtime campaign contract does not match policy or report")
    contract_budget = contract.get("max_budget_usd")
    if (
        isinstance(contract_budget, bool)
        or not isinstance(contract_budget, (int, float))
        or float(contract_budget) > float(campaign_policy["max_budget_usd"])
    ):
        raise M5Error("runtime campaign contract budget exceeds policy")
    if report.get("max_budget_usd") != contract_budget or report.get("thresholds") != contract.get("thresholds"):
        raise M5Error("runtime campaign report does not preserve contract budget and thresholds")
    if report.get("failures") != []:
        return False, "runtime campaign report contains failures", report
    tasks_path = _repo_path(root, campaign_policy.get("tasks"), "runtime campaign tasks")
    tasks, tasks_by_id = _campaign_tasks(tasks_path)
    if report.get("tasks_sha256") != _sha256_file(tasks_path):
        raise M5Error("runtime campaign tasks digest does not match evidence")
    if report.get("task_count") != len(tasks):
        raise M5Error("runtime campaign task count does not match task evidence")
    task_count = report.get("task_count")
    trials = report.get("trials")
    if isinstance(task_count, bool) or not isinstance(task_count, int) or task_count < campaign_policy["minimum_tasks"]:
        return False, "runtime campaign task count is below policy", report
    if isinstance(trials, bool) or not isinstance(trials, int) or trials < campaign_policy["minimum_trials"]:
        return False, "runtime campaign trial count is below policy", report
    expected = task_count * 2 * len(campaign_policy["required_runtimes"]) * trials
    if report.get("expected_results") != expected or report.get("validated_results") != expected:
        return False, "runtime campaign evidence is incomplete", report
    provenance = report.get("runtime_provenance")
    if not isinstance(provenance, list):
        return False, "runtime campaign provenance is missing", report
    actual = {
        item.get("runtime"): item
        for item in provenance
        if isinstance(item, dict) and isinstance(item.get("runtime"), str)
    }
    if len(provenance) != len(actual) or set(actual) != set(campaign_policy["required_runtimes"]):
        return False, "runtime campaign provenance does not cover required runtimes", report
    for runtime in campaign_policy["required_runtimes"]:
        entry = actual[runtime]
        if entry.get("requested_model") != campaign_policy["required_models"][runtime]:
            return False, "runtime campaign model does not match policy", report
        if not isinstance(entry.get("runtime_version"), str) or not entry["runtime_version"]:
            return False, "runtime campaign CLI version is missing", report
    gates = report.get("gates")
    if not isinstance(gates, dict) or not gates or not all(value is True for value in gates.values()):
        return False, "runtime campaign gates are not all passing", report
    if not HEX64_RE.fullmatch(str(report.get("evidence_sha256", ""))):
        return False, "runtime campaign evidence hash is invalid", report
    total_cost = report.get("total_cost_usd")
    if (
        isinstance(total_cost, bool)
        or not isinstance(total_cost, (int, float))
        or not math.isfinite(float(total_cost))
        or total_cost < 0
        or total_cost > float(campaign_policy["max_budget_usd"])
    ):
        return False, "runtime campaign cost exceeds policy", report
    state_ok, state_message = _validate_campaign_state(
        root,
        campaign_policy,
        contract,
        report,
        actual,
        tasks,
        tasks_by_id,
    )
    return state_ok, state_message, report


def _validate_repository_campaign(
    root: Path, policy: Mapping[str, Any]
) -> Tuple[bool, str, Optional[Mapping[str, Any]]]:
    campaign = policy["repository_runtime_campaign"]
    report_path = _repo_path(root, campaign.get("report"), "repository runtime report", must_exist=False)
    if not report_path.is_file():
        return False, "repository runtime report is missing", None
    campaign_root = _repo_path(root, campaign.get("root"), "repository runtime root")
    if not campaign_root.is_dir():
        raise M5Error("repository runtime root must be a directory")
    contract_path = _repo_path(root, campaign.get("contract"), "repository runtime contract")
    if not _inside(contract_path, campaign_root) or not _inside(report_path, campaign_root):
        raise M5Error("repository runtime contract and report must stay inside the declared root")
    source_root = Path(__file__).resolve().parents[2] / "agent-dev-kit" / "src"
    if not source_root.is_dir():
        raise M5Error("repository runtime certifier source is missing")
    source_value = str(source_root)
    if source_value not in sys.path:
        sys.path.insert(0, source_value)
    try:
        from agent_dev_kit import model as repository_model
        from agent_dev_kit import repository_evaluation as repository_evaluation_module
    except (ImportError, OSError) as exc:
        raise M5Error("cannot load repository runtime certifier") from exc
    module_paths = []
    for module in (repository_model, repository_evaluation_module):
        module_file = getattr(module, "__file__", None)
        if not isinstance(module_file, str):
            raise M5Error("repository runtime certifier module provenance is missing")
        module_paths.append(Path(module_file).resolve())
    if not all(_inside(module_path, source_root) for module_path in module_paths):
        raise M5Error("repository runtime certifier module provenance is outside the trusted source root")
    RepositoryManifestError = repository_model.ManifestError
    certify_repository_report = repository_evaluation_module.certify_repository_report
    try:
        certification = certify_repository_report(
            SimpleNamespace(root=campaign_root, version=policy["release"]["evaluation_version"]),
            contract_path,
            report_path,
        )
    except (RepositoryManifestError, OSError, ValueError) as exc:
        raise M5Error("repository runtime evidence is invalid: {}".format(exc)) from exc
    if certification.get("status") != "pass":
        return False, "repository runtime campaign is not certified", certification
    required_runtimes = campaign["required_runtimes"]
    if set(certification.get("runtime_metrics", {})) != set(required_runtimes):
        raise M5Error("repository runtime certification does not cover required runtimes")
    if int(certification.get("task_count", 0)) < int(campaign["minimum_tasks"]):
        return False, "repository runtime task count is below policy", certification
    report = _load_object(report_path, "repository runtime report")
    if report.get("runtimes") != required_runtimes:
        raise M5Error("repository runtime report runtimes do not match policy")
    if int(report.get("trials", 0)) < int(campaign["minimum_trials"]):
        return False, "repository runtime trial count is below policy", certification
    contract = _load_object(contract_path, "repository runtime contract")
    tasks_path = (campaign_root / str(contract.get("tasks", ""))).resolve()
    if not _inside(tasks_path, campaign_root) or not tasks_path.is_file():
        raise M5Error("repository runtime tasks are missing or outside the declared root")
    try:
        task_values = [json.loads(line) for line in tasks_path.read_text(encoding="utf-8").splitlines() if line]
    except (OSError, json.JSONDecodeError) as exc:
        raise M5Error("repository runtime task evidence is invalid") from exc
    real_tasks = [
        task
        for task in task_values
        if isinstance(task, dict)
        and task.get("source_kind") == "approved-real-repository"
        and task.get("execution_status") == "owner-approved"
    ]
    if len(real_tasks) < int(campaign["minimum_real_tasks"]):
        return False, "repository runtime campaign lacks approved real-repository tasks", certification
    results = report.get("results", [])
    total_cost = sum(
        float(item.get("usage", {}).get("cost_usd", 0))
        for item in results
        if isinstance(item, dict) and isinstance(item.get("usage"), dict)
    )
    if not math.isfinite(total_cost) or total_cost > float(campaign["max_budget_usd"]):
        return False, "repository runtime campaign cost exceeds policy", certification
    return True, "repository runtime campaign passed", certification


def _field_progress(
    policy: Mapping[str, Any],
    repositories: Mapping[str, Mapping[str, Any]],
    operators: Mapping[str, Mapping[str, Any]],
    pilots: Mapping[str, Mapping[str, Any]],
    events: Sequence[Mapping[str, Any]],
) -> Tuple[Dict[str, Any], List[Dict[str, str]]]:
    field_policy = policy["field_certification"]
    field_events = [event for event in events if event["evidence_layer"] == "field"]
    active_pilots = [pilot for pilot in pilots.values() if pilot["status"] != "withdrawn"]
    active_ids = {pilot["id"] for pilot in active_pilots}
    evidenced_repositories = {
        event["repository_id"]
        for event in field_events
        if event["pilot_id"] in active_ids and repositories[event["repository_id"]]["real_software"] is True
    }
    independent_repositories = {
        repository_id
        for repository_id in evidenced_repositories
        if repositories[repository_id]["classification"] == "independent"
    }
    human_operators = {
        event["operator_id"]
        for event in field_events
        if operators[event["operator_id"]]["operator_type"] == "human"
    }
    required_types = list(field_policy["required_event_types"])
    required_metrics = field_policy["required_metrics"]
    metric_contracts = field_policy["metric_contracts"]
    qualifying_pilots: List[str] = []
    best_span_days = 0
    best_independent_operator_count = 0
    independent_reviewer_observed = False
    missing_types = set(required_types)
    for pilot in pilots.values():
        if pilot["status"] != "completed" or pilot["environment_class"] != "independent":
            continue
        independent_members = [
            repository_id
            for repository_id in pilot["repositories"]
            if repositories[repository_id]["classification"] == "independent"
        ]
        if not independent_members:
            continue
        pilot_events = [
            event for event in field_events if event["pilot_id"] == pilot["id"]
        ]
        if not pilot_events:
            continue
        start = _parse_time(pilot["started_at"], "pilot started_at")
        end = _parse_time(pilot["ended_at"], "pilot ended_at")
        ledger_days = (end.date() - start.date()).days
        observed_times = sorted(_parse_time(event["occurred_at"], "event occurred_at") for event in pilot_events)
        observed_days = (observed_times[-1].date() - observed_times[0].date()).days
        best_span_days = max(best_span_days, min(ledger_days, observed_days))
        event_types = {event["event_type"] for event in pilot_events}
        pilot_humans = {
            event["operator_id"]
            for event in pilot_events
            if operators[event["operator_id"]]["operator_type"] == "human"
        }
        best_independent_operator_count = max(best_independent_operator_count, len(pilot_humans))
        reviewer_present = any(operators[value].get("independent_reviewer") is True for value in pilot_humans)
        reviewer_reviewed = any(
            event["event_type"] == "pilot_reviewed"
            and operators[event["operator_id"]].get("independent_reviewer") is True
            for event in pilot_events
        )
        independent_reviewer_observed = independent_reviewer_observed or reviewer_reviewed
        metric_complete = True
        for event in pilot_events:
            event_type = event["event_type"]
            for field in required_metrics.get(event_type, []):
                if field not in event["metrics"] or not _metric_matches(
                    event["metrics"][field],
                    metric_contracts[event_type][field],
                    policy["release"],
                ):
                    metric_complete = False
        selection_events = [event for event in pilot_events if event["event_type"] == "task_selection_recorded"]
        baseline_events = [event for event in pilot_events if event["event_type"] == "human_baseline_recorded"]
        workload_events = [event for event in pilot_events if event["event_type"] == "workload_executed"]
        semantic_complete = len(selection_events) == 1 and len(baseline_events) == 1 and bool(workload_events)
        if semantic_complete:
            selection_event = selection_events[0]
            baseline_event = baseline_events[0]
            selection = selection_event["metrics"]
            baseline_metrics = baseline_event["metrics"]
            selection_time = _parse_time(selection_event["occurred_at"], "task selection occurred_at")
            baseline_time = _parse_time(baseline_event["occurred_at"], "human baseline occurred_at")
            first_workload_time = min(
                _parse_time(event["occurred_at"], "workload occurred_at") for event in workload_events
            )
            if not selection_time <= baseline_time <= first_workload_time:
                semantic_complete = False
            if (
                selection.get("accepted_task_count", 0) + selection.get("rejected_task_count", 0)
                != selection.get("preregistered_task_count")
            ):
                semantic_complete = False
            for workload in workload_events:
                values = workload["metrics"]
                if (
                    values.get("task_count") != selection.get("accepted_task_count")
                    or values.get("preregistered_task_count") != selection.get("preregistered_task_count")
                    or values.get("rejected_task_count") != selection.get("rejected_task_count")
                    or baseline_metrics.get("baseline_task_count") != values.get("task_count")
                    or values.get("human_active_minutes", 0) > values.get("wall_clock_minutes", 0)
                    or values.get("agent_active_minutes", 0)
                    > values.get("wall_clock_minutes", 0) * values.get("concurrent_agent_peak", 0)
                ):
                    semantic_complete = False
        metric_complete = metric_complete and semantic_complete
        missing = set(required_types).difference(event_types)
        if (
            ledger_days >= int(field_policy["minimum_calendar_days"])
            and observed_days >= int(field_policy["minimum_calendar_days"])
            and not missing
            and metric_complete
            and len(pilot_humans) >= int(field_policy["minimum_human_operators"])
            and reviewer_present
            and reviewer_reviewed
        ):
            qualifying_pilots.append(str(pilot["id"]))
            missing_types.clear()
        elif len(missing) < len(missing_types):
            missing_types = missing

    gaps: List[Dict[str, str]] = []
    if len(evidenced_repositories) < int(field_policy["minimum_real_repositories"]):
        gaps.append({"id": "real_repository_count", "message": "real repository field evidence is below policy"})
    if len(independent_repositories) < int(field_policy["minimum_independent_repositories"]):
        gaps.append({"id": "independent_repository", "message": "no independently operated software repository has field evidence"})
    if (
        best_independent_operator_count < int(field_policy["minimum_human_operators"])
        or not independent_reviewer_observed
    ):
        gaps.append(
            {
                "id": "operator_count",
                "message": "a qualifying independent pilot lacks a second human operator or reviewer-authored review event",
            }
        )
    if not qualifying_pilots:
        gaps.append({"id": "pilot_duration", "message": "no completed independent pilot has 30-day ledger and observed spans"})
        gaps.append(
            {
                "id": "required_field_events",
                "message": "independent pilot is missing required field event or metric evidence: {}".format(
                    ",".join(sorted(missing_types)) or "metric evidence"
                ),
            }
        )
    progress = {
        "event_count": len(events),
        "field_event_count": len(field_events),
        "real_repositories_with_field_evidence": len(evidenced_repositories),
        "independent_repositories_with_field_evidence": len(independent_repositories),
        "human_operators_with_field_evidence": len(human_operators),
        "best_independent_pilot_human_operators": best_independent_operator_count,
        "independent_reviewer_observed": independent_reviewer_observed,
        "best_independent_pilot_observed_days": best_span_days,
        "qualifying_pilots": sorted(qualifying_pilots),
        "event_chain_head": events[-1]["event_hash"] if events else ZERO_HASH,
    }
    return progress, gaps


def assess(root: Path, as_of: Optional[datetime] = None) -> Dict[str, Any]:
    root = root.resolve()
    as_of = (as_of or _utc_now()).astimezone(timezone.utc).replace(microsecond=0)
    result: Dict[str, Any] = {
        "schema": STATUS_SCHEMA,
        "as_of": _format_time(as_of),
        "scope": "software-only",
        "integrity_status": "pass",
        "readiness_status": "not-ready",
        "eligibility_status": "blocked",
        "certification_status": "blocked",
        "software_m5_certified": False,
        "readiness_failures": [],
        "certification_gaps": [],
    }
    try:
        policy = _load_object(root / "manifests/software_m5_policy.json", "software M5 policy")
        _validate_policy(policy)
        ledger = _load_object(root / "manifests/software_m5_pilot_ledger.json", "software M5 pilot ledger")
        ledger["_root"] = str(root)
        repositories, operators, pilots = _validate_ledger(ledger, policy)
        event_log = _repo_path(root, ledger.get("event_log"), "software M5 event log")
        events = _read_events(root, event_log, as_of)
        _validate_event_references(events, repositories, operators, pilots)
        release_ok, release_message = _validate_release(root, policy)
        campaign_ok, campaign_message, _ = _validate_campaign(root, policy)
        repository_campaign_ok, repository_campaign_message, _ = _validate_repository_campaign(root, policy)
        progress, field_gaps = _field_progress(policy, repositories, operators, pilots, events)
        active_self = [
            pilot for pilot in pilots.values() if pilot["status"] == "active" and pilot["environment_class"] == "self"
        ]
        self_start = any(
            event["event_type"] == "pilot_started"
            and event["evidence_layer"] == "field"
            and event["pilot_id"] in {pilot["id"] for pilot in active_self}
            for event in events
        )
        if not release_ok:
            result["readiness_failures"].append({"id": "release_rehearsal", "message": release_message})
        if not active_self:
            result["readiness_failures"].append({"id": "self_pilot", "message": "no active self pilot is registered"})
        if not self_start:
            result["readiness_failures"].append({"id": "pilot_start_event", "message": "self pilot has no field pilot_started event"})
        if not campaign_ok:
            result["certification_gaps"].append({"id": "runtime_campaign", "message": campaign_message})
        if not repository_campaign_ok:
            result["certification_gaps"].append(
                {"id": "repository_runtime_campaign", "message": repository_campaign_message}
            )
        result["certification_gaps"].extend(field_gaps)
        if policy["release"]["candidate_version"] != policy["release"]["final_version"]:
            result["certification_gaps"].append(
                {
                    "id": "final_version",
                    "message": "final {} promotion is blocked until campaign and field eligibility pass".format(
                        policy["release"]["final_version"]
                    ),
                }
            )
        result["candidate_version"] = policy["release"]["candidate_version"]
        result["evaluation_version"] = policy["release"]["evaluation_version"]
        result["final_version"] = policy["release"]["final_version"]
        result["release_rehearsal"] = "pass" if release_ok else "missing"
        result["runtime_campaign"] = "pass" if campaign_ok else "blocked"
        result["repository_runtime_campaign"] = "pass" if repository_campaign_ok else "blocked"
        result["field_progress"] = progress
        if not result["readiness_failures"]:
            result["readiness_status"] = "m5-ready"
        non_version_gaps = [gap for gap in result["certification_gaps"] if gap["id"] != "final_version"]
        if not non_version_gaps and result["readiness_status"] == "m5-ready":
            result["eligibility_status"] = "eligible-for-final"
        if not result["certification_gaps"] and result["readiness_status"] == "m5-ready":
            result["certification_status"] = "pass"
            result["software_m5_certified"] = True
    except M5Error as exc:
        result["integrity_status"] = "fail"
        result["readiness_failures"].append({"id": "evidence_integrity", "message": str(exc)})
    result["blocker_ids"] = sorted(
        {item["id"] for item in result["readiness_failures"] + result["certification_gaps"]}
    )
    result["status_sha256"] = _digest(result)
    return result


def _declaration_failures(root: Path, result: Mapping[str, Any]) -> List[Dict[str, str]]:
    failures: List[Dict[str, str]] = []
    try:
        scorecard = _load_object(root / "manifests/product_maturity_scorecard.json", "product maturity scorecard")
    except M5Error as exc:
        return [{"id": "scorecard", "message": str(exc)}]
    declared = scorecard.get("software_m5")
    if not isinstance(declared, dict):
        return [{"id": "scorecard", "message": "product maturity scorecard is missing software_m5"}]
    expected = {
        "readiness_status": result.get("readiness_status"),
        "eligibility_status": result.get("eligibility_status"),
        "certification_status": result.get("certification_status"),
        "certified": result.get("software_m5_certified"),
        "candidate_version": result.get("candidate_version"),
        "final_version": result.get("final_version"),
        "blocking_gates": result.get("blocker_ids"),
    }
    for field, value in expected.items():
        if declared.get(field) != value:
            failures.append(
                {"id": "scorecard_{}".format(field), "message": "scorecard software_m5.{} is stale".format(field)}
            )
    overall = scorecard.get("overall")
    if not isinstance(overall, dict):
        failures.append({"id": "scorecard_overall", "message": "scorecard overall is missing"})
    else:
        expected_field_status = "field_verified" if result.get("software_m5_certified") else "self_pilot_active"
        if overall.get("field_status") != expected_field_status:
            failures.append({"id": "scorecard_field_status", "message": "scorecard field_status is stale"})
        if overall.get("terminal_mature") is not bool(result.get("software_m5_certified")):
            failures.append({"id": "scorecard_terminal_mature", "message": "scorecard terminal_mature is stale"})
        if result.get("software_m5_certified") is True and overall.get("level") != "M5":
            failures.append({"id": "scorecard_level", "message": "certified software M5 must declare overall level M5"})
        if result.get("software_m5_certified") is not True and overall.get("level") == "M5":
            failures.append({"id": "scorecard_level", "message": "overall level M5 requires certified software M5"})
    return failures


def check(root: Path, as_of: Optional[datetime] = None) -> Dict[str, Any]:
    result = assess(root, as_of)
    declaration_failures = _declaration_failures(root.resolve(), result)
    result["declaration_failures"] = declaration_failures
    result["declaration_status"] = "pass" if not declaration_failures else "fail"
    result.pop("status_sha256", None)
    result["status_sha256"] = _digest(result)
    return result


def append_event(
    root: Path,
    event_values: Mapping[str, Any],
    recorded_at: Optional[datetime] = None,
) -> Dict[str, Any]:
    root = root.resolve()
    policy = _load_object(root / "manifests/software_m5_policy.json", "software M5 policy")
    _validate_policy(policy)
    ledger = _load_object(root / "manifests/software_m5_pilot_ledger.json", "software M5 pilot ledger")
    ledger["_root"] = str(root)
    repositories, operators, pilots = _validate_ledger(ledger, policy)
    event_log = _repo_path(root, ledger.get("event_log"), "software M5 event log")
    lock_path = event_log.with_name(event_log.name + ".lock")
    recorded = (recorded_at or _utc_now()).astimezone(timezone.utc).replace(microsecond=0)
    if lock_path.is_symlink():
        raise M5Error("software M5 event lock must not be a symlink")
    flags = os.O_CREAT | os.O_RDWR
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        lock_fd = os.open(str(lock_path), flags, 0o600)
    except OSError as exc:
        raise M5Error("cannot open software M5 event lock") from exc
    try:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise M5Error("software M5 event log is locked by another writer") from exc
        events = _read_events(root, event_log, recorded)
        _validate_event_references(events, repositories, operators, pilots)
        event_id = event_values.get("event_id")
        if any(event["event_id"] == event_id for event in events):
            raise M5Error("event_id already exists")
        event = {
            "schema": EVENT_SCHEMA,
            "sequence": len(events) + 1,
            "event_id": event_id,
            "pilot_id": event_values.get("pilot_id"),
            "occurred_at": event_values.get("occurred_at"),
            "recorded_at": _format_time(recorded),
            "event_type": event_values.get("event_type"),
            "evidence_layer": event_values.get("evidence_layer"),
            "repository_id": event_values.get("repository_id"),
            "operator_id": event_values.get("operator_id"),
            "summary": event_values.get("summary"),
            "evidence": event_values.get("evidence"),
            "evidence_sha256": {
                value: _evidence_digest(root, value)
                for value in event_values.get("evidence", [])
            }
            if isinstance(event_values.get("evidence"), list)
            else {},
            "metrics": event_values.get("metrics", {}),
            "previous_hash": events[-1]["event_hash"] if events else ZERO_HASH,
        }
        event["event_hash"] = _digest(event)
        candidate = events + [event]
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            prefix="." + event_log.name + ".",
            suffix=".candidate",
            dir=str(event_log.parent),
            delete=False,
        ) as temp:
            temp_path = Path(temp.name)
            temp.write(
                "".join(
                    json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n"
                    for item in candidate
                )
            )
            temp.flush()
            os.fsync(temp.fileno())
        try:
            validated = _read_events(root, temp_path, recorded)
            _validate_event_references(validated, repositories, operators, pilots)
            with event_log.open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")
                stream.flush()
                os.fsync(stream.fileno())
        finally:
            temp_path.unlink(missing_ok=True)
        return event
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def _parse_metric(value: str) -> Tuple[str, Any]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("metric must use key=value")
    key, raw = value.split("=", 1)
    if not ID_RE.fullmatch(key):
        raise argparse.ArgumentTypeError("metric key is invalid")
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = raw
    if isinstance(parsed, (dict, list)) or parsed is None:
        raise argparse.ArgumentTypeError("metric value must be scalar")
    return key, parsed


def _write_output(path: Optional[str], value: Mapping[str, Any], compact: bool = False) -> None:
    content = (
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n"
        if compact
        else json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    )
    if path:
        output = Path(path).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        temp = output.with_name(output.name + ".tmp")
        temp.write_text(content, encoding="utf-8")
        temp.replace(output)
    else:
        print(content, end="")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="software-m5.sh")
    parser.add_argument("--root", default=str(Path.cwd()))
    sub = parser.add_subparsers(dest="command", required=True)
    commands = {}
    for name in ("status", "check", "certify"):
        command = sub.add_parser(name)
        commands[name] = command
        command.add_argument("--as-of")
        command.add_argument("--output")
        command.add_argument("--summary-json", action="store_true")
    commands["check"].add_argument("--allow-not-ready", action="store_true")
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
    append.add_argument("--output")
    append.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root)
    try:
        if args.command == "append":
            metrics = dict(args.metric)
            if len(metrics) != len(args.metric):
                raise M5Error("duplicate metric keys are not allowed")
            value = append_event(
                root,
                {
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
                },
            )
            _write_output(args.output, value, args.summary_json)
            return 0
        as_of = _parse_time(args.as_of, "--as-of") if args.as_of else None
        value = check(root, as_of) if args.command in {"check", "certify"} else assess(root, as_of)
        _write_output(args.output, value, args.summary_json)
        if args.command == "certify":
            return 0 if (
                value.get("software_m5_certified") is True
                and value.get("declaration_status") == "pass"
            ) else 1
        if args.command == "check":
            return 0 if (
                value.get("integrity_status") == "pass"
                and value.get("declaration_status") == "pass"
                and (
                    value.get("readiness_status") == "m5-ready"
                    or args.allow_not_ready and value.get("readiness_status") == "not-ready"
                )
            ) else 1
        return 0 if value.get("integrity_status") == "pass" else 1
    except M5Error as exc:
        error = {"schema": STATUS_SCHEMA, "status": "fail", "error": str(exc)}
        _write_output(getattr(args, "output", None), error, getattr(args, "summary_json", False))
        return 2


if __name__ == "__main__":
    sys.exit(main())
