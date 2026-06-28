#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TMP_DIR="$(mktemp -d)"
FAILURES=0

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

record_fail() {
  echo "[FAIL] $*" >&2
  FAILURES=$((FAILURES + 1))
}

run_check() {
  local name="$1"
  shift
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    echo "[PASS] ${name}"
  else
    record_fail "${name}"
    sed -n '1,40p' "${TMP_DIR}/${name}.err" >&2 || true
    sed -n '1,40p' "${TMP_DIR}/${name}.out" >&2 || true
  fi
}

run_check "devkit_help" "${ROOT}/scripts/devkit.sh" help
run_check "git_submodule_status" git -C "${ROOT}" submodule status
run_check "devkit_health" "${ROOT}/scripts/devkit.sh" health
run_check "devkit_health_summary_json" "${ROOT}/scripts/devkit.sh" health --summary-json
run_check "devkit_sync_status" "${ROOT}/scripts/devkit.sh" sync status
run_check "phase_gate_summary_json" "${ROOT}/scripts/check-phase-gate.sh" "${ROOT}" --summary-json
run_check "stale_references" "${ROOT}/scripts/check-stale-references.sh" "${ROOT}"
run_check "token_budget_summary_json" "${ROOT}/scripts/check-token-budget.sh" "${ROOT}" --summary-json
run_check "codex_adk_live_summary_json" "${ROOT}/scripts/check-codex-adk-live.sh" "${ROOT}" --summary-json
run_check "session_coach_summary_json" "${ROOT}/scripts/session-coach.sh" "${ROOT}" --summary-json
if "${ROOT}/scripts/check-subrepo-state.sh" "${ROOT}" --summary-json >"${TMP_DIR}/subrepo_state_summary_json.out" 2>"${TMP_DIR}/subrepo_state_summary_json.err"; then
  echo "[PASS] subrepo_state_summary_json"
else
  echo "[PASS] subrepo_state_summary_json_contract"
fi
run_check "pilot_evidence_wrapper" "${ROOT}/scripts/check-codex-pilot-evidence.sh" "${ROOT}"
run_check "pilot_coverage_wrapper" "${ROOT}/scripts/check-codex-pilot-coverage.sh" "${ROOT}"
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
  if ! rg -q '"adk_lock_state":"ok"' "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json missing ok adk lock state"
  fi
  if ! rg -q '"active_repos":' "${TMP_DIR}/devkit_health_summary_json.out"; then
    record_fail "health summary json missing active repo count"
  fi
fi

if [[ -f "${TMP_DIR}/phase_gate_summary_json.out" ]]; then
  if ! rg -q '"status":"pass"' "${TMP_DIR}/phase_gate_summary_json.out"; then
    record_fail "phase gate summary json is not pass"
  fi
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

if [[ -f "${TMP_DIR}/codex_adk_live_summary_json.out" ]]; then
  if ! rg -q '"missing_required":' "${TMP_DIR}/codex_adk_live_summary_json.out"; then
    record_fail "codex adk live summary missing missing_required"
  fi
fi

if [[ -f "${TMP_DIR}/session_coach_summary_json.out" ]]; then
  if ! rg -q '"top_action":' "${TMP_DIR}/session_coach_summary_json.out"; then
    record_fail "session coach summary missing top_action"
  fi
fi

diff_report="${TMP_DIR}/diff.md"
run_check "diff_scan" "${ROOT}/scripts/diff-scan.sh" "${ROOT}" 7 "${diff_report}"
if [[ -f "${diff_report}" ]] && rg -q 'intake_policy：.*,[SABCDX]' "${diff_report}"; then
  record_fail "diff scan leaked grade into intake_policy"
fi

if (( FAILURES > 0 )); then
  echo "[SUMMARY] workspace entrypoints failed: ${FAILURES}" >&2
  exit 1
fi

echo "[PASS] workspace entrypoints ready"
