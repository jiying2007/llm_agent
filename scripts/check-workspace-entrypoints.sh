#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WORKTREE_INTEGRATION=0
if [[ $# -gt 0 && "$1" != --* ]]; then
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree-integration) WORKTREE_INTEGRATION=1; shift ;;
    -h|--help)
      echo "usage: scripts/check-workspace-entrypoints.sh [root] [--worktree-integration]"
      exit 0
      ;;
    *) echo "[FAIL] unknown arg: $1" >&2; exit 2 ;;
  esac
done
TMP_DIR="$(mktemp -d)"
FAILURES=0
INITIAL_STATUS="${TMP_DIR}/initial-status.txt"
rtk git -C "${ROOT}" status --porcelain=v1 >"${INITIAL_STATUS}"
SAME_RUN_EVIDENCE_LIB="${ROOT}/scripts/lib/same-run-evidence.sh"
SAME_RUN_REUSE_READY=0
REUSE_FINGERPRINT_CACHE=""

if [[ -f "${SAME_RUN_EVIDENCE_LIB}" ]]; then
  # shellcheck source=scripts/lib/same-run-evidence.sh
  source "${SAME_RUN_EVIDENCE_LIB}"
fi

if [[ -n "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR:-}" \
  && -n "${LLM_AGENT_SAME_RUN_PRODUCER_PID:-}" \
  && -n "${LLM_AGENT_SAME_RUN_PRODUCER_START:-}" \
  && -n "${LLM_AGENT_SAME_RUN_REUSE_REPORT:-}" \
  && "${LLM_AGENT_SAME_RUN_PRODUCER_PID}" == "${PPID}" ]]; then
  current_parent_start=""
  if current_parent_start="$(llm_agent_process_start_token "${PPID}")" \
    && [[ "${current_parent_start}" == "${LLM_AGENT_SAME_RUN_PRODUCER_START}" ]]; then
    SAME_RUN_REUSE_READY=1
    export -n \
      LLM_AGENT_SAME_RUN_EVIDENCE_DIR \
      LLM_AGENT_SAME_RUN_PRODUCER_PID \
      LLM_AGENT_SAME_RUN_PRODUCER_START \
      LLM_AGENT_SAME_RUN_REUSE_REPORT
  fi
fi

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

record_fail() {
  echo "[FAIL] $*" >&2
  FAILURES=$((FAILURES + 1))
}

invalidate_reuse_fingerprint() {
  REUSE_FINGERPRINT_CACHE=""
}

run_check() {
  local name="$1"
  shift
  invalidate_reuse_fingerprint
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    echo "[PASS] ${name}"
  else
    record_fail "${name}"
    sed -n '1,40p' "${TMP_DIR}/${name}.err" >&2 || true
    sed -n '1,40p' "${TMP_DIR}/${name}.out" >&2 || true
  fi
}

run_expected_fail() {
  local name="$1"
  local expected="$2"
  shift 2
  invalidate_reuse_fingerprint
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    record_fail "${name} unexpectedly passed"
    sed -n '1,40p' "${TMP_DIR}/${name}.out" >&2 || true
  else
    if rg -q --fixed-strings -- "${expected}" "${TMP_DIR}/${name}.err" "${TMP_DIR}/${name}.out"; then
      echo "[PASS] ${name}"
    else
      record_fail "${name} failed without expected message: ${expected}"
      sed -n '1,40p' "${TMP_DIR}/${name}.err" >&2 || true
      sed -n '1,40p' "${TMP_DIR}/${name}.out" >&2 || true
    fi
  fi
}

try_same_run_reuse() {
  local consumer_name="$1"
  local producer_name="$2"
  local required_marker="${3:-}"
  local evidence_output=""

  [[ "${SAME_RUN_REUSE_READY}" -eq 1 ]] || return 1
  if [[ -z "${REUSE_FINGERPRINT_CACHE}" ]]; then
    REUSE_FINGERPRINT_CACHE="$(llm_agent_workspace_fingerprint "${ROOT}")" || {
      REUSE_FINGERPRINT_CACHE=""
      return 1
    }
  fi
  evidence_output="$(
    llm_agent_same_run_validate \
      "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR}" \
      "${LLM_AGENT_SAME_RUN_PRODUCER_PID}" \
      "${LLM_AGENT_SAME_RUN_PRODUCER_START}" \
      "${ROOT}" \
      "${REUSE_FINGERPRINT_CACHE}" \
      "${producer_name}" \
      "${ROOT}/scripts/${producer_name}" \
      "${required_marker}" \
      2>/dev/null
  )" || return 1
  [[ -f "${evidence_output}" ]] || return 1
  llm_agent_same_run_report_append \
    "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR}" \
    "${LLM_AGENT_SAME_RUN_REUSE_REPORT}" \
    "${consumer_name}" \
    "${producer_name}" \
    2>/dev/null || return 1
  echo "[REUSE] ${consumer_name} <- ${producer_name}"
}

