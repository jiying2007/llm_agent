#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/tests/helpers/runtime_target_evidence_test_lib.sh"
runtime_evidence_test_init "${ROOT}"
trap runtime_evidence_test_cleanup EXIT

codex_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/20260709T000000Z"
canonical_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home"
candidate_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home/20260709T000001Z"

target_required_summary="${TMP_DIR}/target-required-summary.json"
if "${COLLECTOR}" "${ROOT}" --summary-json >"${target_required_summary}" 2>"${TMP_DIR}/target-required-summary.err"; then
  fail "target-required collector summary unexpectedly passed"
fi
assert_json_value "${target_required_summary}" "status" '"fail"' "target-required collector summary did not report failure"
assert_json_value "${target_required_summary}" "error_code" '"RUNTIME_TARGET_EVIDENCE_TARGET_REQUIRED"' "target-required collector summary did not include stable error code"

unknown_arg_summary="${TMP_DIR}/unknown-arg-summary.json"
if "${COLLECTOR}" "${ROOT}" --summary-json --bad-arg >"${unknown_arg_summary}" 2>"${TMP_DIR}/unknown-arg-summary.err"; then
  fail "unknown-arg collector summary unexpectedly passed"
fi
assert_json_value "${unknown_arg_summary}" "status" '"fail"' "unknown-arg collector summary did not report failure"
assert_json_value "${unknown_arg_summary}" "error_code" '"RUNTIME_TARGET_EVIDENCE_UNKNOWN_ARG"' "unknown-arg collector summary did not include stable error code"

"${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000000Z --out-dir "${codex_dir}" --summary-json >"${TMP_DIR}/codex-summary.json"

assert_json_value "${TMP_DIR}/codex-summary.json" "status" '"pass"' "codex evidence package summary did not pass"
assert_json_value "${TMP_DIR}/codex-summary.json" "error_code" 'null' "codex evidence package pass summary did not include null error_code"
assert_json_value "${TMP_DIR}/codex-summary.json" "message" 'null' "codex evidence package pass summary did not include null message"

for artifact in evidence-index.jsonl evidence-index.md explain-target.json runtime-targets.json adapter-fixtures.md runtime-health.json footprint-policy.json; do
  assert_file "${codex_dir}/${artifact}" "codex evidence package missing artifact: ${artifact}"
done

"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${codex_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

if [[ -f "${canonical_dir}/evidence-index.jsonl" ]]; then
  fail "collector promoted canonical index without --promote-current"
fi

assert_jsonl_entry_value "${codex_dir}/evidence-index.jsonl" "CODEX-HOME-APPLY-001" "gate" '"apply"' "codex evidence package missing apply gate"
assert_jsonl_entry_value "${codex_dir}/evidence-index.jsonl" "CODEX-HOME-APPLY-001" "execution_status" '"blocked"' "codex evidence package missing blocked apply path"

"${COLLECTOR}" "${ROOT}" --target claude-code-home --timestamp 20260709T000001Z --out-dir "${candidate_dir}" --summary-json >"${TMP_DIR}/candidate-summary.json"

assert_json_value "${TMP_DIR}/candidate-summary.json" "status" '"pass"' "candidate evidence package summary did not pass"

assert_no_file "${candidate_dir}/runtime-health.json" "candidate evidence package should not run runtime health"

assert_jsonl_entry_value "${candidate_dir}/evidence-index.jsonl" "CLAUDE-CODE-HOME-HEALTH-001" "gate" '"health"' "candidate evidence package missing health gate"
assert_jsonl_entry_value "${candidate_dir}/evidence-index.jsonl" "CLAUDE-CODE-HOME-HEALTH-001" "result_summary" '"not executed: target or adapter is not active"' "candidate health gate did not record blocked reason"

"${CHECKER}" "${TMP_DIR}" --target claude-code-home --index "${candidate_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

missing_out="${TMP_DIR}/missing.out"
if "${COLLECTOR}" "${ROOT}" --target missing-runtime-home --out-dir "${TMP_DIR}/missing" >"${missing_out}" 2>&1; then
  fail "missing target evidence package unexpectedly passed"
fi
assert_contains "${missing_out}" "runtime target not declared: missing-runtime-home" "missing target collector did not explain failure"

missing_summary="${TMP_DIR}/missing-summary.json"
if "${COLLECTOR}" "${ROOT}" --target missing-runtime-home --out-dir "${TMP_DIR}/missing-summary" --summary-json >"${missing_summary}" 2>"${TMP_DIR}/missing-summary.err"; then
  fail "missing target evidence package summary unexpectedly passed"
fi
assert_json_value "${missing_summary}" "status" '"fail"' "missing target collector summary did not report failure"
assert_json_value "${missing_summary}" "error_code" '"RUNTIME_TARGET_EVIDENCE_TARGET_NOT_DECLARED"' "missing target collector summary did not include stable error code"
assert_json_value "${missing_summary}" "message" '"runtime target not declared: missing-runtime-home"' "missing target collector summary did not include stable message"

echo "[PASS] runtime target evidence package collector behaves as expected"
