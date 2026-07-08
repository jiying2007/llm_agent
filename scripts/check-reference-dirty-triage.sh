#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DATE="$(date +%F)"
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      DATE="${2:-}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-reference-dirty-triage.sh [root] [--date YYYY-MM-DD] [--summary-json]

Checks that today's reference dirty triage report exists and matches the known
dirty baseline. This gate is report-only; it does not modify subrepos.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

JSON_REPORT="${ROOT}/reports/reference-dirty-triage-${DATE}.json"

python3 - "$ROOT" "$JSON_REPORT" "$SUMMARY_JSON" <<'PY'
import json
import os
import sys

root, report_path, summary_json = sys.argv[1:4]
summary_json = summary_json == "1"
failures = []

if not os.path.isfile(report_path):
    failures.append(f"missing report: {os.path.relpath(report_path, root)}")
    data = {}
else:
    with open(report_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)

items = data.get("items") or []
if data:
    if data.get("schema_version") != 1:
        failures.append("schema_version must be 1")
    if data.get("mode") != "report-only":
        failures.append("mode must be report-only")
    if data.get("status") != "pass":
        failures.append(f"status must be pass, got {data.get('status')}")
    repos = {item.get("repo") for item in items}
    for repo in ("OpenSpec", "superpowers", "vibeflow"):
        if repo not in repos:
            failures.append(f"missing repo triage: {repo}")
    for item in items:
        if item.get("decision") != "known-dirty-review":
            failures.append(f"{item.get('repo')} decision must be known-dirty-review")
        if item.get("fingerprint_matches") is not True:
            failures.append(f"{item.get('repo')} fingerprint must match baseline")
        if item.get("expired") is not False:
            failures.append(f"{item.get('repo')} baseline must not be expired")

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