run_check_or_reuse() {
  local consumer_name="$1"
  local producer_name="$2"
  local required_marker="$3"
  shift 3

  if try_same_run_reuse "${consumer_name}" "${producer_name}" "${required_marker}"; then
    return 0
  fi
  run_check "${consumer_name}" "$@"
}

assert_json_field() {
  local name="$1"
  local file="$2"
  local path="$3"
  local expected_json="$4"
  if python3 - "$file" "$path" "$expected_json" <<'PY'
import json
import sys

path, expected = sys.argv[2], json.loads(sys.argv[3])
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data
for part in path.split("."):
    value = value[part]
if value != expected:
    raise SystemExit(f"{path}: expected {expected!r}, got {value!r}")
PY
  then
    return 0
  fi
  record_fail "${name} json mismatch: ${path}"
}

run_check "devkit_help" "${ROOT}/scripts/devkit.sh" help
run_check "git_submodule_status" rtk git -C "${ROOT}" submodule status
health_args=()
[[ "${WORKTREE_INTEGRATION}" -eq 0 ]] || health_args+=(--worktree-integration)
run_check "devkit_health" "${ROOT}/scripts/devkit.sh" health "${health_args[@]}"
run_check "devkit_health_summary_json" "${ROOT}/scripts/devkit.sh" health --summary-json "${health_args[@]}"
run_check "devkit_sync_status" "${ROOT}/scripts/devkit.sh" sync status
run_check "phase_gate_summary_json" "${ROOT}/scripts/check-phase-gate.sh" "${ROOT}" --summary-json
run_check "runtime_targets_summary_json" "${ROOT}/scripts/check-runtime-targets.sh" "${ROOT}" --summary-json
run_check "runtime_target_explain_codex" "${ROOT}/scripts/check-runtime-targets.sh" "${ROOT}" --explain-target codex-home
run_check "runtime_target_explain_claude_code_candidate" "${ROOT}/scripts/check-runtime-targets.sh" "${ROOT}" --explain-target claude-code-home
run_check_or_reuse \
  "runtime_target_evidence_index" \
  "check-runtime-target-evidence-index.sh" \
  "" \
  "${ROOT}/scripts/check-runtime-target-evidence-index.sh" "${ROOT}"
run_check_or_reuse \
  "runtime_target_evidence_package" \
  "check-root-regression.sh" \
  "[PASS] test_runtime_target_evidence_package" \
  "${ROOT}/tests/test_runtime_target_evidence_package.sh"
run_check_or_reuse \
  "runtime_target_evidence_promotion" \
  "check-root-regression.sh" \
  "[PASS] test_runtime_target_evidence_promotion" \
  "${ROOT}/tests/test_runtime_target_evidence_promotion.sh"
run_check_or_reuse \
  "stale_references" \
  "check-stale-references.sh" \
  "" \
  "${ROOT}/scripts/check-stale-references.sh" "${ROOT}"
run_check_or_reuse \
  "pilot_evidence_wrapper" \
  "check-runtime-pilot-evidence.sh" \
  "" \
  "${ROOT}/scripts/check-runtime-pilot-evidence.sh" "${ROOT}"
run_check_or_reuse \
  "pilot_coverage_wrapper" \
  "check-runtime-pilot-coverage.sh" \
  "" \
  "${ROOT}/scripts/check-runtime-pilot-coverage.sh" "${ROOT}"
run_check "token_budget_summary_json" "${ROOT}/scripts/check-token-budget.sh" "${ROOT}" --summary-json
run_check "reference_dirty_triage_summary_json" "${ROOT}/scripts/check-reference-dirty-triage.sh" "${ROOT}" --summary-json
run_check "runtime_health_summary_json" "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --summary-json
run_expected_fail "runtime_health_claude_code_candidate_blocked" "runtime target is not enabled" "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --target claude-code-home --summary-json
run_expected_fail "runtime_health_hermes_agent_candidate_blocked" "runtime target is not enabled" "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --target hermes-agent-home --summary-json
run_expected_fail "runtime_health_opencode_candidate_blocked" "runtime target is not enabled" "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --target opencode-home --summary-json
run_check "runtime_live_footprint_summary_json" "${ROOT}/scripts/check-runtime-live-footprint.sh" "${ROOT}" --summary-json
run_check "runtime_control_snapshot" rtk bash "${HOME}/codex/scripts/runtime-control.sh" snapshot
if "${ROOT}/scripts/check-subrepo-state.sh" "${ROOT}" --summary-json >"${TMP_DIR}/subrepo_state_summary_json.out" 2>"${TMP_DIR}/subrepo_state_summary_json.err"; then
  echo "[PASS] subrepo_state_summary_json"
