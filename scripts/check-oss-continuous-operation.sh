#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUMMARY_JSON=0
FIXTURES=1
REPORTS=()

usage() {
  cat <<USAGE
usage: scripts/check-oss-continuous-operation.sh [root] [--report FILE] [--no-fixtures] [--summary-json]

Validates P4 OSS intake continuous-operation report-only contracts.
The check is offline and read-only. It does not fetch, register, remove, absorb, or apply assets.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --report requires a file path" >&2
        exit 1
      }
      REPORTS+=("$2")
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

python3 - "$ROOT" "$SUMMARY_JSON" "$FIXTURES" "${REPORTS[@]}" <<'PY'
import glob
import json
import os
import sys

root = os.path.abspath(sys.argv[1])
summary_json = sys.argv[2] == "1"
check_fixtures = sys.argv[3] == "1"
explicit_reports = sys.argv[4:]

required_commands = {
    "rtk scripts/check-oss-intake-ledger.sh .",
    "rtk scripts/check-oss-registration-plan.sh .",
    "rtk scripts/check-oss-removal-plan.sh .",
}
required_approvals = {
    "network discovery",
    "candidate registration apply",
    "subrepo removal apply",
    "ADK absorption",
    "source-to-live apply",
}
failures = []
stats = {"manifests": 0, "reports": 0, "pass_fixtures": 0, "fail_fixtures": 0}


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


def validate_manifest():
    path = os.path.join(root, "manifests/oss_continuous_operation.json")
    if not os.path.isfile(path):
        fail("missing manifest: manifests/oss_continuous_operation.json")
        return
    try:
        manifest = read_json(path)
    except Exception as exc:
        fail(f"invalid JSON in manifests/oss_continuous_operation.json: {exc}")
        return
    stats["manifests"] += 1
    if manifest.get("status") != "report-only":
        fail("oss_continuous_operation.json status must be report-only")
    if manifest.get("default_mode") != "report-only":
        fail("oss_continuous_operation.json default_mode must be report-only")
    commands = set(manifest.get("commands", []))
    missing = sorted(required_commands - commands)
    if missing:
        fail(f"oss_continuous_operation.json missing commands: {', '.join(missing)}")
    approvals = set(manifest.get("approval_points", []))
    missing_approvals = sorted(required_approvals - approvals)
    if missing_approvals:
        fail(f"oss_continuous_operation.json missing approval points: {', '.join(missing_approvals)}")
    if not manifest.get("stop_conditions"):
        fail("oss_continuous_operation.json stop_conditions must be non-empty")
    rules = manifest.get("rules", {})
    for key in (
        "cycle_must_be_report_only",
        "cycle_must_not_fetch_network",
        "cycle_must_not_modify_registry",
        "cycle_must_not_modify_gitmodules",
        "cycle_must_not_absorb_into_adk",
        "cycle_must_leave_auditable_report",
    ):
        if rules.get(key) is not True:
            fail(f"oss_continuous_operation.json rules.{key} must be true")


def validate_report(path, expect_pass=True):
    before = len(failures)
    if not os.path.isfile(path):
        fail(f"missing cycle report: {rel(path)}")
        return False
    try:
        report = read_json(path)
    except Exception as exc:
        fail(f"{rel(path)}: invalid JSON: {exc}")
        return False

    context = rel(path)
    if report.get("schema_version") != 1:
        fail(f"{context}: schema_version must be 1")
    if report.get("mode") != "report-only":
        fail(f"{context}: mode must be report-only")
    if report.get("status") not in {"pass", "fail"}:
        fail(f"{context}: status must be pass or fail")
    commands = report.get("commands")
    if not isinstance(commands, list) or not commands:
        fail(f"{context}: commands must be a non-empty array")
    else:
        got = {item.get("command") for item in commands if isinstance(item, dict)}
        missing = sorted(required_commands - got)
        if missing:
            fail(f"{context}: missing required commands: {', '.join(missing)}")
        for item in commands:
            if item.get("status") not in {"pass", "fail", "skipped"}:
                fail(f"{context}: command status must be pass, fail, or skipped")
    approvals = set(report.get("approval_required_before", []))
    missing_approvals = sorted(required_approvals - approvals)
    if missing_approvals:
        fail(f"{context}: missing approval boundaries: {', '.join(missing_approvals)}")
    outputs = report.get("outputs")
    if not isinstance(outputs, list) or not outputs:
        fail(f"{context}: outputs must be a non-empty array")
    elif any(not isinstance(item, str) or item.startswith("/") or ".." in item.split("/") for item in outputs):
        fail(f"{context}: outputs must be safe relative paths")

    stats["reports"] += 1
    return len(failures) == before if expect_pass else len(failures) > before


validate_manifest()

for report in explicit_reports:
    validate_report(os.path.abspath(report), expect_pass=True)

if not explicit_reports:
    for path in sorted(glob.glob(os.path.join(root, "reports/oss-intake-cycle-*.json"))):
        validate_report(path, expect_pass=True)

if check_fixtures:
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/continuous/pass/*.json"))):
        before = len(failures)
        validate_report(path, expect_pass=True)
        if len(failures) == before:
            stats["pass_fixtures"] += 1
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/continuous/fail/*.json"))):
        before = len(failures)
        validate_report(path, expect_pass=False)
        if len(failures) == before:
            fail(f"{rel(path)}: fail fixture unexpectedly passed")
        else:
            del failures[before:]
            stats["fail_fixtures"] += 1

if failures:
    if summary_json:
        print(json.dumps({"status": "fail", "failures": len(failures), **stats}, ensure_ascii=False))
    print("[FAIL] oss continuous-operation checks failed", file=sys.stderr)
    for item in failures[:20]:
        print(f"  - {item}", file=sys.stderr)
    if len(failures) > 20:
        print(f"  - ... {len(failures) - 20} more", file=sys.stderr)
    sys.exit(2)

if summary_json:
    print(json.dumps({"status": "pass", "failures": 0, **stats}, ensure_ascii=False))
else:
    print(
        "[PASS] oss continuous-operation P4 checks healthy: "
        f"manifests={stats['manifests']} reports={stats['reports']} "
        f"pass_fixtures={stats['pass_fixtures']} fail_fixtures={stats['fail_fixtures']}"
    )
PY
