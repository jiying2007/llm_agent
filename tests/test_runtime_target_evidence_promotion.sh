#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

COLLECTOR="${ROOT}/scripts/collect-runtime-target-evidence-package.sh"
CHECKER="${ROOT}/scripts/check-runtime-target-evidence-index.sh"

promote_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/runs/20260709T000002Z"
canonical_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home"
candidate_promote_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home/runs/20260709T000003Z"
candidate_canonical_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

show_file_head() {
  local file="$1"
  sed -n '1,80p' "${file}" >&2 || true
}

assert_contains() {
  local file="$1"
  local token="$2"
  local message="$3"
  if ! rg -q --fixed-strings -- "${token}" "${file}"; then
    echo "[FAIL] ${message}" >&2
    show_file_head "${file}"
    exit 1
  fi
}

assert_file() {
  local file="$1"
  local message="$2"
  if [[ ! -f "${file}" ]]; then
    fail "${message}"
  fi
}

assert_canonical_artifacts() {
  local dir="$1"
  local label="$2"
  for artifact in evidence-index.jsonl evidence-index.md current-status.md; do
    assert_file "${dir}/${artifact}" "${label} missing canonical artifact: ${artifact}"
  done
}

snapshot_canonical() {
  cp "${canonical_dir}/evidence-index.jsonl" "${canonical_before}"
  cp "${canonical_dir}/evidence-index.md" "${canonical_md_before}"
  cp "${canonical_dir}/current-status.md" "${current_status_before}"
}

assert_canonical_unchanged() {
  local label="$1"
  if ! cmp -s "${canonical_before}" "${canonical_dir}/evidence-index.jsonl" || ! cmp -s "${canonical_md_before}" "${canonical_dir}/evidence-index.md" || ! cmp -s "${current_status_before}" "${canonical_dir}/current-status.md"; then
    fail "${label} changed canonical artifacts"
  fi
}

"${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000002Z --out-dir "${promote_dir}" --promote-current --summary-json >"${TMP_DIR}/promote-summary.json"

assert_contains "${TMP_DIR}/promote-summary.json" '"promoted":true' "promote-current summary did not report promoted=true"
assert_canonical_artifacts "${canonical_dir}" "promote-current"
assert_contains "${canonical_dir}/current-status.md" "promotion_rule: canonical files are refreshed only after strict artifact validation passes." "current status does not record strict promotion rule"
assert_contains "${canonical_dir}/current-status.md" "no source-to-live apply, rollback or live-root write" "current status does not preserve report-only boundary"

"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${canonical_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

canonical_before="${TMP_DIR}/canonical-before.jsonl"
canonical_md_before="${TMP_DIR}/canonical-before.md"
current_status_before="${TMP_DIR}/current-status-before.md"
snapshot_canonical

escape_out="${TMP_DIR}/escape.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000004Z --out-dir "${TMP_DIR}/outside-evidence" --promote-current >"${escape_out}" 2>&1; then
  fail "promote-current unexpectedly allowed out-dir outside runtime-target-activation tree"
fi
assert_contains "${escape_out}" "--promote-current requires --out-dir under reports/runtime-target-activation/codex-home/" "promote-current out-dir escape failure was not explicit"
assert_canonical_unchanged "out-dir escape failure"

cross_target_out="${TMP_DIR}/cross-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000005Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/claude-code-home/cross-codex" --promote-current >"${cross_target_out}" 2>&1; then
  fail "promote-current unexpectedly allowed cross-target out-dir"
fi
assert_contains "${cross_target_out}" "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "promote-current cross-target failure was not explicit"
if [[ -e "${TMP_DIR}/reports/runtime-target-activation/claude-code-home/cross-codex" ]]; then
  fail "promote-current created cross-target package directory before validation"
fi
assert_canonical_unchanged "cross-target failure"

dotdot_out="${TMP_DIR}/dotdot-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000007Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home/../claude-code-home/dotdot-codex" --promote-current >"${dotdot_out}" 2>&1; then
  fail "promote-current unexpectedly allowed dotdot cross-target out-dir"
