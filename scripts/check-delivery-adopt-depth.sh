#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

tmp_rows="$(mktemp)"
trap 'rm -f "${tmp_rows}"' EXIT

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
    } else {
      printf("%d|%s\n", NR, evidence)
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
}
' "${MATRIX}" > "${tmp_rows}"

if [[ -s "${tmp_rows}" ]]; then
  while IFS='|' read -r line_no evidence; do
    while IFS= read -r item; do
      path="$(printf '%s' "${item}" | sed 's/^ *//;s/ *$//' | sed 's/#.*$//')"
      [[ -z "${path}" ]] && continue
      if [[ ! -e "${ROOT}/${path}" && ! -e "${path}" ]]; then
        echo "[FAIL] delivery adopt evidence path missing (line ${line_no}): ${path}" >&2
        exit 3
      fi
    done < <(printf '%s\n' "${evidence}" | sed 's/;/\n/g')
  done < "${tmp_rows}"
fi

checked="$(wc -l < "${tmp_rows}" | tr -d ' ')"
echo "[PASS] delivery adopt depth checks passed (${checked} rows)"
