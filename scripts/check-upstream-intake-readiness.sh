#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

awk -F'|' '
  BEGIN { failed=0; checked=0 }
  /^\| 20/ {
    decision=$9
    status=$10
    target=$11
    evidence=$12
    gsub(/^ +| +$/, "", decision)
    gsub(/^ +| +$/, "", status)
    gsub(/^ +| +$/, "", target)
    gsub(/^ +| +$/, "", evidence)

    if (decision == "adopt" && status == "done") {
      checked++
      if (target !~ /agent-dev-kit|codex/) {
        print "[FAIL] adopt row missing production target:" $0 > "/dev/stderr"
        failed=1
      }
      if (evidence !~ /agent-dev-kit\/|reports\/|scripts\//) {
        print "[FAIL] adopt row missing local evidence:" $0 > "/dev/stderr"
        failed=1
      }
    }
  }
  END {
    if (checked == 0) {
      print "[FAIL] no adopt+done rows checked" > "/dev/stderr"
      exit 1
    }
    if (failed) {
      exit 1
    }
    printf("[PASS] upstream intake readiness checks passed (%d adopt rows)\n", checked)
  }
' "${MATRIX}"
