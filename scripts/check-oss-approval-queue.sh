#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUMMARY_JSON=0
FIXTURES=1
QUEUES=()

usage() {
  cat <<USAGE
usage: scripts/check-oss-approval-queue.sh [root] [--queue FILE] [--no-fixtures] [--summary-json]

Validates OSS intake approval queue policy and report-only queue artifacts.
The check is offline and read-only. It does not approve, apply, register, remove, absorb, commit, or push.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --queue)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --queue requires a file path" >&2
        exit 1
      }
      QUEUES+=("$2")
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

python3 - "$ROOT" "$SUMMARY_JSON" "$FIXTURES" "${QUEUES[@]}" <<'PY'
import glob
import json
import os
import re
import sys
from collections import Counter

root = os.path.abspath(sys.argv[1])
summary_json = sys.argv[2] == "1"
check_fixtures = sys.argv[3] == "1"
explicit_queues = sys.argv[4:]

allowed_types = {"candidate-review", "candidate-registration-apply", "subrepo-removal-apply", "cycle-gate-review"}
allowed_levels = {"L1-plan-review", "L2-metadata-apply", "L3-destructive-or-live-apply"}
blocked_auto_actions = {
    "network discovery",
    "candidate registration apply",
    "subrepo removal apply",
    "ADK absorption",
    "source-to-live apply",
    "commit",
    "push",
}
dangerous_fragments = [
    "--apply",
    " git rm",
    "git rm",
    "submodule deinit",
    "rm -rf",
    "reset --hard",
    "push",
]
failures = []
stats = {"manifests": 0, "queues": 0, "items": 0, "pass_fixtures": 0, "fail_fixtures": 0}


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


def safe_rel_path(value):
    return isinstance(value, str) and value and not value.startswith("/") and ".." not in value.split("/")


def validate_policy():
    path = os.path.join(root, "manifests/oss_intake_approval_queue.json")
    if not os.path.isfile(path):
        fail("missing manifest: manifests/oss_intake_approval_queue.json")
        return
    try:
        policy = read_json(path)
    except Exception as exc:
        fail(f"invalid JSON in manifests/oss_intake_approval_queue.json: {exc}")
        return
    stats["manifests"] += 1
    if policy.get("status") != "gated-approval":
        fail("oss_intake_approval_queue.json status must be gated-approval")
    if policy.get("default_mode") != "report-only":
        fail("oss_intake_approval_queue.json default_mode must be report-only")
    if set(policy.get("approval_levels", [])) != allowed_levels:
        fail("oss_intake_approval_queue.json approval_levels mismatch")
    if set(policy.get("item_types", [])) != allowed_types:
        fail("oss_intake_approval_queue.json item_types mismatch")
    if not blocked_auto_actions.issubset(set(policy.get("blocked_auto_actions", []))):
        fail("oss_intake_approval_queue.json blocked_auto_actions missing required entries")
    rules = policy.get("rules", {})
    for key in (
        "queue_must_be_report_only",
        "queue_items_require_evidence",
        "queue_items_require_recommended_next_step",
        "queue_must_not_execute_apply",
        "queue_must_not_modify_registry",
        "queue_must_not_modify_gitmodules",
        "queue_must_not_modify_agent_dev_kit",
    ):
        if rules.get(key) is not True:
            fail(f"oss_intake_approval_queue.json rules.{key} must be true")


