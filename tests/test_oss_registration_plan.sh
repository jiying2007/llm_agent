#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-oss-registration-plan.sh"
ONBOARD="${ROOT}/scripts/onboard-oss-candidate.sh"
TMP_JSON="$(mktemp)"
TMP_MD="$(mktemp)"
trap 'rm -f "${TMP_JSON}" "${TMP_MD}"' EXIT

for fixture in "${ROOT}"/fixtures/oss-intake/registration/pass/*.json; do
  "${CHECK}" "${ROOT}" --no-fixtures --plan "${fixture}" >/dev/null
done

for fixture in "${ROOT}"/fixtures/oss-intake/registration/fail/*.json; do
  if "${CHECK}" "${ROOT}" --no-fixtures --plan "${fixture}" >/dev/null 2>&1; then
    echo "[FAIL] fail fixture unexpectedly passed: ${fixture}" >&2
    exit 1
  fi
done

"${ONBOARD}" "${ROOT}" \
  --ledger "${ROOT}/reports/oss-discovery-candidates-2026-06-16.jsonl" \
  --repo example/runtime-policy-gates \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --out-json "${TMP_JSON}" \
  --out-md "${TMP_MD}" >/dev/null

"${CHECK}" "${ROOT}" --no-fixtures --plan "${TMP_JSON}" >/dev/null

if ! rg -q --fixed-strings "materialization" "${TMP_JSON}"; then
  echo "[FAIL] generated onboarding plan is missing materialization" >&2
  exit 1
fi

echo "[PASS] oss registration plan fixtures behave as expected"
