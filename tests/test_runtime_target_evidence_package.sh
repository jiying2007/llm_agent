#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

COLLECTOR="${ROOT}/scripts/collect-runtime-target-evidence-package.sh"
CHECKER="${ROOT}/scripts/check-runtime-target-evidence-index.sh"

codex_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/20260709T000000Z"
promote_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/runs/20260709T000002Z"
canonical_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home"
candidate_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home/20260709T000001Z"

"${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000000Z --out-dir "${codex_dir}" --summary-json >"${TMP_DIR}/codex-summary.json"

if ! rg -q --fixed-strings -- '"status":"pass"' "${TMP_DIR}/codex-summary.json"; then
  echo "[FAIL] codex evidence package summary did not pass" >&2
  sed -n '1,80p' "${TMP_DIR}/codex-summary.json" >&2 || true
  exit 1
fi

for artifact in evidence-index.jsonl evidence-index.md explain-target.json runtime-targets.json adapter-fixtures.md runtime-health.json footprint-policy.json; do
  if [[ ! -f "${codex_dir}/${artifact}" ]]; then
    echo "[FAIL] codex evidence package missing artifact: ${artifact}" >&2
    exit 1
  fi
done

"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${codex_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

if [[ -f "${canonical_dir}/evidence-index.jsonl" ]]; then
  echo "[FAIL] collector promoted canonical index without --promote-current" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"evidence_id":"CODEX-HOME-APPLY-001"' "${codex_dir}/evidence-index.jsonl"; then
  echo "[FAIL] codex evidence package missing apply gate" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"execution_status":"blocked"' "${codex_dir}/evidence-index.jsonl"; then
  echo "[FAIL] codex evidence package missing blocked path" >&2
  exit 1
fi

"${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000002Z --out-dir "${promote_dir}" --promote-current --summary-json >"${TMP_DIR}/promote-summary.json"

if ! rg -q --fixed-strings -- '"promoted":true' "${TMP_DIR}/promote-summary.json"; then
  echo "[FAIL] promote-current summary did not report promoted=true" >&2
  sed -n '1,80p' "${TMP_DIR}/promote-summary.json" >&2 || true
  exit 1
fi

for artifact in evidence-index.jsonl evidence-index.md current-status.md; do
  if [[ ! -f "${canonical_dir}/${artifact}" ]]; then
    echo "[FAIL] promote-current missing canonical artifact: ${artifact}" >&2
    exit 1
  fi
done

if ! rg -q --fixed-strings -- "promotion_rule: canonical files are refreshed only after strict artifact validation passes." "${canonical_dir}/current-status.md"; then
  echo "[FAIL] current status does not record strict promotion rule" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "no source-to-live apply, rollback or live-root write" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] current status does not preserve report-only boundary" >&2
  exit 1
fi

"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${canonical_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

"${COLLECTOR}" "${ROOT}" --target claude-code-home --timestamp 20260709T000001Z --out-dir "${candidate_dir}" --summary-json >"${TMP_DIR}/candidate-summary.json"

if ! rg -q --fixed-strings -- '"status":"pass"' "${TMP_DIR}/candidate-summary.json"; then
  echo "[FAIL] candidate evidence package summary did not pass" >&2
  sed -n '1,80p' "${TMP_DIR}/candidate-summary.json" >&2 || true
  exit 1
fi

if [[ -f "${candidate_dir}/runtime-health.json" ]]; then
  echo "[FAIL] candidate evidence package should not run runtime health" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"evidence_id":"CLAUDE-CODE-HOME-HEALTH-001"' "${candidate_dir}/evidence-index.jsonl"; then
  echo "[FAIL] candidate evidence package missing health gate" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"result_summary":"not executed: target or adapter is not active"' "${candidate_dir}/evidence-index.jsonl"; then
  echo "[FAIL] candidate health gate did not record blocked reason" >&2
  exit 1
fi

"${CHECKER}" "${TMP_DIR}" --target claude-code-home --index "${candidate_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

missing_out="${TMP_DIR}/missing.out"
if "${COLLECTOR}" "${ROOT}" --target missing-runtime-home --out-dir "${TMP_DIR}/missing" >"${missing_out}" 2>&1; then
  echo "[FAIL] missing target evidence package unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "runtime target not declared: missing-runtime-home" "${missing_out}"; then
  echo "[FAIL] missing target collector did not explain failure" >&2
  sed -n '1,80p' "${missing_out}" >&2 || true
  exit 1
fi

echo "[PASS] runtime target evidence package collector behaves as expected"