def validate_queue(path, expect_pass=True):
    before = len(failures)
    if not os.path.isfile(path):
        fail(f"missing approval queue: {rel(path)}")
        return False
    try:
        queue = read_json(path)
    except Exception as exc:
        fail(f"{rel(path)}: invalid JSON: {exc}")
        return False
    context = rel(path)
    if queue.get("schema_version") != 1:
        fail(f"{context}: schema_version must be 1")
    if queue.get("mode") != "report-only":
        fail(f"{context}: mode must be report-only")
    if queue.get("status") not in {"empty", "needs-approval", "blocked"}:
        fail(f"{context}: status must be empty, needs-approval, or blocked")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(queue.get("date", ""))):
        fail(f"{context}: date must be YYYY-MM-DD")
    items = queue.get("items")
    if not isinstance(items, list):
        fail(f"{context}: items must be an array")
        items = []
    seen = set()
    type_counts = Counter()
    level_counts = Counter()
    for item in items:
        item_id = item.get("id")
        if not isinstance(item_id, str) or not item_id:
            fail(f"{context}: item.id is required")
        elif item_id in seen:
            fail(f"{context}: duplicate item id: {item_id}")
        else:
            seen.add(item_id)
        item_type = item.get("type")
        level = item.get("approval_level")
        if item_type not in allowed_types:
            fail(f"{context}: invalid item type: {item_type}")
        else:
            type_counts[item_type] += 1
        if level not in allowed_levels:
            fail(f"{context}: invalid approval level: {level}")
        else:
            level_counts[level] += 1
        if item.get("status") not in {"pending-approval", "blocked", "approved", "rejected"}:
            fail(f"{context}: invalid item status for {item_id}")
        for key in ("repo", "reason", "recommended_next_step"):
            if not isinstance(item.get(key), str) or not item.get(key).strip():
                fail(f"{context}: item.{key} is required for {item_id}")
        evidence = item.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            fail(f"{context}: evidence must be non-empty for {item_id}")
        elif any(not safe_rel_path(value) for value in evidence):
            fail(f"{context}: evidence contains unsafe paths for {item_id}")
        blocked = set(item.get("blocked_auto_actions", []))
        if not blocked:
            fail(f"{context}: blocked_auto_actions must be non-empty for {item_id}")
        if item_type == "candidate-registration-apply" and "candidate registration apply" not in blocked:
            fail(f"{context}: candidate registration item must block apply for {item_id}")
        if item_type == "candidate-review" and "candidate registration apply" not in blocked:
            fail(f"{context}: candidate review item must block apply for {item_id}")
        if item_type == "subrepo-removal-apply" and "subrepo removal apply" not in blocked:
            fail(f"{context}: removal item must block apply for {item_id}")
        next_step = item.get("recommended_next_step", "")
        if any(fragment in next_step for fragment in dangerous_fragments):
            fail(f"{context}: recommended_next_step contains an apply/destructive command for {item_id}")

    summary = queue.get("summary")
    if not isinstance(summary, dict):
        fail(f"{context}: summary must be an object")
    else:
        if summary.get("items") != len(items):
            fail(f"{context}: summary.items must equal item count")
        if summary.get("by_type", {}) != dict(type_counts):
            fail(f"{context}: summary.by_type mismatch")
        if summary.get("by_level", {}) != dict(level_counts):
            fail(f"{context}: summary.by_level mismatch")
    if queue.get("status") == "empty" and items:
        fail(f"{context}: empty queue must not contain items")
    if queue.get("status") == "needs-approval" and not items:
        fail(f"{context}: needs-approval queue must contain items")

    stats["queues"] += 1
    stats["items"] += len(items)
    return len(failures) == before if expect_pass else len(failures) > before


validate_policy()

for queue in explicit_queues:
    validate_queue(os.path.abspath(queue), expect_pass=True)

if not explicit_queues:
    for path in sorted(glob.glob(os.path.join(root, "reports/oss-intake-approval-queue-*.json"))):
        validate_queue(path, expect_pass=True)

if check_fixtures:
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/approval-queue/pass/*.json"))):
        before = len(failures)
        validate_queue(path, expect_pass=True)
        if len(failures) == before:
            stats["pass_fixtures"] += 1
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/approval-queue/fail/*.json"))):
        before = len(failures)
        validate_queue(path, expect_pass=False)
        if len(failures) == before:
            fail(f"{rel(path)}: fail fixture unexpectedly passed")
        else:
            del failures[before:]
            stats["fail_fixtures"] += 1

if failures:
    if summary_json:
        print(json.dumps({"status": "fail", "failures": len(failures), **stats}, ensure_ascii=False))
    print("[FAIL] oss approval queue checks failed", file=sys.stderr)
    for item in failures[:20]:
        print(f"  - {item}", file=sys.stderr)
    if len(failures) > 20:
        print(f"  - ... {len(failures) - 20} more", file=sys.stderr)
    sys.exit(2)

if summary_json:
    print(json.dumps({"status": "pass", "failures": 0, **stats}, ensure_ascii=False))
else:
    print(
        "[PASS] oss approval queue checks healthy: "
        f"manifests={stats['manifests']} queues={stats['queues']} items={stats['items']} "
        f"pass_fixtures={stats['pass_fixtures']} fail_fixtures={stats['fail_fixtures']}"
    )
PY
