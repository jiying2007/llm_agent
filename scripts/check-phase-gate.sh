#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GATE_FILE="${ROOT}/subrepos/phase-gate.env"
SUMMARY_JSON=0

for arg in "${@:2}"; do
  case "${arg}" in
    --summary-json)
      SUMMARY_JSON=1
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-phase-gate.sh [root] [--summary-json]

Validates the llm_agent phase gate lifecycle file.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: ${arg}" >&2
      exit 1
      ;;
  esac
done

fail() {
  if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
    printf '{"status":"fail","reason":"%s"}\n' "$1"
  else
    echo "[FAIL] $1" >&2
  fi
  exit 1
}

value_for() {
  local key="$1"
  awk -F '=' -v key="${key}" '$1 == key {print $2; exit}' "${GATE_FILE}"
}

date_ge_today() {
  local value="$1"
  local today
  today="$(date +%F)"
  [[ "${value}" > "${today}" || "${value}" == "${today}" ]]
}

[[ -f "${GATE_FILE}" ]] || fail "missing phase gate file: ${GATE_FILE}"

phase="$(value_for phase)"
allow_upstream_sync="$(value_for allow_upstream_sync)"
owner="$(value_for owner)"
opened_on="$(value_for opened_on)"
last_live_refresh="$(value_for last_live_refresh)"
next_review_by="$(value_for next_review_by)"

case "${phase}" in
  harden-adk|live-refresh|fallback-sunset|upstream-intake-cycle|post-harden)
    ;;
  *)
    fail "invalid phase: ${phase}"
    ;;
esac

case "${allow_upstream_sync}" in
  yes|no)
    ;;
  *)
    fail "allow_upstream_sync must be yes or no"
    ;;
esac

[[ -n "${owner}" ]] || fail "missing owner"

if [[ "${allow_upstream_sync}" == "yes" ]]; then
  [[ "${opened_on}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "opened_on required when upstream sync is allowed"
fi

if [[ "${phase}" == "fallback-sunset" || "${phase}" == "live-refresh" ]]; then
  [[ "${last_live_refresh}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "last_live_refresh required for ${phase}"
  [[ "${next_review_by}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "next_review_by required for ${phase}"
  date_ge_today "${next_review_by}" || fail "next_review_by expired: ${next_review_by}"
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  printf '{"status":"pass","phase":"%s","allow_upstream_sync":"%s","owner":"%s","next_review_by":"%s"}\n' \
    "${phase}" "${allow_upstream_sync}" "${owner}" "${next_review_by:-}"
else
  echo "[PASS] phase gate ready phase=${phase} allow_upstream_sync=${allow_upstream_sync} owner=${owner}"
fi
