#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FORMAT="markdown"
OUT=""
FAIL_ON_NEEDS_FIX=0
MAX_SUMMARY_CHARS=800

usage() {
  cat <<USAGE
usage: scripts/evidence-bundle.sh [root] [--format markdown|json] [--out <path>] [--fail-on-needs-fix] [--max-summary-chars <n>]

Collects a compact pre-commit / release evidence bundle for llm_agent and
agent-dev-kit. The command is read-only except for --out.
USAGE
}

shift_root=0
if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift_root=1
fi
if [[ "${shift_root}" -eq 1 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --fail-on-needs-fix)
      FAIL_ON_NEEDS_FIX=1
      shift
      ;;
    --max-summary-chars)
      MAX_SUMMARY_CHARS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${FORMAT}" in
  markdown|json)
    ;;
  *)
    echo "[FAIL] unsupported format: ${FORMAT}" >&2
    exit 1
    ;;
esac
[[ "${MAX_SUMMARY_CHARS}" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] --max-summary-chars must be numeric" >&2
  exit 1
}

ADK_DIR="${ROOT}/agent-dev-kit"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

run_capture() {
  local name="$1"
  shift
  local out_file="${TMP_DIR}/${name}.out"
  local rc=0
  set +e
  "$@" >"${out_file}" 2>&1
  rc=$?
  set -e
  printf '%s' "${rc}" >"${TMP_DIR}/${name}.rc"
}

run_capture adk_lock "${ROOT}/scripts/check-adk-lock.sh" "${ROOT}"
run_capture runtime_targets "${ROOT}/scripts/check-runtime-targets.sh" "${ROOT}" --summary-json
run_capture phase_gate "${ROOT}/scripts/check-phase-gate.sh" "${ROOT}" --summary-json
run_capture subrepo_state "${ROOT}/scripts/check-subrepo-state.sh" "${ROOT}" --summary-json
run_capture reference_dirty_triage "${ROOT}/scripts/check-reference-dirty-triage.sh" "${ROOT}" --summary-json
run_capture runtime_pilot "${ROOT}/scripts/check-runtime-pilot.sh" "${ROOT}" evidence
run_capture runtime_health "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --profile minimal --summary-json
run_capture runtime_live "${ROOT}/scripts/check-runtime-live-footprint.sh" "${ROOT}" --summary-json
run_capture pilot_readiness "${ADK_DIR}/scripts/pilot-readiness.sh" --summary-json
run_capture fallback_sunset "${ADK_DIR}/scripts/check-fallback-sunset.sh" --summary-json

root_head="$(git -C "${ROOT}" rev-parse --short HEAD)"
adk_head="$(git -C "${ADK_DIR}" rev-parse --short HEAD)"
generated_at="$(date -Iseconds)"
overall_status="pass"
for check_name in adk_lock runtime_targets phase_gate subrepo_state reference_dirty_triage runtime_pilot runtime_health runtime_live pilot_readiness fallback_sunset; do
  if [[ "$(cat "${TMP_DIR}/${check_name}.rc")" -ne 0 ]]; then
    overall_status="needs-fix"
  fi
done

compact_file() {
  local file="$1"
  local summary
  summary="$(tr '\n' ' ' <"${file}" | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c "1-${MAX_SUMMARY_CHARS}")"
  if [[ "$(wc -c <"${file}" | tr -d ' ')" -gt "${MAX_SUMMARY_CHARS}" ]]; then
    summary="${summary}..."
  fi
  printf '%s' "${summary}"
}

write_markdown() {
  cat <<MD
# llm_agent Evidence Bundle

- generated_at: ${generated_at}
- status: ${overall_status}
- root_head: ${root_head}
- agent_dev_kit_head: ${adk_head}

| Check | Exit Code | Summary |
|---|---:|---|
| adk_lock | $(cat "${TMP_DIR}/adk_lock.rc") | $(compact_file "${TMP_DIR}/adk_lock.out") |
| runtime_targets | $(cat "${TMP_DIR}/runtime_targets.rc") | $(compact_file "${TMP_DIR}/runtime_targets.out") |
| phase_gate | $(cat "${TMP_DIR}/phase_gate.rc") | $(compact_file "${TMP_DIR}/phase_gate.out") |
| subrepo_state | $(cat "${TMP_DIR}/subrepo_state.rc") | $(compact_file "${TMP_DIR}/subrepo_state.out") |
| reference_dirty_triage | $(cat "${TMP_DIR}/reference_dirty_triage.rc") | $(compact_file "${TMP_DIR}/reference_dirty_triage.out") |
| runtime_pilot_evidence | $(cat "${TMP_DIR}/runtime_pilot.rc") | $(compact_file "${TMP_DIR}/runtime_pilot.out") |
| runtime_health | $(cat "${TMP_DIR}/runtime_health.rc") | $(compact_file "${TMP_DIR}/runtime_health.out") |
| runtime_live_footprint | $(cat "${TMP_DIR}/runtime_live.rc") | $(compact_file "${TMP_DIR}/runtime_live.out") |
| pilot_readiness | $(cat "${TMP_DIR}/pilot_readiness.rc") | $(compact_file "${TMP_DIR}/pilot_readiness.out") |
| fallback_sunset | $(cat "${TMP_DIR}/fallback_sunset.rc") | $(compact_file "${TMP_DIR}/fallback_sunset.out") |
MD
}

write_json() {
  printf '{\n'
  printf '  "generated_at": %s,\n' "$(json_string "${generated_at}")"
  printf '  "status": %s,\n' "$(json_string "${overall_status}")"
  printf '  "root_head": %s,\n' "$(json_string "${root_head}")"
  printf '  "agent_dev_kit_head": %s,\n' "$(json_string "${adk_head}")"
  printf '  "checks": [\n'
  local first=1
  local name
  for name in adk_lock runtime_targets phase_gate subrepo_state reference_dirty_triage runtime_pilot runtime_health runtime_live pilot_readiness fallback_sunset; do
    [[ "${first}" -eq 1 ]] || printf ',\n'
    first=0
    printf '    {"name": %s, "exit_code": %s, "summary": %s}' \
      "$(json_string "${name}")" \
      "$(cat "${TMP_DIR}/${name}.rc")" \
      "$(json_string "$(compact_file "${TMP_DIR}/${name}.out")")"
  done
  printf '\n  ]\n'
  printf '}\n'
}

if [[ -n "${OUT}" ]]; then
  mkdir -p "$(dirname "${OUT}")"
  if [[ "${FORMAT}" == "json" ]]; then
    write_json >"${OUT}"
  else
    write_markdown >"${OUT}"
  fi
  echo "[PASS] evidence bundle written: ${OUT}"
else
  if [[ "${FORMAT}" == "json" ]]; then
    write_json
  else
    write_markdown
  fi
fi

if [[ "${FAIL_ON_NEEDS_FIX}" -eq 1 && "${overall_status}" != "pass" ]]; then
  echo "[FAIL] evidence bundle status=${overall_status}" >&2
  exit 1
fi
