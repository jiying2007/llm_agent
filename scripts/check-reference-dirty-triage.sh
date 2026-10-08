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

PYTHONPATH="$ROOT/agent-dev-kit/src:$ROOT${PYTHONPATH:+:$PYTHONPATH}" python3 - "$ROOT" "$JSON_REPORT" "$SUMMARY_JSON" <<'PY'
import json
import os
import glob
import datetime as dt
import sys
import subprocess
import csv
from pathlib import Path
from tools.codex_assets.reference_worktree_identity import SCHEMA, snapshot, verify_review
from tools.codex_assets.intake_io import IntakeError, read_json

root, report_path, summary_json = sys.argv[1:4]
summary_json = summary_json == "1"
failures = []
today = dt.date.today().isoformat()
with open(os.path.join(root, "subrepos", "dirty-baseline.tsv"), encoding="utf-8", newline="") as handle:
    baselines = {row["repo"]: row for row in csv.DictReader(handle, delimiter="\t")}

def load_report(path):
    data = read_json(Path(path), label="reference triage report", max_bytes=512 * 1024)
    if not isinstance(data, dict):
        raise IntakeError("reference triage report must be an object")
    items = data.get("items", [])
    if not isinstance(items, list) or any(not isinstance(item, dict) for item in items):
        raise IntakeError("reference triage items must be objects")
    return data

report_dirs = {Path(root) / "reports"}
for baseline in baselines.values():
    record = baseline.get("review_record", "")
    if record:
        parent = (Path(root) / record).parent.resolve()
        if parent.is_relative_to(Path(root).resolve()):
            report_dirs.add(parent)

if report_path and not os.path.isfile(report_path):
    name = Path(report_path).name
    matches = sorted(str(directory / name) for directory in report_dirs if (directory / name).is_file())
    if len(matches) == 1:
        report_path = matches[0]

def validate(path, data):
    local_failures = []
    items = data.get("items") or []
    if data.get("schema_version") != 2:
        local_failures.append("schema_version must be 2")
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
        if item.get("classification_matches") is not True:
            local_failures.append(f"{repo} classification must match baseline")
        if item.get("analysis_policy") != "commit-snapshot-only":
            local_failures.append(f"{repo} analysis policy must be commit-snapshot-only")
        if not item.get("actual_classification"):
            local_failures.append(f"{repo} actual classification is required")
        for count_field in ("mode_changes", "content_changes", "type_changes", "untracked_changes", "staged_changes"):
            if not isinstance(item.get(count_field), int):
                local_failures.append(f"{repo} {count_field} must be an integer")
        if item.get("expired") is not False:
            local_failures.append(f"{repo} baseline must not be expired")
        expires_on = item.get("expires_on") or ""
        if expires_on < today:
            local_failures.append(f"{repo} baseline expired as of {today}: {expires_on}")
        baseline = baselines.get(repo, {})
        if (item.get("snapshot_schema") != SCHEMA or baseline.get("snapshot_schema") != SCHEMA
                or not baseline.get("snapshot_sha256") or not item.get("review_record")
                or item.get("review_record") != baseline.get("review_record")):
            local_failures.append(f"{repo} current content identity/review record required")
            continue
        try:
            verify_review(Path(root), str(repo), baseline["snapshot_sha256"], baseline["review_record"])
            identity = snapshot(Path(root), str(repo))
        except (OSError, ValueError, subprocess.TimeoutExpired):
            local_failures.append(f"{repo} current snapshot unavailable")
            continue
        if (identity["snapshot_sha256"] != baseline["snapshot_sha256"]
                or identity["snapshot_sha256"] != item.get("snapshot_sha256")):
            local_failures.append(f"{repo} current content identity does not match review")
        if baseline.get("expires_on", "") < today or item.get("expires_on") != baseline.get("expires_on"):
            local_failures.append(f"{repo} current baseline expiry does not match review")
        if item.get("source_approved") is not False or item.get("content_disposition") != "isolated-needs-review":
            local_failures.append(f"{repo} observed baseline must not approve reference content")
    return local_failures

if not report_path:
    candidates = sorted({str(path) for directory in report_dirs for path in directory.glob("reference-dirty-triage-*.json")}, key=lambda path: (Path(path).name, path), reverse=True)
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
    try:
        data = load_report(report_path)
    except IntakeError as exc:
        failures.append(str(exc))
        data = {}

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
