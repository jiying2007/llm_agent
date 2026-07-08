#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DATE=""
LATEST_VALID=1
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      DATE="${2:-}"
      LATEST_VALID=0
      shift 2
      ;;
    --latest-valid)
      LATEST_VALID=1
      DATE=""
      shift
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-reference-dirty-triage.sh [root] [--date YYYY-MM-DD|--latest-valid] [--summary-json]

Checks that a reference dirty triage report exists and matches the known dirty
baseline. Defaults to the latest valid report. This gate is report-only and
does not modify subrepos.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${LATEST_VALID}" -eq 0 ]]; then
  JSON_REPORT="${ROOT}/reports/reference-dirty-triage-${DATE}.json"
else
  JSON_REPORT=""
fi

python3 - "$ROOT" "$JSON_REPORT" "$SUMMARY_JSON" <<'PY'
import json
import os
import glob
import datetime as dt
import sys

root, report_path, summary_json = sys.argv[1:4]
summary_json = summary_json == "1"
failures = []
today = dt.date.today().isoformat()

def load_report(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)

def validate(path, data):
    local_failures = []
    items = data.get("items") or []
    if data.get("schema_version") != 1:
        local_failures.append("schema_version must be 1")
    if data.get("mode") != "report-only":
        local_failures.append("mode must be report-only")
    if data.get("status") != "pass":
        local_failures.append(f"status must be pass, got {data.get('status')}")
    repos = {item.get("repo") for item in items}
    for repo in ("OpenSpec", "superpowers", "vibeflow"):
        if repo not in repos:
            local_failures.append(f"missing repo triage: {repo}")
    for item in items:
        repo = item.get("repo")
        if item.get("decision") != "known-dirty-review":
            local_failures.append(f"{repo} decision must be known-dirty-review")
        if item.get("fingerprint_matches") is not True:
            local_failures.append(f"{repo} fingerprint must match baseline")
        if item.get("expired") is not False:
            local_failures.append(f"{repo} baseline must not be expired")
        expires_on = item.get("expires_on") or ""
        if expires_on < today:
            local_failures.append(f"{repo} baseline expired as of {today}: {expires_on}")
    return local_failures

if not report_path:
    candidates = sorted(glob.glob(os.path.join(root, "reports", "reference-dirty-triage-*.json")), reverse=True)
    selected = None
    selected_data = None
    selected_failures = []
    for candidate in candidates:
        try:
            data = load_report(candidate)
        except Exception as exc:
            selected_failures = [f"invalid JSON in {os.path.relpath(candidate, root)}: {exc}"]
            continue
        candidate_failures = validate(candidate, data)
        if not candidate_failures:
            selected = candidate
            selected_data = data
            selected_failures = []
            break
        if not selected_failures:
            selected_failures = candidate_failures
    if selected:
        report_path = selected
        data = selected_data
    else:
        report_path = candidates[0] if candidates else os.path.join(root, "reports", "reference-dirty-triage-<none>.json")
        data = {}
        failures.extend(selected_failures or ["no valid reference dirty triage report found"])
elif not os.path.isfile(report_path):
    failures.append(f"missing report: {os.path.relpath(report_path, root)}")
    data = {}
else:
    data = load_report(report_path)

items = data.get("items") or []
if data:
    failures.extend(validate(report_path, data))

status = "pass" if not failures else "fail"
if summary_json:
    print(json.dumps({"status": status, "report": os.path.relpath(report_path, root), "items": len(items), "failures": failures}, ensure_ascii=False, separators=(",", ":")))
elif failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
else:
    print(f"[PASS] reference dirty triage ready: report={os.path.relpath(report_path, root)} items={len(items)}")

if failures:
    sys.exit(1)
PY
