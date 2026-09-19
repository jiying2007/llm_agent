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
assert_collector_summary_failure "${target_required_summary}" "RUNTIME_TARGET_EVIDENCE_TARGET_REQUIRED" "target-required"

unknown_arg_summary="${TMP_DIR}/unknown-arg-summary.json"
if "${COLLECTOR}" "${ROOT}" --summary-json --bad-arg >"${unknown_arg_summary}" 2>"${TMP_DIR}/unknown-arg-summary.err"; then
  fail "unknown-arg collector summary unexpectedly passed"
fi
assert_collector_summary_failure "${unknown_arg_summary}" "RUNTIME_TARGET_EVIDENCE_UNKNOWN_ARG" "unknown-arg"

missing_manifest_root="${TMP_DIR}/missing-manifest-root"
mkdir -p "${missing_manifest_root}"
missing_manifest_summary="${TMP_DIR}/missing-manifest-summary.json"
if "${COLLECTOR}" "${missing_manifest_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/missing-manifest-out" >"${missing_manifest_summary}" 2>"${TMP_DIR}/missing-manifest-summary.err"; then
  fail "missing manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure "${missing_manifest_summary}" "RUNTIME_TARGET_EVIDENCE_RUNTIME_TARGETS_MANIFEST_MISSING" "missing manifest"

invalid_manifest_root="${TMP_DIR}/invalid-manifest-root"
mkdir -p "${invalid_manifest_root}/manifests"
printf '{bad json\n' >"${invalid_manifest_root}/manifests/runtime_targets.json"
invalid_manifest_summary="${TMP_DIR}/invalid-manifest-summary.json"
if "${COLLECTOR}" "${invalid_manifest_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/invalid-manifest-out" >"${invalid_manifest_summary}" 2>"${TMP_DIR}/invalid-manifest-summary.err"; then
  fail "invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure "${invalid_manifest_summary}" "RUNTIME_TARGET_EVIDENCE_RUNTIME_TARGETS_MANIFEST_INVALID_JSON" "invalid manifest"

adapters_missing_root="${TMP_DIR}/adapters-missing-root"
mkdir -p "${adapters_missing_root}/manifests"
printf '{"targets":[{"id":"codex-home","health_adapter":"codex-global-health"}]}\n' >"${adapters_missing_root}/manifests/runtime_targets.json"
adapters_missing_summary="${TMP_DIR}/adapters-missing-summary.json"
if "${COLLECTOR}" "${adapters_missing_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/adapters-missing-out" >"${adapters_missing_summary}" 2>"${TMP_DIR}/adapters-missing-summary.err"; then
  fail "missing adapters manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure "${adapters_missing_summary}" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "missing health_adapters field"

adapters_invalid_root="${TMP_DIR}/adapters-invalid-root"
mkdir -p "${adapters_invalid_root}/manifests"
printf '{"targets":[{"id":"codex-home","health_adapter":"codex-global-health"}],"health_adapters":{}}\n' >"${adapters_invalid_root}/manifests/runtime_targets.json"
adapters_invalid_summary="${TMP_DIR}/adapters-invalid-summary.json"
if "${COLLECTOR}" "${adapters_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/adapters-invalid-out" >"${adapters_invalid_summary}" 2>"${TMP_DIR}/adapters-invalid-summary.err"; then
  fail "invalid adapters manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure "${adapters_invalid_summary}" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "invalid health_adapters field"

targets_top_invalid_root="${TMP_DIR}/targets-top-invalid-root"
mkdir -p "${targets_top_invalid_root}/manifests"
printf '[]\n' >"${targets_top_invalid_root}/manifests/runtime_targets.json"
targets_top_invalid_summary="${TMP_DIR}/targets-top-invalid-summary.json"
if "${COLLECTOR}" "${targets_top_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/targets-top-invalid-out" >"${targets_top_invalid_summary}" 2>"${TMP_DIR}/targets-top-invalid-summary.err"; then
  fail "targets-top-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${targets_top_invalid_summary}" "${TMP_DIR}/targets-top-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "targets-top-invalid manifest"

