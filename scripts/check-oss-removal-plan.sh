#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUMMARY_JSON=0
FIXTURES=1
PLANS=()

usage() {
  cat <<USAGE
usage: scripts/check-oss-removal-plan.sh [root] [--plan FILE] [--no-fixtures] [--summary-json]

Validates P3 gated OSS subrepo removal plans.
The check is offline and read-only. It does not delete, unregister, absorb, or edit subrepos.
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
eligible_states = {"archive-only", "disabled"}
allowed_targets = {
    ".gitmodules",
    "subrepos/registry.csv",
    "subrepos/dirty-baseline.tsv",
    "manifests/subrepo_lifecycle.json",
    "docs/llm-agent-maintenance-guide.md",
    "docs/runbooks/oss-intake-lifecycle.md",
}
required_artifacts = [
    "adoption_decision",
    "evidence_dependency_scan",
    "dirty_baseline_review",
    "rollback_plan",
]
required_changes = ["gitmodules", "gitlink", "registry", "dirty_baseline", "lifecycle", "docs_reports"]
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


def non_empty_string(value):
    return isinstance(value, str) and bool(value.strip())


def safe_rel_path(path):
    return non_empty_string(path) and not path.startswith("/") and ".." not in path.split("/")


def validate_policy():
    path = os.path.join(root, "manifests/oss_removal_policy.json")
    if not os.path.isfile(path):
        fail("missing manifest: manifests/oss_removal_policy.json")
        return
    try:
        policy = read_json(path)
    except Exception as exc:
        fail(f"invalid JSON in manifests/oss_removal_policy.json: {exc}")
        return
    stats["manifests"] += 1
    if policy.get("status") != "gated-removal":
        fail("oss_removal_policy.json status must be gated-removal")
    if policy.get("default_mode") != "dry-run":
        fail("oss_removal_policy.json default_mode must be dry-run")
    if policy.get("required_gates") != required_gates:
        fail("oss_removal_policy.json required_gates mismatch")
    if set(policy.get("eligible_lifecycle_states", [])) != eligible_states:
        fail("oss_removal_policy.json eligible_lifecycle_states mismatch")
    if "agent-dev-kit" not in policy.get("protected_repositories", []):
        fail("oss_removal_policy.json must protect agent-dev-kit")
    rules = policy.get("rules", {})
    for key in (
        "default_must_be_dry_run",
        "apply_requires_explicit_flag",
        "apply_requires_confirmed_plan",
        "apply_must_not_touch_agent_dev_kit",
        "apply_must_not_delete_without_rollback",
        "apply_must_run_precheck_and_postcheck",
        "dirty_baseline_update_must_be_explicit",
    ):
        if rules.get(key) is not True:
            fail(f"oss_removal_policy.json rules.{key} must be true")


def validate_plan(path, expect_pass=True):
    before = len(failures)
    if not os.path.isfile(path):
        fail(f"missing removal plan: {rel(path)}")
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

    repo_obj = plan.get("repository")
    if not isinstance(repo_obj, dict):
        fail(f"{context}: repository must be an object")
    else:
        repo = repo_obj.get("repo")
        if not non_empty_string(repo) or "/" in repo or repo.startswith("."):
            fail(f"{context}: repository.repo must be a local subrepo name")
        if repo == "agent-dev-kit":
            fail(f"{context}: agent-dev-kit is protected")
        if repo_obj.get("lifecycle_state") not in eligible_states:
            fail(f"{context}: lifecycle_state must be archive-only or disabled")
        if repo_obj.get("protected") is not False:
            fail(f"{context}: repository.protected must be false")
        if repo_obj.get("active_core") is not False:
            fail(f"{context}: repository.active_core must be false")

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
            if not safe_rel_path(value):
                fail(f"{context}: required_artifacts.{key} must be a safe relative path")

    changes = plan.get("planned_changes")
    if not isinstance(changes, dict):
        fail(f"{context}: planned_changes must be an object")
    else:
        for key in required_changes:
            change = changes.get(key)
            if not isinstance(change, dict):
                fail(f"{context}: planned_changes.{key} must be an object")
                continue
            if not non_empty_string(change.get("action")):
                fail(f"{context}: planned_changes.{key}.action is required")
            path_value = change.get("path")
            if not safe_rel_path(path_value):
                fail(f"{context}: planned_changes.{key}.path must be a safe relative path")
            if key != "gitlink" and path_value not in allowed_targets and not re.fullmatch(r"reports/subrepo-removal-plan-[^/]+-\d{4}-\d{2}-\d{2}\.md", path_value or ""):
                fail(f"{context}: planned_changes.{key}.path is not an allowed apply target")

    for key in ("precheck", "postcheck"):
        value = plan.get(key)
        if not isinstance(value, dict) or value.get("command") != "rtk scripts/check-all.sh --quick":
            fail(f"{context}: {key}.command must be rtk scripts/check-all.sh --quick")

    rollback = plan.get("rollback")
    if not isinstance(rollback, dict):
        fail(f"{context}: rollback must be an object")
    else:
        files = rollback.get("files")
        commands = rollback.get("commands")
        if not isinstance(files, list) or not files:
            fail(f"{context}: rollback.files must be a non-empty array")
        elif any(item not in allowed_targets for item in files):
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
    for path in sorted(glob.glob(os.path.join(root, "reports/subrepo-removal-plan-*.json"))):
        validate_plan(path, expect_pass=True)

if check_fixtures:
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/removal/pass/*.json"))):
        before = len(failures)
        validate_plan(path, expect_pass=True)
        if len(failures) == before:
            stats["pass_fixtures"] += 1
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/removal/fail/*.json"))):
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
    print("[FAIL] oss removal plan checks failed", file=sys.stderr)
    for item in failures[:20]:
        print(f"  - {item}", file=sys.stderr)
    if len(failures) > 20:
        print(f"  - ... {len(failures) - 20} more", file=sys.stderr)
    sys.exit(2)

if summary_json:
    print(json.dumps({"status": "pass", "failures": 0, **stats}, ensure_ascii=False))
else:
    print(
        "[PASS] oss removal P3 checks healthy: "
        f"manifests={stats['manifests']} plans={stats['plans']} "
        f"pass_fixtures={stats['pass_fixtures']} fail_fixtures={stats['fail_fixtures']}"
    )
PY
