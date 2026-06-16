#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUMMARY_JSON=0
FIXTURES=1
PLANS=()

usage() {
  cat <<USAGE
usage: scripts/check-oss-registration-plan.sh [root] [--plan FILE] [--no-fixtures] [--summary-json]

Validates P2 gated OSS onboarding plans.
The check is offline and read-only. It does not clone, register, absorb, or remove repositories.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --plan requires a file path" >&2
        exit 1
      }
      PLANS+=("$2")
      FIXTURES=0
      shift 2
      ;;
    --no-fixtures)
      FIXTURES=0
      shift
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
    *)
      ROOT="$1"
      shift
      ;;
  esac
done

python3 - "$ROOT" "$SUMMARY_JSON" "$FIXTURES" "${PLANS[@]}" <<'PY'
import glob
import json
import os
import re
import sys

root = os.path.abspath(sys.argv[1])
summary_json = sys.argv[2] == "1"
check_fixtures = sys.argv[3] == "1"
explicit_plans = sys.argv[4:]

required_gates = [
    "candidate_score_gate",
    "hard_reject_gate",
    "analysis_report_gate",
    "duplicate_check_gate",
    "security_review_gate",
    "phase_gate",
    "registry_conflict_gate",
    "target_path_gate",
    "materialization_gate",
    "rollback_plan_gate",
]
required_artifacts = ["ledger", "analysis_report", "duplicate_check", "security_review"]
required_changes = ["registry", "gitmodules", "adoption_matrix"]
allowed_apply_targets = {
    ".gitmodules",
    "subrepos/registry.csv",
    "subrepos/adoption-matrix.md",
    "subrepos/adoption-matrix.jsonl",
    "manifests/subrepo_lifecycle.json",
}

failures = []
stats = {"manifests": 0, "plans": 0, "pass_fixtures": 0, "fail_fixtures": 0}


def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path


def fail(message):
    failures.append(message)


def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_policy():
    path = os.path.join(root, "manifests/oss_registration_policy.json")
    if not os.path.isfile(path):
        fail("missing manifest: manifests/oss_registration_policy.json")
        return
    try:
        policy = read_json(path)
    except Exception as exc:
        fail(f"invalid JSON in manifests/oss_registration_policy.json: {exc}")
        return
    stats["manifests"] += 1
    if policy.get("status") != "gated-registration":
        fail("oss_registration_policy.json status must be gated-registration")
    if policy.get("default_mode") != "dry-run":
        fail("oss_registration_policy.json default_mode must be dry-run")
    if policy.get("required_gates") != required_gates:
        fail("oss_registration_policy.json required_gates mismatch")
    rules = policy.get("rules", {})
    for key in (
        "apply_requires_explicit_flag",
        "apply_requires_materialization_mode",
        "apply_must_not_modify_agent_dev_kit",
        "apply_must_not_run_network_discovery",
        "apply_must_generate_rollback_evidence",
    ):
        if rules.get(key) is not True:
            fail(f"oss_registration_policy.json rules.{key} must be true")


def non_empty_string(value):
    return isinstance(value, str) and bool(value.strip())


