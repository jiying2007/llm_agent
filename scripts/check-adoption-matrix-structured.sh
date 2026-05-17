#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"
JSONL="${ROOT}/subrepos/adoption-matrix.jsonl"
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

[[ -f "${JSONL}" ]] || {
  echo "[FAIL] structured adoption matrix missing: ${JSONL}" >&2
  exit 1
}

"${ROOT}/scripts/export-adoption-matrix-jsonl.sh" "${ROOT}" "${TMP}" >/dev/null

if ! cmp -s "${TMP}" "${JSONL}"; then
  echo "[FAIL] adoption-matrix.jsonl is not synchronized with adoption-matrix.md" >&2
  echo "[INFO] regenerate with: rtk bash scripts/export-adoption-matrix-jsonl.sh" >&2
  exit 1
fi

bad_decisions="$(awk -F'"decision":"' 'NF > 1 {split($2,a,"\""); if (a[1]!="adopt" && a[1]!="observe" && a[1]!="reject") print NR ":" a[1]}' "${JSONL}")"
bad_states="$(awk -F'"state":"' 'NF > 1 {split($2,a,"\""); if (a[1]!="done" && a[1]!="pending" && a[1]!="blocked") print NR ":" a[1]}' "${JSONL}")"

if [[ -n "${bad_decisions}" ]]; then
  echo "[FAIL] invalid decisions in adoption-matrix.jsonl" >&2
  printf '%s\n' "${bad_decisions}" >&2
  exit 1
fi

if [[ -n "${bad_states}" ]]; then
  echo "[FAIL] invalid states in adoption-matrix.jsonl" >&2
  printf '%s\n' "${bad_states}" >&2
  exit 1
fi

md_count="$(awk -F'|' '/^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {count++} END{print count+0}' "${MATRIX}")"
json_count="$(wc -l < "${JSONL}" | tr -d ' ')"
[[ "${md_count}" == "${json_count}" ]] || {
  echo "[FAIL] adoption matrix count mismatch: md=${md_count} jsonl=${json_count}" >&2
  exit 1
}

echo "[PASS] structured adoption matrix synchronized"
