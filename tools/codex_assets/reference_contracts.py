"""Owned registration/removal lifecycle contracts and artifact boundaries."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Mapping, Tuple

from .intake_io import (
    IntakeError, _load_json, _reject_symlink_chain, _resolve_path,
    _sha256_file,
)

PLAN_SCHEMA = "reference-repository-onboarding/v1"
LIFECYCLE_POLICY_SCHEMA = "reference-repository-lifecycle-policy/v1"
REGISTRATION_POLICY_SCHEMA = "reference-repository-registration-policy/v1"
REMOVAL_PLAN_SCHEMA = "reference-repository-removal/v1"
REMOVAL_POLICY_SCHEMA = "reference-repository-removal-policy/v1"
REQUIRED_GATES = [
    "candidate_contract_gate",
    "owner_decision_gate",
    "repository_metadata_gate",
    "source_risk_gate",
    "analysis_report_gate",
    "duplicate_check_gate",
    "security_review_gate",
    "phase_gate",
    "registry_conflict_gate",
    "target_path_gate",
    "materialization_gate",
    "apply_workspace_gate",
    "rollback_plan_gate",
]
REQUIRED_ARTIFACTS = [
    "candidate_ledger",
    "decision_ledger",
    "analysis_report",
    "duplicate_check",
    "security_review",
]
ALLOWED_APPLY_TARGETS = {
    ".gitmodules",
    "subrepos/registry.csv",
    "subrepos/adoption-matrix.md",
    "subrepos/adoption-matrix.jsonl",
    "manifests/subrepo_lifecycle.json",
}
BLOCKING_RISKS = {"archived-source", "source-rejected", "provider-degraded"}
REACTIVATABLE_LIFECYCLE_STATES = {"archive-only", "disabled", "removed", "watch"}
REMOVAL_REQUIRED_GATES = [
    "lifecycle_state_gate",
    "protected_repo_gate",
    "active_core_gate",
    "adoption_decision_gate",
    "evidence_dependency_gate",
    "dirty_baseline_gate",
    "rollback_plan_gate",
    "precheck_gate",
    "postcheck_gate",
]
REMOVAL_ELIGIBLE_STATES = {"archive-only", "disabled"}
REMOVAL_ARTIFACTS = {
    "adoption_decision",
    "evidence_dependency_scan",
    "dirty_baseline_review",
    "rollback_plan",
}
REMOVAL_CHANGES = {"gitmodules", "gitlink", "registry", "dirty_baseline", "lifecycle", "docs_reports"}
REMOVAL_ROLLBACK_FILES = {
    ".gitmodules",
    "subrepos/registry.csv",
    "subrepos/dirty-baseline.tsv",
    "manifests/subrepo_lifecycle.json",
}


def _load_lifecycle_policy(root: Path) -> Tuple[Mapping[str, Any], Path]:
    path = root / "manifests/reference_repository_lifecycle_policy.json"
    value = _load_json(path, 4194304, "reference repository lifecycle policy")
    if not isinstance(value, dict) or value.get("schema") != LIFECYCLE_POLICY_SCHEMA:
        raise IntakeError("reference repository lifecycle policy must use the v1 schema")
    if set(value) != {"schema", "last_updated", "registration", "removal"}:
        raise IntakeError("reference repository lifecycle policy fields drifted")
    return value, path


def _load_registration_policy(root: Path) -> Tuple[Mapping[str, Any], Path]:
    lifecycle, path = _load_lifecycle_policy(root)
    value = lifecycle.get("registration")
    if not isinstance(value, dict):
        raise IntakeError("registration policy root must be an object")
    if value.get("schema") != REGISTRATION_POLICY_SCHEMA:
        raise IntakeError("registration policy must use the v1 hard-switch schema")
    if value.get("status") != "gated-registration" or value.get("default_mode") != "dry-run":
        raise IntakeError("registration policy must remain gated and dry-run by default")
    if value.get("candidate_schema") != "external-practice-candidate/v1":
        raise IntakeError("registration policy candidate schema drifted")
    if value.get("decision_schema") != "external-practice-decision/v1":
        raise IntakeError("registration policy decision schema drifted")
    if value.get("required_gates") != REQUIRED_GATES:
        raise IntakeError("registration policy required_gates drifted")
    rules = value.get("rules")
    required_rules = {
        "apply_requires_explicit_flag",
        "apply_requires_owner_decision",
        "apply_requires_materialization_mode",
        "apply_requires_clean_workspace",
        "apply_requires_clean_source_origin_and_head",
        "apply_metadata_transaction_must_rollback",
        "apply_must_not_modify_agent_dev_kit",
        "apply_must_not_run_network_discovery",
        "apply_must_generate_rollback_evidence",
        "collector_or_curator_must_not_be_decision_owner",
        "legacy_candidate_schema_must_be_rejected",
        "reactivation_requires_disabled_registry_and_inactive_lifecycle",
    }
    if not isinstance(rules, dict) or set(rules) != required_rules or not all(item is True for item in rules.values()):
        raise IntakeError("registration policy rules weaken the v1 boundary")
    return value, path


def _load_removal_policy(root: Path) -> Tuple[Mapping[str, Any], Path]:
    lifecycle, path = _load_lifecycle_policy(root)
    value = lifecycle.get("removal")
    if not isinstance(value, dict) or value.get("schema") != REMOVAL_POLICY_SCHEMA:
        raise IntakeError("reference repository removal policy must use the v1 schema")
    if value.get("status") != "gated-removal" or value.get("default_mode") != "dry-run":
        raise IntakeError("reference repository removal policy must remain gated and dry-run")
    if value.get("required_gates") != REMOVAL_REQUIRED_GATES:
        raise IntakeError("reference repository removal gates drifted")
    if set(value.get("eligible_lifecycle_states") or []) != REMOVAL_ELIGIBLE_STATES:
        raise IntakeError("reference repository removal states drifted")
    if "agent-dev-kit" not in set(value.get("protected_repositories") or []):
        raise IntakeError("reference repository removal policy must protect agent-dev-kit")
    if set(value.get("blocked_lifecycle_states") or []) != {"active-core", "active-reference", "watch"}:
        raise IntakeError("reference repository blocked states drifted")
    required_rules = {
        "plan_requires_hashed_artifacts",
        "default_must_be_dry_run",
        "apply_requires_explicit_flag",
        "apply_requires_confirmed_plan",
        "apply_must_not_touch_agent_dev_kit",
        "apply_must_not_delete_without_rollback",
        "apply_must_run_precheck_and_postcheck",
        "dirty_baseline_update_must_be_explicit",
    }
    rules = value.get("rules")
    if not isinstance(rules, dict) or set(rules) != required_rules or not all(item is True for item in rules.values()):
        raise IntakeError("reference repository removal rules weaken the boundary")
    expected_targets = {
        ".gitmodules",
        "subrepos/registry.csv",
        "subrepos/dirty-baseline.tsv",
        "manifests/subrepo_lifecycle.json",
        "docs/llm-agent-maintenance-guide.md",
        "docs/runbooks/reference-repository-lifecycle.md",
        "reports/reference-repository-removal-*.json",
        "reports/reference-repository-removal-*.md",
    }
    if set(value.get("allowed_apply_targets") or []) != expected_targets:
        raise IntakeError("reference repository removal apply targets drifted")
    return value, path


def _artifact(root: Path, value: str, label: str) -> Tuple[Path, str, str]:
    path = _resolve_path(root, value, label)
    _reject_symlink_chain(path)
    if not path.is_file():
        raise IntakeError("{} must be a regular non-symlink file".format(label))
    try:
        ref = path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError as exc:
        raise IntakeError("{} must be inside the repository for durable review".format(label)) from exc
    if path.stat().st_size < 16:
        raise IntakeError("{} is too small to be durable review evidence".format(label))
    return path, ref, _sha256_file(path)


def _safe_component(value: str, label: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,99}", value):
        raise IntakeError("{} is not a safe repository component".format(label))
    return value
