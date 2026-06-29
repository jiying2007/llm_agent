#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"
CUTOFF_DATE="${ADK_TARGET_EVIDENCE_CUTOFF:-2026-06-29}"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

python3 - "$ROOT" "$MATRIX" "$CUTOFF_DATE" <<'PY'
import os
import re
import sys

root, matrix, cutoff = sys.argv[1:4]
failures = []
checked = 0

def clean_cell(value):
    return value.strip().strip("`")

def split_row(line):
    cells = [clean_cell(part) for part in line.strip().strip("|").split("|")]
    return cells if len(cells) >= 11 else []

def evidence_paths(evidence):
    for item in re.split(r"[;,]", evidence):
        item = item.strip().strip("`")
        if not item.startswith("agent-dev-kit/"):
            continue
        item = item.split("#", 1)[0].strip()
        if item:
            yield item

with open(matrix, "r", encoding="utf-8") as fh:
    for lineno, line in enumerate(fh, 1):
        if not line.startswith("| 20"):
            continue
        cells = split_row(line)
        if not cells:
            continue
        date, repo, _category, capability, _value, _cost, _risk, decision, state, target, evidence = cells[:11]
        if date < cutoff:
            continue
        if "agent-dev-kit" not in target:
            continue
        if state != "done" or decision not in {"adopt", "observe"}:
            continue
        checked += 1
        candidates = list(evidence_paths(evidence))
        existing = [path for path in candidates if os.path.exists(os.path.join(root, path))]
        if not existing:
            failures.append(
                f"line {lineno} repo={repo}: target includes agent-dev-kit but evidence has no existing agent-dev-kit/... path"
            )

if failures:
    print("[FAIL] adk target evidence checks failed", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    sys.exit(1)

print(f"[PASS] adk target evidence checks passed checked={checked} cutoff={cutoff}")
PY