fi
assert_contains "${dotdot_out}" "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "promote-current dotdot failure was not explicit"

prefix_out="${TMP_DIR}/prefix-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000008Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home-evil/prefix-codex" --promote-current >"${prefix_out}" 2>&1; then
  fail "promote-current unexpectedly allowed similar-prefix target out-dir"
fi
assert_contains "${prefix_out}" "--promote-current --out-dir must stay under reports/runtime-target-activation/codex-home/" "promote-current similar-prefix failure was not explicit"

mkdir -p "${TMP_DIR}/outside-realpath"
ln -s "${TMP_DIR}/outside-realpath" "${canonical_dir}/symlink-runs"
symlink_out="${TMP_DIR}/symlink-target.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000009Z --out-dir "${canonical_dir}/symlink-runs/symlink-codex" --promote-current >"${symlink_out}" 2>&1; then
  fail "promote-current unexpectedly allowed symlink parent out-dir escape"
fi
assert_contains "${symlink_out}" "--promote-current --out-dir realpath must stay under reports/runtime-target-activation/codex-home/" "promote-current symlink escape failure was not explicit"
if [[ -e "${TMP_DIR}/outside-realpath/symlink-codex" ]]; then
  fail "promote-current created package through symlink escape"
fi
assert_canonical_unchanged "path escape failures"

bad_profile_out="${TMP_DIR}/bad-profile.out"
if "${COLLECTOR}" "${ROOT}" --target codex-home --profile missing-profile --timestamp 20260709T000006Z --out-dir "${TMP_DIR}/reports/runtime-target-activation/codex-home/bad-profile" --promote-current >"${bad_profile_out}" 2>&1; then
  fail "promote-current unexpectedly allowed failed evidence package"
fi
assert_contains "${bad_profile_out}" "current evidence was not promoted" "failed evidence package did not explain skipped promotion"
assert_canonical_unchanged "failed evidence package"

strict_fail_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/strict-fail"
strict_fail_out="${TMP_DIR}/strict-fail.out"
if ADK_TEST_RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL=17 "${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000010Z --out-dir "${strict_fail_dir}" --promote-current >"${strict_fail_out}" 2>&1; then
  fail "promote-current unexpectedly allowed injected strict checker failure"
fi
assert_contains "${strict_fail_out}" "strict artifact validation failed; current evidence was not promoted" "injected strict checker failure did not explain skipped promotion"
assert_contains "${strict_fail_out}" "injected strict artifact failure" "injected strict checker output was not surfaced"
assert_file "${strict_fail_dir}/evidence-index.jsonl" "injected strict failure did not leave generated package for inspection"
"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${strict_fail_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null
assert_canonical_unchanged "injected strict checker failure"

"${COLLECTOR}" "${ROOT}" --target claude-code-home --timestamp 20260709T000003Z --out-dir "${candidate_promote_dir}" --promote-current --summary-json >"${TMP_DIR}/candidate-promote-summary.json"

assert_contains "${TMP_DIR}/candidate-promote-summary.json" '"promoted":true' "candidate promote-current summary did not report promoted=true"

if [[ -f "${candidate_promote_dir}/runtime-health.json" ]]; then
  fail "candidate promote-current should not run runtime health"
fi

assert_canonical_artifacts "${candidate_canonical_dir}" "candidate promote-current"
assert_contains "${candidate_canonical_dir}/current-status.md" "target_enabled: false" "candidate current status did not record target_enabled=false"
assert_contains "${candidate_canonical_dir}/current-status.md" "target_role: target-candidate" "candidate current status did not record target_role=target-candidate"
assert_contains "${candidate_canonical_dir}/current-status.md" "activation_ready: false" "candidate current status did not record activation_ready=false"
assert_contains "${candidate_canonical_dir}/current-status.md" "promotion never changes enabled state" "candidate current status did not preserve evidence-pointer boundary"

"${CHECKER}" "${TMP_DIR}" --target claude-code-home --index "${candidate_canonical_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

echo "[PASS] runtime target evidence promotion behaves as expected"
