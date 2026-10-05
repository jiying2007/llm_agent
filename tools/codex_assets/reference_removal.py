"""Dry-run-only reference removal planning and validation; never deletes."""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any, Dict, List, Mapping

from .intake_io import (
    IntakeError, _json_bytes, _load_json, _reject_symlink_chain, _relative_ref, _resolve_path,
    _sha256_file, _transactional_write,
)
from .practice_intake import _clean_text, _parse_date

from .reference_contracts import (
    REMOVAL_PLAN_SCHEMA,
    REMOVAL_REQUIRED_GATES,
    REMOVAL_ELIGIBLE_STATES,
    REMOVAL_ARTIFACTS,
    REMOVAL_CHANGES,
    REMOVAL_ROLLBACK_FILES,
    _load_removal_policy,
    _artifact,
    _safe_component,
)


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
