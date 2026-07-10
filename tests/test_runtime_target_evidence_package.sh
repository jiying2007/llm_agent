#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/tests/helpers/runtime_target_evidence_test_lib.sh"
runtime_evidence_test_init "${ROOT}"
trap runtime_evidence_test_cleanup EXIT

codex_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home/20260709T000000Z"
canonical_dir="${TMP_DIR}/reports/runtime-target-activation/codex-home"
candidate_dir="${TMP_DIR}/reports/runtime-target-activation/claude-code-home/20260709T000001Z"

"${COLLECTOR}" "${ROOT}" --target codex-home --timestamp 20260709T000000Z --out-dir "${codex_dir}" --summary-json >"${TMP_DIR}/codex-summary.json"

assert_contains "${TMP_DIR}/codex-summary.json" '"status":"pass"' "codex evidence package summary did not pass"

for artifact in evidence-index.jsonl evidence-index.md explain-target.json runtime-targets.json adapter-fixtures.md runtime-health.json footprint-policy.json; do
  assert_file "${codex_dir}/${artifact}" "codex evidence package missing artifact: ${artifact}"
done

"${CHECKER}" "${TMP_DIR}" --target codex-home --index "${codex_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

if [[ -f "${canonical_dir}/evidence-index.jsonl" ]]; then
  fail "collector promoted canonical index without --promote-current"
fi

assert_contains "${codex_dir}/evidence-index.jsonl" '"evidence_id":"CODEX-HOME-APPLY-001"' "codex evidence package missing apply gate"
assert_contains "${codex_dir}/evidence-index.jsonl" '"execution_status":"blocked"' "codex evidence package missing blocked path"

"${COLLECTOR}" "${ROOT}" --target claude-code-home --timestamp 20260709T000001Z --out-dir "${candidate_dir}" --summary-json >"${TMP_DIR}/candidate-summary.json"

assert_contains "${TMP_DIR}/candidate-summary.json" '"status":"pass"' "candidate evidence package summary did not pass"

assert_no_file "${candidate_dir}/runtime-health.json" "candidate evidence package should not run runtime health"

assert_contains "${candidate_dir}/evidence-index.jsonl" '"evidence_id":"CLAUDE-CODE-HOME-HEALTH-001"' "candidate evidence package missing health gate"
assert_contains "${candidate_dir}/evidence-index.jsonl" '"result_summary":"not executed: target or adapter is not active"' "candidate health gate did not record blocked reason"

"${CHECKER}" "${TMP_DIR}" --target claude-code-home --index "${candidate_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

missing_out="${TMP_DIR}/missing.out"
if "${COLLECTOR}" "${ROOT}" --target missing-runtime-home --out-dir "${TMP_DIR}/missing" >"${missing_out}" 2>&1; then
  fail "missing target evidence package unexpectedly passed"
fi
assert_contains "${missing_out}" "runtime target not declared: missing-runtime-home" "missing target collector did not explain failure"

echo "[PASS] runtime target evidence package collector behaves as expected"
