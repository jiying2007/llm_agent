#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-oss-intake-ledger.sh"
SCORE="${ROOT}/scripts/score-oss-candidates.sh"
TMP_REPORT="$(mktemp)"
trap 'rm -f "${TMP_REPORT}"' EXIT

for fixture in "${ROOT}"/fixtures/oss-intake/pass/*.jsonl; do
  "${CHECK}" "${ROOT}" --no-fixtures --fixture "${fixture}" >/dev/null
done

for fixture in "${ROOT}"/fixtures/oss-intake/fail/*.jsonl; do
  if "${CHECK}" "${ROOT}" --no-fixtures --fixture "${fixture}" >/dev/null 2>&1; then
    echo "[FAIL] fail fixture unexpectedly passed: ${fixture}" >&2
    exit 1
  fi
done

"${CHECK}" "${ROOT}" >/dev/null
"${SCORE}" "${ROOT}" --ledger "${ROOT}/reports/oss-discovery-candidates-2026-06-16.jsonl" --out "${TMP_REPORT}" >/dev/null

if ! rg -q --fixed-strings "Status: report-only" "${TMP_REPORT}"; then
  echo "[FAIL] score report is missing report-only status" >&2
  exit 1
fi

echo "[PASS] oss intake ledger fixtures behave as expected"
