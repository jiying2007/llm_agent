#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${2:-${ROOT}/subrepos/adoption-matrix.jsonl}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

[[ -f "${MATRIX}" ]] || {
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
}

mkdir -p "$(dirname "${OUT}")"

awk -F'|' '
function trim(value) {
  gsub(/^[ \t]+|[ \t]+$/, "", value)
  return value
}
function esc(value) {
  gsub(/\\/, "\\\\", value)
  gsub(/"/, "\\\"", value)
  gsub(/\t/, "\\t", value)
  return value
}
function field(idx) {
  return esc(trim($idx))
}
/^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {
  printf "{\"date\":\"%s\",\"repo\":\"%s\",\"category\":\"%s\",\"capability\":\"%s\",\"value\":\"%s\",\"cost\":\"%s\",\"risk\":\"%s\",\"decision\":\"%s\",\"state\":\"%s\",\"target\":\"%s\",\"evidence\":\"%s\"}\n",
    field(2), field(3), field(4), field(5), field(6), field(7), field(8), field(9), field(10), field(11), field(12)
}
' "${MATRIX}" > "${OUT}"

echo "[OK] adoption matrix jsonl exported: ${OUT}"
