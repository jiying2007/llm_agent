#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

awk -F'|' '
function trim(s) {
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  return s
}

/^\| [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] \|/ {
  category = trim($4)
  decision = trim($9)
  status = trim($10)
  evidence = trim($12)
  row = $0

  if (category == "delivery" && decision == "adopt" && status == "done") {
    checked++

    if (evidence == "") {
      printf("[FAIL] delivery adopt row has empty evidence:\n%s\n", row) > "/dev/stderr"
      failed = 1
    }
  }
}

END {
  if (checked == 0) {
    print "[FAIL] no delivery+adopt+done rows checked in adoption-matrix" > "/dev/stderr"
    exit 2
  }

  if (failed) {
    exit 3
  }

  printf("[PASS] delivery adopt depth checks passed (%d rows)\n", checked)
}
' "${MATRIX}"
