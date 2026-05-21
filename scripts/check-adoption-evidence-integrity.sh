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
/^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {
  decision = trim($9)
  state = trim($10)
  evidence = trim($12)
  printf("%d|%s|%s|%s\n", NR, decision, state, evidence)
}
' "${MATRIX}" > "${tmp_rows}"

checked_rows=0
checked_paths=0

while IFS='|' read -r line_no decision state evidence; do
  if [[ "${state}" != "done" ]]; then
    continue
  fi
  checked_rows=$((checked_rows + 1))

  if [[ -z "${evidence}" ]]; then
    echo "[FAIL] done row has empty evidence (line ${line_no})" >&2
    exit 2
  fi

  while IFS= read -r item; do
    path="$(printf '%s' "${item}" | sed 's/^ *//;s/ *$//' | sed 's/#.*$//')"
    [[ -z "${path}" ]] && continue
    if [[ "${path}" == *"://"* ]]; then
      continue
    fi
    checked_paths=$((checked_paths + 1))
    if [[ ! -e "${ROOT}/${path}" && ! -e "${path}" ]]; then
      echo "[FAIL] evidence path missing (line ${line_no}): ${path}" >&2
      exit 3
    fi
  done < <(printf '%s\n' "${evidence}" | sed 's/;/\n/g')
done < "${tmp_rows}"

if [[ "${checked_rows}" -eq 0 ]]; then
  echo "[FAIL] no done rows found in adoption matrix" >&2
  exit 4
fi

echo "[PASS] adoption evidence integrity checks passed (rows=${checked_rows} paths=${checked_paths})"
