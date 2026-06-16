#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LEDGER=""
OUT=""

usage() {
  cat <<USAGE
usage: scripts/score-oss-candidates.sh [root] --ledger FILE [--out FILE]

Generates a report-only Markdown score report from a local OSS candidate JSONL ledger.
The command is offline and read-only except for the requested report output file.
It does not discover, clone, register, absorb, or remove repositories.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --ledger requires a file path" >&2
        exit 1
      }
      LEDGER="$2"
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --out requires a file path" >&2
        exit 1
      }
      OUT="$2"
      shift 2
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

[[ -n "${LEDGER}" ]] || {
  echo "[FAIL] --ledger is required" >&2
  exit 1
}

[[ -f "${LEDGER}" ]] || {
  echo "[FAIL] missing ledger: ${LEDGER}" >&2
  exit 1
}

"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${LEDGER}" >/dev/null

if [[ -z "${OUT}" ]]; then
  OUT="${ROOT}/reports/oss-score-report-$(date '+%Y-%m-%d').md"
fi

mkdir -p "$(dirname "${OUT}")"

python3 - "${ROOT}" "${LEDGER}" "${OUT}" <<'PY'
import json
import os
import sys
from collections import Counter

root = os.path.abspath(sys.argv[1])
ledger = os.path.abspath(sys.argv[2])
out = os.path.abspath(sys.argv[3])

rows = []
with open(ledger, "r", encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            rows.append(json.loads(line))

counter = Counter(row["decision"] for row in rows)
scored = [row for row in rows if row["score"] is not None]
unscored = [row for row in rows if row["score"] is None]

def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path

def cell(value):
    text = "" if value is None else str(value)
    return text.replace("|", "\\|")

lines = [
    "# OSS Score Report",
    "",
    "> Status: report-only",
    f"> Source ledger: `{rel(ledger)}`",
    "",
    "## Summary",
    "",
    f"- candidates: {len(rows)}",
    f"- scored: {len(scored)}",
    f"- unscored: {len(unscored)}",
]

for decision, count in sorted(counter.items()):
    lines.append(f"- {decision}: {count}")

lines.extend([
    "",
    "## Candidates",
    "",
    "| repo | domain_fit | score | decision | hard_rejects | reason |",
    "|---|---|---:|---|---|---|",
])

for row in sorted(rows, key=lambda item: (item["score"] is None, -(item["score"] or -1), item["repo"])):
    hard_rejects = ",".join(row["hard_rejects"])
    lines.append(
        "| {repo} | {domain_fit} | {score} | {decision} | {hard_rejects} | {reason} |".format(
            repo=cell(row["repo"]),
            domain_fit=cell(row["domain_fit"]),
            score=cell(row["score"]),
            decision=cell(row["decision"]),
            hard_rejects=cell(hard_rejects),
            reason=cell(row["reason"]),
        )
    )

lines.extend([
    "",
    "## Report-Only Boundary",
    "",
    "- This report does not register repositories.",
    "- This report does not update `.gitmodules`, `subrepos/registry.csv`, or `subrepos/adoption-matrix.md`.",
    "- `onboard-candidate` means eligible for later gated onboarding review, not automatic registration.",
    "",
])

with open(out, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))

print(f"[PASS] wrote OSS score report: {rel(out)} candidates={len(rows)} scored={len(scored)} unscored={len(unscored)}")
PY