else
  echo "[PASS] subrepo_state_summary_json_contract"
fi
run_check "evidence_bundle_json" "${ROOT}/scripts/evidence-bundle.sh" "${ROOT}" --format json
run_check "governance_health_json" "${ROOT}/scripts/governance-health.sh" "${ROOT}" --format json
run_check "governance_review_json" "${ROOT}/scripts/governance-review.sh" "${ROOT}" --format json

weekly_report="${TMP_DIR}/weekly.md"
run_check "weekly_report" "${ROOT}/scripts/generate-weekly-report.sh" "${ROOT}" --output "${weekly_report}"
if [[ -f "${weekly_report}" ]]; then
  if ! rg -q '\*\*综合状态: PASS\*\*' "${weekly_report}"; then
    record_fail "weekly report gate status is not PASS"
  fi
  if rg -q 'intake_policy.*,[SABCDX]' "${weekly_report}"; then
    record_fail "weekly report leaked grade into intake_policy"
  fi
else
  record_fail "weekly report output missing"
fi

if [[ -f "${TMP_DIR}/devkit_health_summary_json.out" ]]; then
  if ! rg -q '"status":"pass"' "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json is not pass"
  fi
  expected_gate_mode="release"
  [[ "${WORKTREE_INTEGRATION}" -eq 0 ]] || expected_gate_mode="working-tree"
  if ! rg -q "\"gate_mode\":\"${expected_gate_mode}\"" "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json missing expected gate mode"
  fi
  if ! rg -q '"adk_lock_state":"ok"' "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json missing ok adk lock state"
  fi
  if ! rg -q '"active_repos":' "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json missing active repo count"
  fi
  for field in root_script_files root_manifest_files root_report_files adk_agents adk_core_skills adk_optional_skills adk_profiles adk_workflows adk_test_files adk_manifest_files; do
    if ! rg -q "\"${field}\":" "${TMP_DIR}/devkit_health_summary_json.out"; then
      record_fail "health summary json missing dynamic inventory field: ${field}"
    fi
  done
fi

if [[ -f "${TMP_DIR}/phase_gate_summary_json.out" ]]; then
  if ! rg -q '"status":"pass"' "${TMP_DIR}/phase_gate_summary_json.out"; then
    record_fail "phase gate summary json is not pass"
  fi
fi

if [[ -f "${TMP_DIR}/runtime_targets_summary_json.out" ]]; then
  if ! rg -q '"default_runtime":"codex"' "${TMP_DIR}/runtime_targets_summary_json.out"; then
    record_fail "runtime targets summary missing default_runtime=codex"
  fi
  if ! rg -q '"default_live_root":"~/.codex"' "${TMP_DIR}/runtime_targets_summary_json.out"; then
    record_fail "runtime targets summary missing default_live_root=~/.codex"
  fi
  if ! rg -q '"health_adapters":4' "${TMP_DIR}/runtime_targets_summary_json.out"; then
    record_fail "runtime targets summary missing health adapter count"
  fi
  if ! rg -q '"enabled_health_adapters":1' "${TMP_DIR}/runtime_targets_summary_json.out"; then
    record_fail "runtime targets summary missing enabled health adapter count"
  fi
fi

if [[ -f "${TMP_DIR}/runtime_target_explain_codex.out" ]]; then
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "status" '"pass"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "target_id" '"codex-home"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "runtime" '"codex"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "role" '"external-handoff-target"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "enabled" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "source_repo" '"~/codex"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "live_root" '"~/.codex"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "source_to_live_chain" '["agent-dev-kit","~/codex","~/.codex"]'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "write_policy" '"report-only-from-llm_agent"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "health_adapter" '"codex-global-health"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_declared" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_enabled" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_status" '"active"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_read_only" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_runtime" '"codex"'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "adapter_bound" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "activation_ready" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "evidence_status.dry_run" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "evidence_status.rollback" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "evidence_status.runtime_health" 'true'
  assert_json_field "runtime target explain codex" "${TMP_DIR}/runtime_target_explain_codex.out" "evidence_status.runtime_live_footprint" 'true'
fi

