#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<USAGE
usage: scripts/oss-intake.sh <command> [args...]

Commands:
  status [--summary-json]        Run local OSS intake health checks.
  discover --dry-run [args...]   Generate report-only discovery candidate ledger.
  cycle [args...]                Run report-only P4 cycle.
  queue [args...]                Generate report-only approval queue.
  score --ledger FILE [--out F]  Generate score report from a local ledger.
  plan-onboard [args...]         Generate P2 onboarding plan.
  plan-remove [args...]          Generate P3 removal plan.
  check                         Run P1-P4 OSS intake fixture checks.

This wrapper does not add network discovery, apply, removal, absorption, commit, or push behavior.
USAGE
}

[[ $# -gt 0 ]] || {
  usage
  exit 1
}

COMMAND="$1"
shift

has_arg() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

status_summary_json() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  local scripts=(
    "check-oss-intake-ledger.sh"
    "check-oss-registration-plan.sh"
    "check-oss-removal-plan.sh"
    "check-oss-continuous-operation.sh"
    "check-oss-approval-queue.sh"
  )
  local script rc overall="pass"
  for script in "${scripts[@]}"; do
    rc=0
    set +e
    "${ROOT}/scripts/${script}" "${ROOT}" --summary-json >"${tmp_dir}/${script}.json" 2>"${tmp_dir}/${script}.err"
    rc=$?
    set -e
    printf '%s\n' "${rc}" >"${tmp_dir}/${script}.rc"
    [[ "${rc}" -ne 0 ]] && overall="fail"
  done

  python3 - "${tmp_dir}" "${overall}" "${scripts[@]}" <<'PY'
import json
import os
import sys

tmp_dir = sys.argv[1]
overall = sys.argv[2]
scripts = sys.argv[3:]
checks = []
for script in scripts:
    with open(os.path.join(tmp_dir, f"{script}.rc"), "r", encoding="utf-8") as handle:
        rc = int(handle.read().strip())
    out_path = os.path.join(tmp_dir, f"{script}.json")
    err_path = os.path.join(tmp_dir, f"{script}.err")
    detail = None
    try:
        with open(out_path, "r", encoding="utf-8") as handle:
            text = handle.read().strip()
        detail = json.loads(text) if text else None
    except Exception:
        detail = None
    error = ""
    if os.path.exists(err_path):
        with open(err_path, "r", encoding="utf-8") as handle:
            error = handle.read().strip()[:240]
    checks.append({
        "script": script,
        "status": "pass" if rc == 0 else "fail",
        "exit_code": rc,
        "detail": detail,
        "error": error,
    })
print(json.dumps({
    "schema_version": 1,
    "status": overall,
    "mode": "report-only",
    "checks": checks,
}, ensure_ascii=False))
PY

  [[ "${overall}" == "pass" ]]
}

case "${COMMAND}" in
  status)
    if has_arg "--summary-json" "$@"; then
      status_summary_json
    else
      "${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" "$@"
      "${ROOT}/scripts/check-oss-registration-plan.sh" "${ROOT}" "$@"
      "${ROOT}/scripts/check-oss-removal-plan.sh" "${ROOT}" "$@"
      "${ROOT}/scripts/check-oss-continuous-operation.sh" "${ROOT}" "$@"
      "${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" "$@"
    fi
    ;;
  cycle)
    "${ROOT}/scripts/run-oss-intake-cycle.sh" "${ROOT}" "$@"
    ;;
  discover)
    "${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" "$@"
    ;;
  queue)
    "${ROOT}/scripts/generate-oss-intake-approval-queue.sh" "${ROOT}" "$@"
    ;;
  score)
    "${ROOT}/scripts/score-oss-candidates.sh" "${ROOT}" "$@"
    ;;
  plan-onboard)
    "${ROOT}/scripts/onboard-oss-candidate.sh" "${ROOT}" "$@"
    ;;
  plan-remove)
    "${ROOT}/scripts/plan-oss-subrepo-removal.sh" "${ROOT}" "$@"
    ;;
  check)
    "${ROOT}/scripts/check-oss-intake-fixtures.sh" "${ROOT}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "[FAIL] unknown oss intake command: ${COMMAND}" >&2
    usage >&2
    exit 1
    ;;
esac