adapters_top_invalid_root="${TMP_DIR}/adapters-top-invalid-root"
mkdir -p "${adapters_top_invalid_root}/manifests"
printf '{"targets":[{"id":"codex-home","health_adapter":"codex-global-health"}],"health_adapters":{}}\n' >"${adapters_top_invalid_root}/manifests/runtime_targets.json"
adapters_top_invalid_summary="${TMP_DIR}/adapters-top-invalid-summary.json"
if "${COLLECTOR}" "${adapters_top_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/adapters-top-invalid-out" >"${adapters_top_invalid_summary}" 2>"${TMP_DIR}/adapters-top-invalid-summary.err"; then
  fail "adapters-top-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${adapters_top_invalid_summary}" "${TMP_DIR}/adapters-top-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "adapters-top-invalid manifest"

schema_invalid_root="${TMP_DIR}/schema-invalid-root"
mkdir -p "${schema_invalid_root}/manifests"
printf '{"targets":{}}\n' >"${schema_invalid_root}/manifests/runtime_targets.json"
schema_invalid_summary="${TMP_DIR}/schema-invalid-summary.json"
if "${COLLECTOR}" "${schema_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/schema-invalid-out" >"${schema_invalid_summary}" 2>"${TMP_DIR}/schema-invalid-summary.err"; then
  fail "schema-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${schema_invalid_summary}" "${TMP_DIR}/schema-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "schema-invalid manifest"

targets_entry_invalid_root="${TMP_DIR}/targets-entry-invalid-root"
mkdir -p "${targets_entry_invalid_root}/manifests"
printf '{"targets":["not-object"]}\n' >"${targets_entry_invalid_root}/manifests/runtime_targets.json"
targets_entry_invalid_summary="${TMP_DIR}/targets-entry-invalid-summary.json"
if "${COLLECTOR}" "${targets_entry_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/targets-entry-invalid-out" >"${targets_entry_invalid_summary}" 2>"${TMP_DIR}/targets-entry-invalid-summary.err"; then
  fail "targets-entry-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${targets_entry_invalid_summary}" "${TMP_DIR}/targets-entry-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "targets-entry-invalid manifest"

adapters_schema_invalid_root="${TMP_DIR}/adapters-schema-invalid-root"
mkdir -p "${adapters_schema_invalid_root}/manifests"
printf '{"targets":[{"id":"codex-home","health_adapter":"codex-global-health"}],"health_adapters":{}}\n' >"${adapters_schema_invalid_root}/manifests/runtime_targets.json"
adapters_schema_invalid_summary="${TMP_DIR}/adapters-schema-invalid-summary.json"
if "${COLLECTOR}" "${adapters_schema_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/adapters-schema-invalid-out" >"${adapters_schema_invalid_summary}" 2>"${TMP_DIR}/adapters-schema-invalid-summary.err"; then
  fail "adapters-schema-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${adapters_schema_invalid_summary}" "${TMP_DIR}/adapters-schema-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "adapters-schema-invalid manifest"

adapters_entry_invalid_root="${TMP_DIR}/adapters-entry-invalid-root"
mkdir -p "${adapters_entry_invalid_root}/manifests"
printf '{"targets":[{"id":"codex-home","health_adapter":"codex-global-health"}],"health_adapters":["not-object"]}\n' >"${adapters_entry_invalid_root}/manifests/runtime_targets.json"
adapters_entry_invalid_summary="${TMP_DIR}/adapters-entry-invalid-summary.json"
if "${COLLECTOR}" "${adapters_entry_invalid_root}" --target codex-home --summary-json --out-dir "${TMP_DIR}/adapters-entry-invalid-out" >"${adapters_entry_invalid_summary}" 2>"${TMP_DIR}/adapters-entry-invalid-summary.err"; then
  fail "adapters-entry-invalid manifest collector summary unexpectedly passed"
fi
assert_collector_summary_failure_no_traceback "${adapters_entry_invalid_summary}" "${TMP_DIR}/adapters-entry-invalid-summary.err" "RUNTIME_TARGET_EVIDENCE_MANIFEST_SCHEMA_INVALID" "adapters-entry-invalid manifest"

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
assert_collector_summary_failure "${missing_summary}" "RUNTIME_TARGET_EVIDENCE_TARGET_NOT_DECLARED" "missing target"
assert_json_value "${missing_summary}" "message" '"runtime target not declared: missing-runtime-home"' "missing target collector summary did not include stable message"

echo "[PASS] runtime target evidence package collector behaves as expected"