def validate_plan(path, expect_pass=True):
    before = len(failures)
    if not os.path.isfile(path):
        fail(f"missing onboarding plan: {rel(path)}")
        return False
    try:
        plan = read_json(path)
    except Exception as exc:
        fail(f"{rel(path)}: invalid JSON: {exc}")
        return False

    context = rel(path)
    if plan.get("schema_version") != 1:
        fail(f"{context}: schema_version must be 1")
    if plan.get("status") not in {"planned", "applied"}:
        fail(f"{context}: status must be planned or applied")
    if plan.get("mode") not in {"dry-run", "apply"}:
        fail(f"{context}: mode must be dry-run or apply")

    candidate = plan.get("candidate")
    if not isinstance(candidate, dict):
        fail(f"{context}: candidate must be an object")
    else:
        repo = candidate.get("repo")
        if not non_empty_string(repo) or not re.fullmatch(r"[^/\s]+/[^/\s]+", repo):
            fail(f"{context}: candidate.repo must be owner/name")
        if candidate.get("score", -1) < 90:
            fail(f"{context}: candidate.score must be >= 90")
        if candidate.get("decision") != "onboard-candidate":
            fail(f"{context}: candidate.decision must be onboard-candidate")
        if candidate.get("hard_rejects") != []:
            fail(f"{context}: candidate.hard_rejects must be empty")

    gates = plan.get("gates")
    if not isinstance(gates, dict):
        fail(f"{context}: gates must be an object")
    else:
        for gate in required_gates:
            if gates.get(gate) is not True:
                fail(f"{context}: gate must pass: {gate}")

    artifacts = plan.get("required_artifacts")
    if not isinstance(artifacts, dict):
        fail(f"{context}: required_artifacts must be an object")
    else:
        for key in required_artifacts:
            value = artifacts.get(key)
            if not non_empty_string(value):
                fail(f"{context}: required_artifacts.{key} must be a non-empty path")
            elif value.startswith("/") or ".." in value.split("/"):
                fail(f"{context}: required_artifacts.{key} must be a safe relative path")

    changes = plan.get("planned_changes")
    if not isinstance(changes, dict):
        fail(f"{context}: planned_changes must be an object")
    else:
        for key in required_changes:
            if not isinstance(changes.get(key), dict):
                fail(f"{context}: planned_changes.{key} must be an object")
        registry = changes.get("registry", {})
        expected_registry = [
            "repo",
            "group",
            "priority",
            "sync_mode",
            "branch",
            "enabled",
            "notes",
            "status",
            "owner",
            "last_reviewed_on",
            "intake_policy",
            "grade",
        ]
        for key in expected_registry:
            if not non_empty_string(registry.get(key)):
                fail(f"{context}: planned_changes.registry.{key} is required")
        if registry.get("repo") == "agent-dev-kit":
            fail(f"{context}: must not register agent-dev-kit through OSS intake")
        if registry.get("status") not in {"active", "disabled"}:
            fail(f"{context}: registry.status must be active or disabled")
        if registry.get("enabled") not in {"yes", "no"}:
            fail(f"{context}: registry.enabled must be yes or no")
        if registry.get("sync_mode") not in {"fetch", "pull", "manual"}:
            fail(f"{context}: registry.sync_mode must be fetch, pull, or manual")
        if registry.get("intake_policy") not in {"adopt-first", "observe-first", "selective-adopt", "pilot-first"}:
            fail(f"{context}: invalid registry.intake_policy")

        gitmodules = changes.get("gitmodules", {})
        for key in ("name", "path", "url"):
            if not non_empty_string(gitmodules.get(key)):
                fail(f"{context}: planned_changes.gitmodules.{key} is required")
        if gitmodules.get("path", "").startswith("agent-dev-kit"):
            fail(f"{context}: gitmodules.path must not target agent-dev-kit")
        if gitmodules.get("materialization") not in {"metadata-only", "local-submodule"}:
            fail(f"{context}: planned_changes.gitmodules.materialization must be metadata-only or local-submodule")

        matrix = changes.get("adoption_matrix", {})
        for key in ("date", "source_repo", "category", "capability", "decision", "state", "target", "evidence"):
            if not non_empty_string(matrix.get(key)):
                fail(f"{context}: planned_changes.adoption_matrix.{key} is required")
        if matrix.get("decision") not in {"adopt", "observe", "reject"}:
            fail(f"{context}: adoption_matrix.decision must be adopt, observe, or reject")
        if matrix.get("state") not in {"done", "pending", "blocked"}:
            fail(f"{context}: adoption_matrix.state must be done, pending, or blocked")

    rollback = plan.get("rollback")
    if not isinstance(rollback, dict):
        fail(f"{context}: rollback must be an object")
    else:
        files = rollback.get("files")
        commands = rollback.get("commands")
        if not isinstance(files, list) or not files:
            fail(f"{context}: rollback.files must be a non-empty array")
        elif any(item not in allowed_apply_targets for item in files):
            fail(f"{context}: rollback.files contains unsupported targets")
        if not isinstance(commands, list) or not commands:
            fail(f"{context}: rollback.commands must be a non-empty array")
        elif any(not isinstance(item, str) or not item.startswith("rtk ") for item in commands):
            fail(f"{context}: rollback.commands must be rtk-prefixed strings")

    stats["plans"] += 1
    return len(failures) == before if expect_pass else len(failures) > before


validate_policy()

for plan in explicit_plans:
    validate_plan(os.path.abspath(plan), expect_pass=True)

if not explicit_plans:
    for path in sorted(glob.glob(os.path.join(root, "reports/oss-onboarding-plan-*.json"))):
        validate_plan(path, expect_pass=True)

if check_fixtures:
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/registration/pass/*.json"))):
        before = len(failures)
        validate_plan(path, expect_pass=True)
        if len(failures) == before:
            stats["pass_fixtures"] += 1
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/registration/fail/*.json"))):
        before = len(failures)
        validate_plan(path, expect_pass=False)
        if len(failures) == before:
            fail(f"{rel(path)}: fail fixture unexpectedly passed")
        else:
            del failures[before:]
            stats["fail_fixtures"] += 1

if failures:
    if summary_json:
        print(json.dumps({"status": "fail", "failures": len(failures), **stats}, ensure_ascii=False))
    print("[FAIL] oss registration plan checks failed", file=sys.stderr)
    for item in failures[:20]:
        print(f"  - {item}", file=sys.stderr)
    if len(failures) > 20:
        print(f"  - ... {len(failures) - 20} more", file=sys.stderr)
    sys.exit(2)

if summary_json:
    print(json.dumps({"status": "pass", "failures": 0, **stats}, ensure_ascii=False))
else:
    print(
        "[PASS] oss registration P2 checks healthy: "
        f"manifests={stats['manifests']} plans={stats['plans']} "
        f"pass_fixtures={stats['pass_fixtures']} fail_fixtures={stats['fail_fixtures']}"
    )
PY
