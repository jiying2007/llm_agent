#!/usr/bin/env python3
"""Post-decision reference repository registration with a v1 hard boundary."""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import subprocess
import sys
import urllib.parse
from datetime import date
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

from .practice_intake import (
    IntakeError,
    _canonical_url,
    _clean_text,
    _json_bytes,
    _load_json,
    _load_jsonl,
    _load_policy,
    _parse_date,
    _reject_symlink_chain,
    _relative_ref,
    _resolve_path,
    _sha256_file,
    _transactional_write,
    _validate_candidate,
    _validate_decision,
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


def _safe_target(value: str) -> str:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise IntakeError("target path must be a safe repository-relative path")
    for part in path.parts:
        _safe_component(part, "target path component")
    return path.as_posix()


def _safe_branch(value: str) -> str:
    branch = _clean_text(value, "branch", 200, allow_empty=False)
    if (
        branch.startswith("-")
        or branch.endswith((".", "/"))
        or ".." in branch
        or "//" in branch
        or "@{" in branch
        or any(character in "~^:?*[\\]" or ord(character) <= 32 or ord(character) == 127 for character in branch)
    ):
        raise IntakeError("branch is not a safe Git branch name")
    return branch


def _run_git(path: Path, arguments: Sequence[str], label: str) -> str:
    completed = subprocess.run(
        ["rtk", "proxy", "git", "-C", str(path), *arguments],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise IntakeError("{} failed".format(label))
    return completed.stdout.strip()


def _workspace_clean(root: Path) -> bool:
    try:
        return not _run_git(root, ["status", "--porcelain", "--untracked-files=all"], "workspace status")
    except IntakeError:
        return False


def _source_snapshot(source: Path, candidate_url: str) -> Mapping[str, Any]:
    source = source.resolve()
    if not source.is_dir():
        raise IntakeError("local-submodule requires an existing reviewed source directory")
    if _run_git(source, ["rev-parse", "--is-inside-work-tree"], "source repository check") != "true":
        raise IntakeError("local-submodule source is not a Git worktree")
    if _run_git(source, ["status", "--porcelain", "--untracked-files=all"], "source cleanliness check"):
        raise IntakeError("local-submodule source must be clean")
    head = _run_git(source, ["rev-parse", "HEAD"], "source HEAD lookup")
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", head):
        raise IntakeError("local-submodule source HEAD is invalid")
    origin = _run_git(source, ["config", "--get", "remote.origin.url"], "source origin lookup")
    candidate_host = urllib.parse.urlsplit(candidate_url).hostname or ""
    canonical_origin = _canonical_url(origin, [candidate_host], repository=True)
    if canonical_origin != candidate_url:
        raise IntakeError("local-submodule source origin does not match the approved candidate")
    return {
        "mode": "local-submodule",
        "source_head": head,
        "source_origin": canonical_origin,
        "source_clean": True,
    }


def _matrix_jsonl_bytes(markdown: str) -> bytes:
    keys = ["date", "repo", "category", "capability", "value", "cost", "risk", "decision", "state", "target", "evidence"]
    rows: List[Mapping[str, str]] = []
    for line in markdown.splitlines():
        if not re.match(r"^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|", line):
            continue
        values = [item.strip() for item in line.strip().strip("|").split("|")]
        if len(values) != len(keys):
            raise IntakeError("adoption matrix contains an unsupported table row")
        rows.append(dict(zip(keys, values)))
    return b"".join(
        (json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
        for row in rows
    )


def _matrix_with_row(markdown: str, row: str) -> str:
    section_marker = "## 当前记录（全量治理）"
    section_start = markdown.find(section_marker)
    if section_start < 0:
        raise IntakeError("adoption matrix canonical table section is missing")
    next_section = markdown.find("\n## ", section_start + len(section_marker))
    if next_section < 0:
        next_section = len(markdown)
    table = markdown[section_start:next_section]
    matches = list(re.finditer(r"(?m)^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|.*\n", table))
    if not matches:
        raise IntakeError("adoption matrix canonical table has no governed rows")
    insert_at = section_start + matches[-1].end()
    return markdown[:insert_at] + row + markdown[insert_at:]


def _contracts(
    root: Path,
    candidate_path: Path,
    decision_path: Path,
    candidate_id: str,
    policy: Mapping[str, Any],
) -> Tuple[Mapping[str, Any], Mapping[str, Any]]:
    candidates = _load_jsonl(candidate_path, policy["limits"]["response_bytes"], "candidate ledger")
    decisions = _load_jsonl(decision_path, policy["limits"]["response_bytes"], "decision ledger")
    for row in candidates:
        _validate_candidate(row, policy)
    for row in decisions:
        _validate_decision(row)
    selected_candidates = [row for row in candidates if row.get("candidate_id") == candidate_id]
    selected_decisions = [row for row in decisions if row.get("candidate_id") == candidate_id]
    if len(selected_candidates) != 1:
        raise IntakeError("candidate_id must resolve to exactly one candidate")
    if len(selected_decisions) != 1:
        raise IntakeError("candidate_id must resolve to exactly one owner decision")
    candidate = selected_candidates[0]
    decision = selected_decisions[0]
    repository = candidate.get("repository")
    if not isinstance(repository, dict):
        raise IntakeError("reference onboarding requires repository metadata")
    if candidate.get("provider") not in {"github", "gitlab", "gitee", "manual"}:
        raise IntakeError("reference onboarding accepts only repository-capable providers")
    if decision.get("decision") != "ADOPT" or decision.get("target") != "reference-repository":
        raise IntakeError("reference onboarding requires an ADOPT decision targeting reference-repository")
    if str(decision.get("owner", "")).lower() in {"external-practice-curator", "collector", "automation"}:
        raise IntakeError("collector or curator cannot own the onboarding decision")
    return candidate, decision


def _phase_gate(root: Path) -> bool:
    path = root / "subrepos/phase-gate.env"
    if not path.is_file():
        return False
    return "allow_upstream_sync=yes" in path.read_text(encoding="utf-8").splitlines()


def _registration_mode(root: Path, repo_name: str) -> Optional[str]:
    with (root / "subrepos/registry.csv").open("r", encoding="utf-8", newline="") as stream:
        registry_rows = [row for row in csv.DictReader(stream) if row.get("repo") == repo_name]
    lifecycle = _load_json(root / "manifests/subrepo_lifecycle.json", 4194304, "subrepo lifecycle")
    if not isinstance(lifecycle, dict) or not isinstance(lifecycle.get("entries"), list):
        return None
    lifecycle_rows = [
        entry
        for entry in lifecycle["entries"]
        if isinstance(entry, dict) and entry.get("repo") == repo_name
    ]
    if not registry_rows and not lifecycle_rows:
        return "register"
    if len(registry_rows) != 1 or len(lifecycle_rows) != 1:
        return None
    registry = registry_rows[0]
    lifecycle_entry = lifecycle_rows[0]
    if registry.get("enabled") != "no" or registry.get("status") != "disabled":
        return None
    if lifecycle_entry.get("state") not in REACTIVATABLE_LIFECYCLE_STATES:
        return None
    return "reactivate"


def _plan(
    root: Path,
    candidate: Mapping[str, Any],
    decision: Mapping[str, Any],
    artifacts: Mapping[str, str],
    artifact_sha256: Mapping[str, str],
    out_md: Path,
    apply_mode: bool,
    materialization: str,
    source_snapshot: Optional[Mapping[str, Any]],
    local_repo_name: str,
    target_path: str,
    branch: str,
    priority: str,
    grade: str,
    intake_policy: str,
    group: str,
) -> Mapping[str, Any]:
    repository = candidate["repository"]
    full_name = str(repository["full_name"])
    repo_name = _safe_component(local_repo_name or full_name.split("/")[-1], "local repository name")
    target = _safe_target(target_path or repo_name)
    branch = _safe_branch(branch)
    registration_mode = _registration_mode(root, repo_name)
    source_risks = set(candidate.get("risk_flags") or [])
    materialization_ready = materialization == "metadata-only" or source_snapshot is not None
    if apply_mode:
        materialization_ready = materialization == "local-submodule" and source_snapshot is not None
    try:
        plan_evidence = out_md.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        plan_evidence = "dry-run-output-outside-repository"
    gates = {
        "candidate_contract_gate": True,
        "owner_decision_gate": True,
        "repository_metadata_gate": True,
        "source_risk_gate": not bool(source_risks.intersection(BLOCKING_RISKS)),
        "analysis_report_gate": True,
        "duplicate_check_gate": True,
        "security_review_gate": True,
        "phase_gate": _phase_gate(root),
        "registry_conflict_gate": registration_mode is not None,
        "target_path_gate": not (root / target).exists(),
        "materialization_gate": materialization_ready,
        "apply_workspace_gate": not apply_mode or _workspace_clean(root),
        "rollback_plan_gate": True,
    }
    plan = {
        "schema": PLAN_SCHEMA,
        "status": "planned",
        "mode": "apply" if apply_mode else "dry-run",
        "candidate": {
            "candidate_id": candidate["candidate_id"],
            "provider": candidate["provider"],
            "source_id": candidate["source_id"],
            "repo": full_name,
            "url": candidate["canonical_url"],
            "license": candidate["license"],
            "risk_flags": candidate["risk_flags"],
            "content_sha256": candidate["content_sha256"],
        },
        "decision": {
            "decision": decision["decision"],
            "owner": decision["owner"],
            "reviewed_at": decision["reviewed_at"],
            "target": decision["target"],
            "evidence_refs": decision["evidence_refs"],
        },
        "gates": gates,
        "required_artifacts": dict(artifacts),
        "artifact_sha256": dict(artifact_sha256),
        "materialization": dict(source_snapshot or {
            "mode": "metadata-only",
            "source_head": None,
            "source_origin": None,
            "source_clean": None,
        }),
        "planned_changes": {
            "registry": {
                "repo": repo_name,
                "group": group,
                "priority": priority,
                "sync_mode": "fetch",
                "branch": branch,
                "enabled": "yes",
                "notes": "approved external-practice active reference; candidate={}".format(candidate["candidate_id"]),
                "status": "active",
                "owner": decision["owner"],
                "last_reviewed_on": decision["reviewed_at"],
                "intake_policy": intake_policy,
                "grade": grade,
            },
            "gitmodules": {
                "name": repo_name,
                "path": target,
                "url": candidate["canonical_url"],
                "materialization": materialization,
            },
            "adoption_matrix": {
                "date": decision["reviewed_at"],
                "source_repo": repo_name,
                "category": group,
                "capability": "approved external-practice reference {}".format(candidate["candidate_id"]),
                "value": "高",
                "cost": "中",
                "risk": "中",
                "decision": "adopt",
                "state": "done" if apply_mode else "pending",
                "target": "llm_agent",
                "evidence": plan_evidence,
            },
        },
        "rollback": {
            "files": sorted(ALLOWED_APPLY_TARGETS),
            "commands": [
                "rtk scripts/plan-reference-repository-removal.sh . --repo {} --evidence-dependency-scan <report> --rollback-plan <report>".format(repo_name),
                "rtk scripts/check-reference-repository-removal.sh .",
            ],
        },
        "boundaries": {
            "network_discovery": False,
            "external_code_executed": False,
            "agent_dev_kit_modified": False,
            "live_runtime_modified": False,
        },
    }
    failed = [name for name, passed in gates.items() if passed is not True]
    if failed:
        raise IntakeError("reference onboarding gates failed: {}".format(", ".join(failed)))
    return plan


def _validate_plan(value: Any, root: Path) -> Mapping[str, Any]:
    if not isinstance(value, dict) or value.get("schema") != PLAN_SCHEMA:
        raise IntakeError("legacy or unknown onboarding plan schema is rejected")
    required = {
        "schema",
        "status",
        "mode",
        "candidate",
        "decision",
        "gates",
        "required_artifacts",
        "artifact_sha256",
        "materialization",
        "planned_changes",
        "rollback",
        "boundaries",
    }
    if set(value) != required:
        raise IntakeError("onboarding plan field set is unsupported")
    status = value.get("status")
    mode = value.get("mode")
    if status not in {"planned", "applied"} or mode not in {"dry-run", "apply"}:
        raise IntakeError("onboarding plan status or mode is invalid")
    if (mode == "dry-run" and status != "planned") or (status == "applied" and mode != "apply"):
        raise IntakeError("onboarding plan status and mode are inconsistent")
    candidate = value.get("candidate")
    candidate_fields = {"candidate_id", "provider", "source_id", "repo", "url", "license", "risk_flags", "content_sha256"}
    if not isinstance(candidate, dict) or set(candidate) != candidate_fields:
        raise IntakeError("onboarding plan candidate projection is invalid")
    provider = candidate.get("provider")
    if provider not in {"github", "gitlab", "gitee", "manual"}:
        raise IntakeError("onboarding plan provider is invalid")
    if not re.fullmatch(r"epc-[0-9a-f]{20}", str(candidate.get("candidate_id", ""))):
        raise IntakeError("onboarding plan candidate_id is invalid")
    if not isinstance(candidate.get("repo"), str) or "/" not in candidate["repo"]:
        raise IntakeError("onboarding plan repository identity is invalid")
    for component in candidate["repo"].split("/"):
        _safe_component(component, "onboarding plan repository component")
    source_id = candidate.get("source_id")
    if not isinstance(source_id, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}", source_id):
        raise IntakeError("onboarding plan source_id is invalid")
    host_map = {"github": ["github.com"], "gitlab": ["gitlab.com"], "gitee": ["gitee.com"], "manual": ["github.com", "gitlab.com", "gitee.com"]}
    canonical_url = _canonical_url(candidate.get("url"), host_map[str(provider)], repository=True)
    if canonical_url != candidate.get("url"):
        raise IntakeError("onboarding plan candidate URL is not canonical")
    _clean_text(candidate.get("license"), "onboarding plan license", 160, allow_empty=False)
    risk_flags = candidate.get("risk_flags")
    if (
        not isinstance(risk_flags, list)
        or len(risk_flags) > 50
        or len(risk_flags) != len(set(risk_flags))
        or not all(isinstance(item, str) and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,99}", item) for item in risk_flags)
        or set(risk_flags).intersection(BLOCKING_RISKS)
    ):
        raise IntakeError("onboarding plan risk flags are invalid or blocking")
    if not re.fullmatch(r"[0-9a-f]{64}", str(candidate.get("content_sha256", ""))):
        raise IntakeError("onboarding plan candidate content hash is invalid")
    decision = value.get("decision")
    decision_fields = {"decision", "owner", "reviewed_at", "target", "evidence_refs"}
    if not isinstance(decision, dict) or set(decision) != decision_fields or decision.get("decision") != "ADOPT" or decision.get("target") != "reference-repository":
        raise IntakeError("onboarding plan requires the ADOPT reference-repository decision")
    owner = _clean_text(decision.get("owner"), "onboarding plan decision owner", 160, allow_empty=False)
    if owner.lower() in {"external-practice-curator", "collector", "automation", "unknown", "none"}:
        raise IntakeError("onboarding plan decision owner is not independent")
    reviewed_at = _parse_date(decision.get("reviewed_at"), "onboarding plan reviewed_at")
    decision_refs = decision.get("evidence_refs")
    if not isinstance(decision_refs, list) or not decision_refs or len(decision_refs) > 50:
        raise IntakeError("onboarding plan decision evidence refs are invalid")
    for ref in decision_refs:
        if not isinstance(ref, str) or _clean_text(ref, "decision evidence ref", 500, allow_empty=False) != ref:
            raise IntakeError("onboarding plan decision evidence ref is invalid")
    gates = value.get("gates")
    if not isinstance(gates, dict) or set(gates) != set(REQUIRED_GATES) or not all(item is True for item in gates.values()):
        raise IntakeError("onboarding plan gates must match and pass the v1 policy")
    artifacts = value.get("required_artifacts")
    if not isinstance(artifacts, dict) or set(artifacts) != set(REQUIRED_ARTIFACTS):
        raise IntakeError("onboarding plan required_artifacts drifted")
    artifact_hashes = value.get("artifact_sha256")
    if not isinstance(artifact_hashes, dict) or set(artifact_hashes) != set(REQUIRED_ARTIFACTS):
        raise IntakeError("onboarding plan artifact hashes drifted")
    for name, ref in artifacts.items():
        if not isinstance(ref, str) or not ref or ref.startswith("/") or ".." in Path(ref).parts:
            raise IntakeError("onboarding plan artifact refs must be safe repository-relative paths")
        artifact_path = root / ref
        _reject_symlink_chain(artifact_path)
        if not artifact_path.is_file():
            raise IntakeError("onboarding plan artifact ref is missing")
        digest = artifact_hashes.get(name)
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) or _sha256_file(artifact_path) != digest:
            raise IntakeError("onboarding plan artifact hash is missing or stale")
    materialization = value.get("materialization")
    materialization_fields = {"mode", "source_head", "source_origin", "source_clean"}
    if not isinstance(materialization, dict) or set(materialization) != materialization_fields:
        raise IntakeError("onboarding plan materialization snapshot is invalid")
    if materialization.get("mode") == "metadata-only":
        if any(materialization.get(field) is not None for field in ("source_head", "source_origin", "source_clean")):
            raise IntakeError("metadata-only plan must not claim a source snapshot")
    elif materialization.get("mode") == "local-submodule":
        if materialization.get("source_clean") is not True:
            raise IntakeError("local-submodule source snapshot must be clean")
        if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", str(materialization.get("source_head", ""))):
            raise IntakeError("local-submodule source snapshot HEAD is invalid")
        if materialization.get("source_origin") != canonical_url:
            raise IntakeError("local-submodule source snapshot origin drifted")
    else:
        raise IntakeError("onboarding plan materialization mode is invalid")
    if mode == "apply" and materialization.get("mode") != "local-submodule":
        raise IntakeError("apply plans require a reviewed local-submodule snapshot")
    changes = value.get("planned_changes")
    if not isinstance(changes, dict) or set(changes) != {"registry", "gitmodules", "adoption_matrix"}:
        raise IntakeError("onboarding plan planned_changes are invalid")
    registry = changes.get("registry")
    registry_fields = {"repo", "group", "priority", "sync_mode", "branch", "enabled", "notes", "status", "owner", "last_reviewed_on", "intake_policy", "grade"}
    if not isinstance(registry, dict) or set(registry) != registry_fields:
        raise IntakeError("onboarding plan registry projection is invalid")
    repo_name = _safe_component(str(registry.get("repo", "")), "onboarding plan local repository name")
    if registry.get("status") != "active" or registry.get("enabled") != "yes" or registry.get("sync_mode") != "fetch":
        raise IntakeError("onboarding plan registry state is invalid")
    _safe_component(str(registry.get("group", "")), "onboarding plan registry group")
    if registry.get("priority") not in {"P0", "P1", "P2"} or registry.get("grade") not in {"S", "A", "B", "C"}:
        raise IntakeError("onboarding plan registry priority or grade is invalid")
    _safe_branch(str(registry.get("branch", "")))
    if registry.get("owner") != owner or registry.get("last_reviewed_on") != reviewed_at:
        raise IntakeError("onboarding plan registry ownership is inconsistent")
    if registry.get("intake_policy") not in {"adopt-first", "observe-first", "selective-adopt", "pilot-first", "security-review-only"}:
        raise IntakeError("onboarding plan registry intake_policy is invalid")
    gitmodules = changes.get("gitmodules")
    if not isinstance(gitmodules, dict) or set(gitmodules) != {"name", "path", "url", "materialization"}:
        raise IntakeError("onboarding plan gitmodules projection is invalid")
    _safe_target(str(gitmodules.get("path", "")))
    if (
        gitmodules.get("name") != repo_name
        or gitmodules.get("url") != canonical_url
        or gitmodules.get("materialization") != materialization.get("mode")
    ):
        raise IntakeError("onboarding plan materialization is invalid")
    matrix = changes.get("adoption_matrix")
    matrix_fields = {"date", "source_repo", "category", "capability", "value", "cost", "risk", "decision", "state", "target", "evidence"}
    if not isinstance(matrix, dict) or set(matrix) != matrix_fields:
        raise IntakeError("onboarding plan adoption_matrix projection is invalid")
    if (
        matrix.get("date") != reviewed_at
        or matrix.get("source_repo") != repo_name
        or matrix.get("category") != registry.get("group")
        or matrix.get("decision") != "adopt"
        or matrix.get("state") != ("done" if mode == "apply" else "pending")
        or matrix.get("target") != "llm_agent"
    ):
        raise IntakeError("onboarding plan adoption_matrix projection is inconsistent")
    evidence_ref = matrix.get("evidence")
    if not isinstance(evidence_ref, str) or not evidence_ref:
        raise IntakeError("onboarding plan evidence reference is missing")
    if mode == "apply" and (evidence_ref.startswith("/") or ".." in Path(evidence_ref).parts or not evidence_ref.startswith("reports/")):
        raise IntakeError("apply plan evidence must be a repository report path")
    rollback = value.get("rollback")
    if not isinstance(rollback, dict) or set(rollback) != {"files", "commands"}:
        raise IntakeError("onboarding plan rollback is invalid")
    if set(rollback.get("files") or []) != ALLOWED_APPLY_TARGETS:
        raise IntakeError("onboarding plan rollback files drifted")
    commands = rollback.get("commands")
    expected_commands = [
        "rtk scripts/plan-reference-repository-removal.sh . --repo {} --evidence-dependency-scan <report> --rollback-plan <report>".format(repo_name),
        "rtk scripts/check-reference-repository-removal.sh .",
    ]
    if commands != expected_commands:
        raise IntakeError("onboarding plan rollback commands are invalid")
    expected_boundaries = {
        "network_discovery": False,
        "external_code_executed": False,
        "agent_dev_kit_modified": False,
        "live_runtime_modified": False,
    }
    if value.get("boundaries") != expected_boundaries:
        raise IntakeError("onboarding plan boundaries were weakened")
    return value


def _markdown(plan: Mapping[str, Any]) -> str:
    lines = [
        "# Reference Repository Onboarding Plan",
        "",
        "> schema: {}".format(plan["schema"]),
        "> status: {}".format(plan["status"]),
        "> mode: {}".format(plan["mode"]),
        "> candidate: {}".format(plan["candidate"]["candidate_id"]),
        "> owner: {}".format(plan["decision"]["owner"]),
        "",
        "## Gates",
        "",
        "| gate | result |",
        "|---|---|",
    ]
    for gate, passed in plan["gates"].items():
        lines.append("| {} | {} |".format(gate, "pass" if passed else "fail"))
    lines.extend([
        "",
        "## Planned Changes",
        "",
        "- registry repository: `{}`".format(plan["planned_changes"]["registry"]["repo"]),
        "- materialization: `{}`".format(plan["planned_changes"]["gitmodules"]["materialization"]),
        "- reviewed source HEAD: `{}`".format(plan["materialization"]["source_head"] or "not-applicable"),
        "- ADK absorption: not performed by repository registration",
        "- external discovery/runtime writes: disabled",
        "",
        "## Rollback",
        "",
    ])
    lines.extend("- `{}`".format(command) for command in plan["rollback"]["commands"])
    lines.extend(["", "## Artifact Digests", ""])
    for name in sorted(plan["required_artifacts"]):
        lines.append("- `{}`: `{}` (`{}`)".format(name, plan["artifact_sha256"][name], plan["required_artifacts"][name]))
    lines.append("")
    return "\n".join(lines)


def _rollback_added_submodule(root: Path, target: str) -> None:
    subprocess.run(
        ["rtk", "git", "-C", str(root), "submodule", "deinit", "-f", "--", target],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    completed = subprocess.run(
        ["rtk", "git", "-C", str(root), "rm", "-f", "--", target],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise IntakeError("registration rollback could not remove the newly added submodule")
    target_path = root / target
    if target_path.exists():
        if not target_path.is_dir() or any(target_path.iterdir()):
            raise IntakeError("registration rollback left a non-empty submodule target")
        target_path.rmdir()


def _apply(
    root: Path,
    plan: Mapping[str, Any],
    submodule_source: Optional[Path],
    out_json: Path,
    out_md: Path,
    inputs: Sequence[Path],
) -> Mapping[str, Any]:
    changes = plan["planned_changes"]
    gitmodules = changes["gitmodules"]
    target = str(gitmodules["path"])
    repo_name = str(gitmodules["name"])
    if gitmodules["materialization"] != "local-submodule" or submodule_source is None:
        raise IntakeError("apply requires local-submodule materialization")
    current_snapshot = _source_snapshot(submodule_source, str(plan["candidate"]["url"]))
    if current_snapshot != plan["materialization"]:
        raise IntakeError("reviewed local source changed after plan generation")

    registry_path = root / "subrepos/registry.csv"
    fieldnames = ["repo", "group", "priority", "sync_mode", "branch", "enabled", "notes", "status", "owner", "last_reviewed_on", "intake_policy", "grade"]
    current_registry = registry_path.read_text(encoding="utf-8")
    registration_mode = _registration_mode(root, repo_name)
    if registration_mode is None:
        raise IntakeError("registration apply found an unsafe registry/lifecycle baseline")
    registry_rows = list(csv.DictReader(io.StringIO(current_registry)))
    matching_registry = [row for row in registry_rows if row.get("repo") == repo_name]
    if registration_mode == "register" and not matching_registry:
        registry_rows.append(changes["registry"])
        previous_lifecycle_state = None
    elif registration_mode == "reactivate" and len(matching_registry) == 1:
        registry_rows = [changes["registry"] if row.get("repo") == repo_name else row for row in registry_rows]
        previous_lifecycle_state = ""
    else:
        raise IntakeError("registration apply found a conflicting registry state")
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(registry_rows)
    registry_payload = buffer.getvalue().encode("utf-8")

    matrix_path = root / "subrepos/adoption-matrix.md"
    current_matrix = matrix_path.read_text(encoding="utf-8")
    matrix_jsonl_path = root / "subrepos/adoption-matrix.jsonl"
    current_matrix_jsonl = matrix_jsonl_path.read_bytes()
    if _matrix_jsonl_bytes(current_matrix) != current_matrix_jsonl:
        raise IntakeError("adoption matrix JSONL is stale before registration")
    row = "| {date} | {source_repo} | {category} | {capability} | {value} | {cost} | {risk} | {decision} | {state} | {target} | {evidence} |\n".format(**changes["adoption_matrix"])
    matrix_payload_text = _matrix_with_row(current_matrix, row)
    matrix_payload = matrix_payload_text.encode("utf-8")
    matrix_jsonl_payload = _matrix_jsonl_bytes(matrix_payload_text)

    lifecycle_path = root / "manifests/subrepo_lifecycle.json"
    lifecycle = _load_json(lifecycle_path, 4194304, "subrepo lifecycle")
    if not isinstance(lifecycle, dict) or not isinstance(lifecycle.get("entries"), list):
        raise IntakeError("subrepo lifecycle manifest is invalid")
    matching_lifecycle = [
        (index, entry)
        for index, entry in enumerate(lifecycle["entries"])
        if isinstance(entry, dict) and entry.get("repo") == changes["registry"]["repo"]
    ]
    if len(matching_lifecycle) > 1:
        raise IntakeError("subrepo lifecycle contains duplicate reference repository entries")
    if registration_mode == "reactivate":
        if len(matching_lifecycle) != 1 or matching_lifecycle[0][1].get("state") not in REACTIVATABLE_LIFECYCLE_STATES:
            raise IntakeError("registration apply found a conflicting lifecycle state")
        previous_lifecycle_state = str(matching_lifecycle[0][1]["state"])
        previous_evidence = matching_lifecycle[0][1].get("evidence") or []
    elif matching_lifecycle:
        raise IntakeError("new registration unexpectedly found an existing lifecycle entry")
    else:
        previous_evidence = []
    lifecycle["last_updated"] = changes["registry"]["last_reviewed_on"]
    lifecycle_entry = {
        "repo": changes["registry"]["repo"],
        "state": "active-reference",
        "source": {
            "url": plan["candidate"]["url"],
            "provider": plan["candidate"]["provider"],
            "branch": changes["registry"]["branch"],
            "commit": plan["materialization"]["source_head"],
            "retrieved_at": changes["registry"]["last_reviewed_on"],
        },
        "runtime_boundaries": [
            "do-not-install-external-skills",
            "do-not-execute-external-hooks-or-runtime",
            "review-before-adk-absorption",
        ],
        "owner": changes["registry"]["owner"],
        "review_window": "monthly",
        "automation_eligible": False,
        "evidence": list(dict.fromkeys([
            *[item for item in previous_evidence if isinstance(item, str)],
            ".gitmodules",
            "subrepos/registry.csv",
            changes["adoption_matrix"]["evidence"],
            *plan["required_artifacts"].values(),
        ])),
    }
    if previous_lifecycle_state is not None:
        lifecycle_entry["reactivated_from"] = previous_lifecycle_state
        lifecycle_entry["reactivated_at"] = changes["registry"]["last_reviewed_on"]
        lifecycle["entries"][matching_lifecycle[0][0]] = lifecycle_entry
    else:
        lifecycle["entries"].append(lifecycle_entry)
    lifecycle_payload = _json_bytes(lifecycle)

    applied_plan = dict(plan)
    applied_plan["status"] = "applied"
    applied_json = _json_bytes(applied_plan)
    applied_markdown = _markdown(applied_plan).encode("utf-8")

    submodule_added = False
    completed = subprocess.run(
        [
            "rtk",
            "git",
            "-C",
            str(root),
            "-c",
            "protocol.file.allow=always",
            "submodule",
            "add",
            "--name",
            repo_name,
            str(submodule_source),
            target,
        ],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise IntakeError("local submodule materialization failed")
    submodule_added = True
    try:
        materialized_head = _run_git(root / target, ["rev-parse", "HEAD"], "materialized submodule HEAD lookup")
        if materialized_head != plan["materialization"]["source_head"]:
            raise IntakeError("materialized submodule HEAD does not match the reviewed source")
        _run_git(
            root,
            ["config", "-f", ".gitmodules", "submodule.{}.url".format(repo_name), str(plan["candidate"]["url"])],
            "approved submodule URL write",
        )
        _run_git(root, ["add", "--", ".gitmodules"], "approved submodule URL staging")
        _run_git(root, ["submodule", "sync", "--", target], "materialized submodule URL sync")
        configured_url = _run_git(root, ["config", "-f", ".gitmodules", "--get", "submodule.{}.url".format(repo_name)], "submodule URL verification")
        materialized_origin = _run_git(root / target, ["config", "--get", "remote.origin.url"], "materialized origin verification")
        if configured_url != plan["candidate"]["url"] or materialized_origin != plan["candidate"]["url"]:
            raise IntakeError("materialized submodule origin does not match the approved candidate")
        _transactional_write(
            [
                (registry_path, registry_payload),
                (matrix_path, matrix_payload),
                (matrix_jsonl_path, matrix_jsonl_payload),
                (lifecycle_path, lifecycle_payload),
                (out_json, applied_json),
                (out_md, applied_markdown),
            ],
            inputs,
        )
    except Exception as exc:
        if submodule_added:
            try:
                _rollback_added_submodule(root, target)
            except IntakeError as rollback_exc:
                raise IntakeError("registration failed and automatic rollback also failed: {}".format(rollback_exc)) from rollback_exc
        if isinstance(exc, IntakeError):
            raise
        raise IntakeError("registration metadata transaction failed") from exc
    return applied_plan


def _cmd_plan(args: argparse.Namespace, root: Path, intake_policy: Mapping[str, Any]) -> int:
    candidate_path, candidate_ref, candidate_sha = _artifact(root, args.candidates, "candidate ledger")
    decision_path, decision_ref, decision_sha = _artifact(root, args.decisions, "decision ledger")
    analysis_path, analysis_ref, analysis_sha = _artifact(root, args.analysis, "analysis report")
    duplicate_path, duplicate_ref, duplicate_sha = _artifact(root, args.duplicate_check, "duplicate check")
    security_path, security_ref, security_sha = _artifact(root, args.security_review, "security review")
    candidate, decision = _contracts(root, candidate_path, decision_path, args.candidate_id, intake_policy)
    if args.materialization not in {"metadata-only", "local-submodule"}:
        raise IntakeError("materialization must be metadata-only or local-submodule")
    if args.apply and args.materialization != "local-submodule":
        raise IntakeError("apply requires explicit local-submodule materialization")
    if args.materialization == "metadata-only" and args.submodule_source:
        raise IntakeError("metadata-only planning must not receive a submodule source")
    submodule_source = Path(args.submodule_source).resolve() if args.submodule_source else None
    if args.materialization == "local-submodule" and (submodule_source is None or not submodule_source.is_dir()):
        raise IntakeError("local-submodule requires a reviewed local source directory")
    out_json = _resolve_path(root, args.out_json or "reports/reference-repository-onboarding-{}-{}.json".format(args.candidate_id, decision["reviewed_at"]), "onboarding plan JSON")
    out_md = _resolve_path(root, args.out_md or "reports/reference-repository-onboarding-{}-{}.md".format(args.candidate_id, decision["reviewed_at"]), "onboarding plan Markdown")
    if args.apply:
        for output in (out_json, out_md):
            try:
                relative = output.relative_to(root)
            except ValueError as exc:
                raise IntakeError("apply plan outputs must stay inside the repository") from exc
            if not relative.parts or relative.parts[0] != "reports":
                raise IntakeError("apply plan outputs must stay under reports/")
    artifacts = {
        "candidate_ledger": candidate_ref,
        "decision_ledger": decision_ref,
        "analysis_report": analysis_ref,
        "duplicate_check": duplicate_ref,
        "security_review": security_ref,
    }
    artifact_hashes = {
        "candidate_ledger": candidate_sha,
        "decision_ledger": decision_sha,
        "analysis_report": analysis_sha,
        "duplicate_check": duplicate_sha,
        "security_review": security_sha,
    }
    source_snapshot = _source_snapshot(submodule_source, str(candidate["canonical_url"])) if submodule_source is not None else None
    plan = _plan(
        root,
        candidate,
        decision,
        artifacts,
        artifact_hashes,
        out_md,
        args.apply,
        args.materialization,
        source_snapshot,
        args.repo_name or "",
        args.target_path or "",
        args.branch,
        args.priority,
        args.grade,
        args.intake_policy,
        args.group,
    )
    _validate_plan(plan, root)
    inputs = [candidate_path, decision_path, analysis_path, duplicate_path, security_path]
    _transactional_write(
        [(out_json, _json_bytes(plan)), (out_md, _markdown(plan).encode("utf-8"))],
        inputs,
    )
    if args.apply:
        plan = _apply(root, plan, submodule_source, out_json, out_md, inputs)
    print("[PASS] reference onboarding mode={} candidate={} plan={}".format(plan["mode"], args.candidate_id, out_json))
    return 0


def _cmd_check(args: argparse.Namespace, root: Path) -> int:
    _load_registration_policy(root)
    paths = [_resolve_path(root, value, "onboarding plan") for value in args.plan]
    if not args.no_fixtures:
        paths.extend(sorted((root / "fixtures/external-practice/registration/pass").glob("*.json")))
    checked = 0
    failures: List[str] = []
    for path in paths:
        try:
            _validate_plan(_load_json(path, 4194304, "onboarding plan"), root)
            checked += 1
        except IntakeError as exc:
            failures.append("{}: {}".format(_relative_ref(root, path), exc))
    if not args.no_fixtures:
        for path in sorted((root / "fixtures/external-practice/registration/fail").glob("*.json")):
            try:
                _validate_plan(_load_json(path, 4194304, "onboarding fail fixture"), root)
            except IntakeError:
                checked += 1
            else:
                failures.append("{} unexpectedly passed".format(_relative_ref(root, path)))
    if failures:
        if args.summary_json:
            print(json.dumps({"status": "fail", "checked": checked, "failures": len(failures)}, sort_keys=True))
        for failure in failures:
            print("[FAIL] {}".format(failure), file=sys.stderr)
        return 2
    if args.summary_json:
        print(json.dumps({"status": "pass", "checked": checked, "failures": 0}, sort_keys=True))
    else:
        print("[PASS] reference repository registration policy and plans passed: checked={}".format(checked))
    return 0


def _safe_repository_ref(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value or value.startswith("/") or ".." in Path(value).parts:
        raise IntakeError("{} must be a safe repository-relative path".format(label))
    return value


def _validate_removal_plan(value: Any, root: Path) -> Mapping[str, Any]:
    if not isinstance(value, dict) or value.get("schema") != REMOVAL_PLAN_SCHEMA:
        raise IntakeError("legacy or unknown reference repository removal plan is rejected")
    required = {
        "schema",
        "status",
        "mode",
        "as_of",
        "repository",
        "gates",
        "required_artifacts",
        "artifact_sha256",
        "planned_changes",
        "precheck",
        "postcheck",
        "rollback",
        "boundaries",
    }
    if set(value) != required or value.get("status") != "planned" or value.get("mode") != "dry-run":
        raise IntakeError("reference repository removal plan must remain a planned dry-run")
    as_of = _parse_date(value.get("as_of"), "reference repository removal as_of")
    repository = value.get("repository")
    repository_fields = {"repo", "lifecycle_state", "registry_status", "protected", "active_core"}
    if not isinstance(repository, dict) or set(repository) != repository_fields:
        raise IntakeError("reference repository removal projection is invalid")
    repo = _safe_component(str(repository.get("repo", "")), "reference repository removal name")
    if (
        repository.get("lifecycle_state") not in REMOVAL_ELIGIBLE_STATES
        or repository.get("protected") is not False
        or repository.get("active_core") is not False
        or repo == "agent-dev-kit"
    ):
        raise IntakeError("reference repository is not eligible for removal planning")
    _clean_text(repository.get("registry_status"), "reference repository registry status", 40, allow_empty=False)
    gates = value.get("gates")
    if not isinstance(gates, dict) or set(gates) != set(REMOVAL_REQUIRED_GATES) or not all(item is True for item in gates.values()):
        raise IntakeError("reference repository removal gates must be complete and passing")
    artifacts = value.get("required_artifacts")
    hashes = value.get("artifact_sha256")
    if not isinstance(artifacts, dict) or set(artifacts) != REMOVAL_ARTIFACTS:
        raise IntakeError("reference repository removal artifacts drifted")
    if not isinstance(hashes, dict) or set(hashes) != REMOVAL_ARTIFACTS:
        raise IntakeError("reference repository removal artifact hashes drifted")
    for name, ref_value in artifacts.items():
        ref = _safe_repository_ref(ref_value, "removal artifact {}".format(name))
        path = root / ref
        _reject_symlink_chain(path)
        digest = hashes.get(name)
        if not path.is_file() or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise IntakeError("reference repository removal artifact is missing or unhashed")
        if _sha256_file(path) != digest:
            raise IntakeError("reference repository removal artifact hash is stale")
    changes = value.get("planned_changes")
    if not isinstance(changes, dict) or set(changes) != REMOVAL_CHANGES:
        raise IntakeError("reference repository removal changes drifted")
    report_path = "reports/reference-repository-removal-{}-{}.md".format(repo, as_of)
    expected_changes = {
        "gitmodules": {"action": "remove-entry", "path": ".gitmodules"},
        "gitlink": {"action": "remove-gitlink", "path": repo},
        "registry": {"action": "mark-removed", "path": "subrepos/registry.csv"},
        "dirty_baseline": {"action": "drop-entry-if-present", "path": "subrepos/dirty-baseline.tsv"},
        "lifecycle": {"action": "mark-removed", "path": "manifests/subrepo_lifecycle.json"},
        "docs_reports": {"action": "write-removal-evidence", "path": report_path},
    }
    if changes != expected_changes:
        raise IntakeError("reference repository removal changes are not deterministic")
    expected_check = {"command": "rtk scripts/check-all.sh --quick"}
    if value.get("precheck") != expected_check or value.get("postcheck") != expected_check:
        raise IntakeError("reference repository removal pre/post checks drifted")
    rollback = value.get("rollback")
    expected_rollback = {
        "files": sorted(REMOVAL_ROLLBACK_FILES),
        "commands": ["rtk git revert <removal-commit>"],
    }
    if rollback != expected_rollback:
        raise IntakeError("reference repository removal rollback contract drifted")
    expected_boundaries = {
        "apply_supported": False,
        "repository_deleted": False,
        "agent_dev_kit_modified": False,
        "live_runtime_modified": False,
    }
    if value.get("boundaries") != expected_boundaries:
        raise IntakeError("reference repository removal boundaries were weakened")
    return value


def _removal_markdown(plan: Mapping[str, Any]) -> str:
    repo = plan["repository"]["repo"]
    lines = [
        "# Reference Repository Removal Plan: {}".format(repo),
        "",
        "> schema: {}".format(plan["schema"]),
        "> date: {}".format(plan["as_of"]),
        "> mode: dry-run",
        "> status: planned",
        "",
        "## Decision",
        "",
        "`{}` is eligible for removal planning because lifecycle state is `{}`.".format(repo, plan["repository"]["lifecycle_state"]),
        "",
        "## Artifact Digests",
        "",
    ]
    for name in sorted(plan["required_artifacts"]):
        lines.append("- `{}`: `{}` (`{}`)".format(name, plan["artifact_sha256"][name], plan["required_artifacts"][name]))
    lines.extend([
        "",
        "## Required Gates",
        "",
        "- `rtk scripts/check-reference-repository-removal.sh .`",
        "- `rtk scripts/check-all.sh --quick`",
        "",
        "No removal has been applied by this plan; destructive apply is not implemented by this control plane.",
        "",
    ])
    return "\n".join(lines)


def _cmd_plan_removal(args: argparse.Namespace, root: Path) -> int:
    _load_removal_policy(root)
    as_of = _parse_date(args.as_of or date.today().isoformat(), "reference repository removal as_of")
    repo = _safe_component(args.repo, "reference repository removal name")
    lifecycle = _load_json(root / "manifests/subrepo_lifecycle.json", 4194304, "subrepo lifecycle")
    if not isinstance(lifecycle, dict) or not isinstance(lifecycle.get("entries"), list):
        raise IntakeError("subrepo lifecycle manifest is invalid")
    entry = next((item for item in lifecycle["entries"] if isinstance(item, dict) and item.get("repo") == repo), None)
    if entry is None:
        raise IntakeError("reference repository is missing from the lifecycle manifest")
    with (root / "subrepos/registry.csv").open("r", encoding="utf-8", newline="") as stream:
        registry = next((item for item in csv.DictReader(stream) if item.get("repo") == repo), None)
    if registry is None:
        raise IntakeError("reference repository is missing from the registry")
    state = entry.get("state")
    if state not in REMOVAL_ELIGIBLE_STATES or repo == "agent-dev-kit" or state == "active-core":
        raise IntakeError("reference repository is not eligible for removal planning")

    artifact_values = {
        "adoption_decision": args.adoption_decision,
        "evidence_dependency_scan": args.evidence_dependency_scan,
        "dirty_baseline_review": args.dirty_baseline_review,
        "rollback_plan": args.rollback_plan,
    }
    artifact_paths: Dict[str, Path] = {}
    artifact_refs: Dict[str, str] = {}
    artifact_hashes: Dict[str, str] = {}
    for name, value in artifact_values.items():
        path, ref, digest = _artifact(root, value, "removal artifact {}".format(name))
        artifact_paths[name] = path
        artifact_refs[name] = ref
        artifact_hashes[name] = digest

    out_json = _resolve_path(root, args.out_json or "reports/reference-repository-removal-{}-{}.json".format(repo, as_of), "removal plan JSON")
    out_md = _resolve_path(root, args.out_md or "reports/reference-repository-removal-{}-{}.md".format(repo, as_of), "removal plan Markdown")
    report_ref = "reports/reference-repository-removal-{}-{}.md".format(repo, as_of)
    plan = {
        "schema": REMOVAL_PLAN_SCHEMA,
        "status": "planned",
        "mode": "dry-run",
        "as_of": as_of,
        "repository": {
            "repo": repo,
            "lifecycle_state": state,
            "registry_status": registry.get("status", ""),
            "protected": False,
            "active_core": False,
        },
        "gates": {name: True for name in REMOVAL_REQUIRED_GATES},
        "required_artifacts": artifact_refs,
        "artifact_sha256": artifact_hashes,
        "planned_changes": {
            "gitmodules": {"action": "remove-entry", "path": ".gitmodules"},
            "gitlink": {"action": "remove-gitlink", "path": repo},
            "registry": {"action": "mark-removed", "path": "subrepos/registry.csv"},
            "dirty_baseline": {"action": "drop-entry-if-present", "path": "subrepos/dirty-baseline.tsv"},
            "lifecycle": {"action": "mark-removed", "path": "manifests/subrepo_lifecycle.json"},
            "docs_reports": {"action": "write-removal-evidence", "path": report_ref},
        },
        "precheck": {"command": "rtk scripts/check-all.sh --quick"},
        "postcheck": {"command": "rtk scripts/check-all.sh --quick"},
        "rollback": {
            "files": sorted(REMOVAL_ROLLBACK_FILES),
            "commands": ["rtk git revert <removal-commit>"],
        },
        "boundaries": {
            "apply_supported": False,
            "repository_deleted": False,
            "agent_dev_kit_modified": False,
            "live_runtime_modified": False,
        },
    }
    _validate_removal_plan(plan, root)
    _transactional_write(
        [(out_json, _json_bytes(plan)), (out_md, _removal_markdown(plan).encode("utf-8"))],
        list(artifact_paths.values()),
    )
    print("[PASS] reference repository removal dry-run plan written: {}".format(_relative_ref(root, out_json)))
    return 0


def _cmd_check_removal(args: argparse.Namespace, root: Path) -> int:
    _load_removal_policy(root)
    paths = [_resolve_path(root, value, "reference repository removal plan") for value in args.plan]
    if not args.no_fixtures:
        paths.extend(sorted((root / "fixtures/reference-repository/removal/pass").glob("*.json")))
    if not paths and not args.no_fixtures:
        paths.extend(sorted((root / "reports").glob("reference-repository-removal-*.json")))
    checked = 0
    failures: List[str] = []
    for path in paths:
        try:
            _validate_removal_plan(_load_json(path, 4194304, "reference repository removal plan"), root)
            checked += 1
        except IntakeError as exc:
            failures.append("{}: {}".format(_relative_ref(root, path), exc))
    if not args.no_fixtures:
        for path in sorted((root / "fixtures/reference-repository/removal/fail").glob("*.json")):
            try:
                _validate_removal_plan(_load_json(path, 4194304, "reference repository removal fail fixture"), root)
            except IntakeError:
                checked += 1
            else:
                failures.append("{} unexpectedly passed".format(_relative_ref(root, path)))
    if failures:
        if args.summary_json:
            print(json.dumps({"status": "fail", "checked": checked, "failures": len(failures)}, sort_keys=True))
        for failure in failures:
            print("[FAIL] {}".format(failure), file=sys.stderr)
        return 2
    if args.summary_json:
        print(json.dumps({"status": "pass", "checked": checked, "failures": 0}, sort_keys=True))
    else:
        print("[PASS] reference repository removal policy and plans passed: checked={}".format(checked))
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Post-decision reference repository registration")
    parser.add_argument("--root", required=True)
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser("plan")
    plan.add_argument("--candidates", required=True)
    plan.add_argument("--decisions", required=True)
    plan.add_argument("--candidate-id", required=True)
    plan.add_argument("--analysis", required=True)
    plan.add_argument("--duplicate-check", required=True)
    plan.add_argument("--security-review", required=True)
    plan.add_argument("--out-json")
    plan.add_argument("--out-md")
    plan.add_argument("--apply", action="store_true")
    plan.add_argument("--materialization", default="metadata-only")
    plan.add_argument("--submodule-source")
    plan.add_argument("--repo-name")
    plan.add_argument("--target-path")
    plan.add_argument("--branch", default="main")
    plan.add_argument("--priority", default="P1")
    plan.add_argument("--grade", default="A")
    plan.add_argument("--intake-policy", default="observe-first")
    plan.add_argument("--group", default="agent-ecosystem")

    check = subparsers.add_parser("check")
    check.add_argument("--plan", action="append", default=[])
    check.add_argument("--no-fixtures", action="store_true")
    check.add_argument("--summary-json", action="store_true")

    plan_removal = subparsers.add_parser("plan-removal")
    plan_removal.add_argument("--repo", required=True)
    plan_removal.add_argument("--as-of")
    plan_removal.add_argument("--adoption-decision", default="subrepos/adoption-matrix.md")
    plan_removal.add_argument("--evidence-dependency-scan", required=True)
    plan_removal.add_argument("--dirty-baseline-review", default="subrepos/dirty-baseline.tsv")
    plan_removal.add_argument("--rollback-plan", required=True)
    plan_removal.add_argument("--out-json")
    plan_removal.add_argument("--out-md")

    check_removal = subparsers.add_parser("check-removal")
    check_removal.add_argument("--plan", action="append", default=[])
    check_removal.add_argument("--no-fixtures", action="store_true")
    check_removal.add_argument("--summary-json", action="store_true")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    root = Path(args.root).resolve()
    if not root.is_dir():
        print("[FAIL] repository root is missing", file=sys.stderr)
        return 2
    try:
        if args.command == "check-removal":
            return _cmd_check_removal(args, root)
        if args.command == "plan-removal":
            return _cmd_plan_removal(args, root)
        if args.command == "check":
            return _cmd_check(args, root)
        _load_registration_policy(root)
        intake_policy, _ = _load_policy(root, None)
        return _cmd_plan(args, root, intake_policy)
    except IntakeError as exc:
        print("[FAIL] {}".format(exc), file=sys.stderr)
        return 2
    except OSError:
        print("[FAIL] local filesystem operation failed", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
