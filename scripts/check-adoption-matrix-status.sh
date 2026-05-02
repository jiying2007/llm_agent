#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

real_pending_lines="$(awk '
  /^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ && $0 ~ /\| pending \|/ {
    print NR ":" $0
  }
' "${MATRIX}")"

if [[ -n "${real_pending_lines}" ]]; then
  echo "[FAIL] adoption-matrix still has real pending rows:" >&2
  echo "${real_pending_lines}" >&2
  exit 2
fi

blocked_rows="$(awk '
  /^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ && $0 ~ /\| blocked \|/ {
    print NR ":" $0
  }
' "${MATRIX}")"

if [[ -n "${blocked_rows}" ]]; then
  while IFS= read -r row; do
    [[ -z "${row}" ]] && continue
    if ! printf "%s\n" "${row}" | rg -q '解除条件'; then
      echo "[FAIL] blocked row missing解除条件: ${row}" >&2
      exit 3
    fi
  done <<< "${blocked_rows}"
fi

echo "[PASS] adoption-matrix status checks passed"
