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
run_check "devkit_sync_status" "${ROOT}/scripts/devkit.sh" sync status
run_check "pilot_evidence_wrapper" "${ROOT}/scripts/check-codex-pilot-evidence.sh" "${ROOT}"
run_check "pilot_coverage_wrapper" "${ROOT}/scripts/check-codex-pilot-coverage.sh" "${ROOT}"

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
