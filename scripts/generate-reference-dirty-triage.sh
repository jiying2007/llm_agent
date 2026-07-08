#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT=""
JSON_OUT=""

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/generate-reference-dirty-triage.sh [root] [--out <md>] [--json-out <json>]

Generates a report-only triage of reference subrepos listed in
subrepos/dirty-baseline.tsv. It reads git status only and does not modify
reference repositories.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

python3 - "$ROOT" "$OUT" "$JSON_OUT" <<'PY'
import csv
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys

root, out_path, json_out_path = sys.argv[1:4]
baseline_path = os.path.join(root, "subrepos", "dirty-baseline.tsv")
today = dt.date.today().isoformat()

if not os.path.isfile(baseline_path):
    raise SystemExit(f"[FAIL] missing dirty baseline: {baseline_path}")


def git_lines(repo, args):
    proc = subprocess.run(["git", "-C", os.path.join(root, repo), *args], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode, proc.stdout.splitlines(), proc.stderr.strip()


def fingerprint(lines):
    payload = "\n".join(lines) + ("\n" if lines else "")
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


with open(baseline_path, "r", encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, delimiter="\t"))

items = []
for row in rows:
    repo = row["repo"]
    rc, status_lines, err = git_lines(repo, ["status", "--porcelain"])
    actual_count = len(status_lines) if rc == 0 else None
    actual_fingerprint = fingerprint(status_lines) if rc == 0 else None
    expected_count = int(row["change_count"])
    expected_fingerprint = row["status_fingerprint"]
    expires_on = row["expires_on"]
    matches = rc == 0 and actual_count == expected_count and actual_fingerprint == expected_fingerprint
    expired = expires_on < today
    decision = "known-dirty-review"
    if rc != 0:
        decision = "needs-investigation"
    elif expired:
        decision = "baseline-expired"
    elif not matches:
        decision = "baseline-drift"

    rc_head, head_lines, _ = git_lines(repo, ["rev-parse", "--short", "HEAD"])
    rc_branch, branch_lines, _ = git_lines(repo, ["branch", "--show-current"])
    sample = status_lines[:8]
    items.append({
        "repo": repo,
        "head": head_lines[0] if rc_head == 0 and head_lines else "-",
        "branch": branch_lines[0] if rc_branch == 0 and branch_lines else "-",
        "expected_state": row["expected_state"],
        "baseline_ref": row["baseline_ref"],
        "expected_count": expected_count,
        "actual_count": actual_count,
        "fingerprint_matches": matches,
        "expires_on": expires_on,
        "expired": expired,
        "owner": row["owner"],
        "reason": row["reason"],
        "decision": decision,
        "sample_status": sample,
        "error": err if rc != 0 else "",
    })

overall = "pass" if all(item["decision"] == "known-dirty-review" for item in items) else "needs-review"
record = {
    "schema_version": 1,
    "generated_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    "date": today,
    "mode": "report-only",
    "status": overall,
    "items": items,
    "boundary": "This report reads reference subrepo status only. It does not clean, reset, commit, push, sync, absorb, or modify live runtime assets.",
}

def write_json(path):
    if not path:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

def write_markdown(path):
    lines = [
        "# Reference Subrepo Dirty Triage",
        "",
        f"- generated_at: {record['generated_at']}",
        f"- date: {today}",
        f"- mode: {record['mode']}",
        f"- status: {overall}",
        "",
        "## Boundary",
        "",
        record["boundary"],
        "",
        "## Summary",
        "",
        "| Repo | Branch | Head | Decision | Count | Expires | Owner |",
        "|---|---|---|---|---:|---|---|",
    ]
    for item in items:
        lines.append(f"| {item['repo']} | {item['branch']} | {item['head']} | {item['decision']} | {item['actual_count']} | {item['expires_on']} | {item['owner']} |")
    lines.extend(["", "## Samples", ""])
    for item in items:
        lines.append(f"### {item['repo']}")
        lines.append("")
        lines.append(f"- baseline_ref: {item['baseline_ref']}")
        lines.append(f"- fingerprint_matches: {str(item['fingerprint_matches']).lower()}")
        lines.append(f"- reason: {item['reason']}")
        lines.append("- sample_status:")
        if item["sample_status"]:
            for sample in item["sample_status"]:
                lines.append(f"  - `{sample}`")
        else:
            lines.append("  - `-`")
        lines.append("")
    content = "\n".join(lines).rstrip() + "\n"
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)
    else:
        print(content, end="")

write_json(json_out_path)
write_markdown(out_path)
if out_path or json_out_path:
    print(f"[PASS] reference dirty triage written: md={out_path or '-'} json={json_out_path or '-'} status={overall}")
PY