if [[ -f "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" ]]; then
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "status" '"pass"'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "target_id" '"claude-code-home"'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "runtime" '"claude-code"'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "role" '"target-candidate"'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "enabled" 'false'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "source_repo" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "live_root" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "source_to_live_chain" '[]'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "write_policy" '"not-enabled"'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "health_adapter" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_declared" 'false'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_enabled" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_status" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_read_only" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_runtime" 'null'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "adapter_bound" 'false'
  assert_json_field "runtime target explain candidate" "${TMP_DIR}/runtime_target_explain_claude_code_candidate.out" "activation_ready" 'false'
fi

if [[ -f "${TMP_DIR}/subrepo_state_summary_json.out" ]]; then
  if ! rg -q '"status":' "${TMP_DIR}/subrepo_state_summary_json.out"; then
    record_fail "subrepo state summary json missing status"
  fi
  if ! rg -q '"known_dirty":' "${TMP_DIR}/subrepo_state_summary_json.out"; then
    record_fail "subrepo state summary json missing known_dirty"
  fi
fi

if [[ -f "${TMP_DIR}/evidence_bundle_json.out" ]]; then
  if ! rg -q '"checks":' "${TMP_DIR}/evidence_bundle_json.out"; then
    record_fail "evidence bundle json missing checks"
  fi
fi

if [[ -f "${TMP_DIR}/governance_health_json.out" ]]; then
  if ! rg -q '"top_actions":' "${TMP_DIR}/governance_health_json.out"; then
    record_fail "governance health json missing top_actions"
  fi
fi

if [[ -f "${TMP_DIR}/governance_review_json.out" ]]; then
  if ! rg -q '"decisions":' "${TMP_DIR}/governance_review_json.out"; then
    record_fail "governance review json missing decisions"
  fi
  if ! rg -q '"checks":' "${TMP_DIR}/governance_review_json.out"; then
    record_fail "governance review json missing checks"
  fi
fi

if [[ -f "${TMP_DIR}/token_budget_summary_json.out" ]]; then
  if ! rg -q '"status":"pass"' "${TMP_DIR}/token_budget_summary_json.out"; then
    record_fail "token budget summary json is not pass"
  fi
fi

if [[ -f "${TMP_DIR}/reference_dirty_triage_summary_json.out" ]]; then
  if ! rg -q '"items":3' "${TMP_DIR}/reference_dirty_triage_summary_json.out"; then
    record_fail "reference dirty triage summary missing 3 items"
  fi
fi

if [[ -f "${TMP_DIR}/runtime_health_summary_json.out" ]]; then
  if ! rg -q '"runtime":"codex"' "${TMP_DIR}/runtime_health_summary_json.out"; then
    record_fail "runtime health summary missing runtime=codex"
  fi
  if ! rg -q '"adapter_exit":0' "${TMP_DIR}/runtime_health_summary_json.out"; then
    record_fail "runtime health adapter did not pass"
  fi
  if ! rg -q '"adapter_id":"codex-global-health"' "${TMP_DIR}/runtime_health_summary_json.out"; then
    record_fail "runtime health summary missing adapter_id=codex-global-health"
  fi
fi

if [[ -f "${TMP_DIR}/runtime_live_footprint_summary_json.out" ]]; then
  if ! rg -q '"missing_required":' "${TMP_DIR}/runtime_live_footprint_summary_json.out"; then
    record_fail "runtime live footprint summary missing missing_required"
  fi
fi

if [[ -f "${TMP_DIR}/runtime_control_snapshot.out" ]]; then
  if ! rg -q '"schema_version": *"runtime_control.decision/v1"' "${TMP_DIR}/runtime_control_snapshot.out"; then
    record_fail "Runtime Control snapshot missing decision schema"
  fi
fi

diff_report="${TMP_DIR}/diff.md"
run_check "diff_scan" "${ROOT}/scripts/diff-scan.sh" "${ROOT}" 7 "${diff_report}"
if [[ -f "${diff_report}" ]] && rg -q 'intake_policy：.*,[SABCDX]' "${diff_report}"; then
  record_fail "diff scan leaked grade into intake_policy"
fi

rtk git -C "${ROOT}" status --porcelain=v1 >"${TMP_DIR}/final-status.txt"
if ! cmp -s "${INITIAL_STATUS}" "${TMP_DIR}/final-status.txt"; then
  record_fail "workspace entrypoints changed repository status"
  diff -u "${INITIAL_STATUS}" "${TMP_DIR}/final-status.txt" >&2 || true
fi

if (( FAILURES > 0 )); then
  echo "[SUMMARY] workspace entrypoints failed: ${FAILURES}" >&2
  exit 1
fi

echo "[PASS] workspace entrypoints ready"
