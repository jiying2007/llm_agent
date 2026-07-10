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
candidate_promote_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home/runs/20260709T000003Z"
candidate_canonical_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home"

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

canonical_before="${TMP_DIR}/canonical-before.jsonl"
cp "${canonical_dir}/evidence-index.jsonl" "${canonical_before}"
canonical_md_before="${TMP_DIR}/canonical-before.md"
cp "${canonical_dir}/evidence-index.md" "${canonical_md_before}"
current_status_before="${TMP_DIR}/current-status-before.md"
cp "${canonical_dir}/current-status.md" "${current_status_before}"

escape_out="${TMP_DIR}/escape.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000004Z --out-dir "${TMP_DIR}/outside-evidence" --promote-current >"${escape_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed out-dir outside runtime-target-activation tree" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--promote-current requires --out-dir under reports/runtime-target-activation/codex-home/" "${escape_out}"; then
  echo "[FAIL] promote-current out-dir escape failure was not explicit" >&2
  sed -n '1,80p' "${escape_out}" >&2 || true
  exit 1
fi
if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl"; then
  echo "[FAIL] out-dir escape failure changed canonical evidence index" >&2
  exit 1
fi
if ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] out-dir escape failure changed canonical markdown/current status" >&2
  exit 1
fi

cross_target_out="${TMP_DIR}/cross-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000005Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/claude-code-home/cross-codex" --promote-current >"${cross_target_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed cross-target out-dir" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "${cross_target_out}"; then
  echo "[FAIL] promote-current cross-target failure was not explicit" >&2
  sed -n '1,80p' "${cross_target_out}" >&2 || true
  exit 1
fi
if [[ -e "${TMP_DIR}/reports/runtime-target-activation/claude-code-home/cross-codex" ]]; then
  echo "[FAIL] promote-current created cross-target package directory before validation" >&2
  exit 1
fi
if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl"; then
  echo "[FAIL] cross-target failure changed canonical evidence index" >&2
  exit 1
fi
if ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] cross-target failure changed canonical markdown/current status" >&2
  exit 1
fi

dotdot_out="${TMP_DIR}/dotdot-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000007Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home/../claude-code-home/dotdot-codex" --promote-current >"${dotdot_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed dotdot cross-target out-dir" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "${dotdot_out}"; then
  echo "[FAIL] promote-current dotdot failure was not explicit" >&2
  sed -n '1,80p' "${dotdot_out}" >&2 || true
  exit 1
fi

prefix_out="${TMP_DIR}/prefix-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000008Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home-evil/prefix-codex" --promote-current >"${prefix_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed similar-prefix target out-dir" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "${prefix_out}"; then
  echo "[FAIL] promote-current similar-prefix failure was not explicit" >&2
  sed -n '1,80p' "${prefix_out}" >&2 || true
  exit 1
fi

mkdir -p "${TMP_DIR}/outside-realpath"
ln -s "${TMP_DIR}/outside-realpath" "${canonical_dir}/symlink-runs"
symlink_out="${TMP_DIR}/symlink-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000009Z --out-dir "${canonical_dir}/symlink-runs/symlink-codex" --promote-current >"${symlink_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed symlink parent out-dir escape" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--promote-current --out-dir realpath must stay under reports/runtime-target-activation/codex-home/" "${symlink_out}"; then
  echo "[FAIL] promote-current symlink escape failure was not explicit" >&2
  sed -n '1,80p' "${symlink_out}" >&2 || true
  exit 1
fi
if [[ -e "${TMP_DIR}/outside-realpath/symlink-codex" ]]; then
  echo "[FAIL] promote-current created package through symlink escape" >&2
  exit 1
fi
if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl" || ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] path escape failures changed canonical artifacts" >&2
  exit 1
fi

bad_profile_out="${TMP_DIR}/bad-profile.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --profile missing-profile --timestamp 20260709T000006Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home/bad-profile" --promote-current >"${bad_profile_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed failed evidence package" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "current evidence was not promoted" "${bad_profile_out}"; then
  echo "[FAIL] failed evidence package did not explain skipped promotion" >&2
  sed -n '1,80p' "${bad_profile_out}" >&2 || true
  exit 1
fi
if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl"; then
  echo "[FAIL] failed evidence package changed canonical evidence index" >&2
  exit 1
fi
if ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] failed evidence package changed canonical markdown/current status" >&2
  exit 1
fi

strict_fail_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/strict-fail"
strict_fail_out="${TMP_DIR}/strict-fail.out"
if ADK_TEST_RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL=17 "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000010Z --out-dir "${strict_fail_dir}" --promote-current >"${strict_fail_out}" 2>&1; then
  echo "[FAIL] promote-current unexpectedly allowed injected strict checker failure" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "strict artifact validation failed; current evidence was not promoted" "${strict_fail_out}"; then
  echo "[FAIL] injected strict checker failure did not explain skipped promotion" >&2
  sed -n '1,80p' "${strict_fail_out}" >&2 || true
  exit 1
fi
if ! rg -q --fixed-strings -- "injected strict artifact failure" "${strict_fail_out}"; then
  echo "[FAIL] injected strict checker output was not surfaced" >&2
  sed -n '1,80p' "${strict_fail_out}" >&2 || true
  exit 1
fi
if [[ ! -f "${strict_fail_dir}/evidence-index.jsonl" ]]; then
  echo "[FAIL] injected strict failure did not leave generated package for inspection" >&2
  exit 1
fi
"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${strict_fail_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null
if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl" || ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
  echo "[FAIL] injected strict checker failure changed canonical artifacts" >&2
  exit 1
fi

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

"${COLLECTOR}" "${ROOT}" --target claude-code-home --timestamp 20260709T000003Z --out-dir "${candidate_promote_dir}" --promote-current --summary-json >"${TMP_DIR}/candidate-promote-summary.json"

if ! rg -q --fixed-strings -- '"promoted":true' "${TMP_DIR}/candidate-promote-summary.json"; then
  echo "[FAIL] candidate promote-current summary did not report promoted=true" >&2
  sed -n '1,80p' "${TMP_DIR}/candidate-promote-summary.json" >&2 || true
  exit 1
fi

if [[ -f "${candidate_promote_dir}/runtime-health.json" ]]; then
  echo "[FAIL] candidate promote-current should not run runtime health" >&2
  exit 1
fi

for artifact in evidence-index.jsonl evidence-index.md current-status.md; do
  if [[ ! -f "${candidate_canonical_dir}/${artifact}" ]]; then
    echo "[FAIL] candidate promote-current missing canonical artifact: ${artifact}" >&2
    exit 1
  fi
done

if ! rg -q --fixed-strings -- "target_enabled: false" "${candidate_canonical_dir}/current-status.md"; then
  echo "[FAIL] candidate current status did not record target_enabled=false" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "target_role: target-candidate" "${candidate_canonical_dir}/current-status.md"; then
  echo "[FAIL] candidate current status did not record target_role=target-candidate" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "activation_ready: false" "${candidate_canonical_dir}/current-status.md"; then
  echo "[FAIL] candidate current status did not record activation_ready=false" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "promotion never changes enabled state" "${candidate_canonical_dir}/current-status.md"; then
  echo "[FAIL] candidate current status did not preserve evidence-pointer boundary" >&2
  exit 1
fi

"${CHECKER}" "${TMP_DIR}" --target claude-code-home --index "${candidate_canonical_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

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
