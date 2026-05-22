#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FORMAT="markdown"
MAX_SUMMARY_CHARS=260

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --max-summary-chars)
      MAX_SUMMARY_CHARS="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/governance-health.sh [root] [--format markdown|json] [--max-summary-chars <n>]

Prints a compact governance health view across goal drift, evidence, subrepo
state, pilot readiness, fallback sunset and runtime boundary checks.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
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
  local rc=0
  set +e
  "$@" >"${TMP_DIR}/${name}.out" 2>&1
  rc=$?
  set -e
  printf '%s' "${rc}" >"${TMP_DIR}/${name}.rc"
}

run_capture stale_refs "${ROOT}/scripts/check-stale-references.sh" "${ROOT}"
run_capture subrepo_state "${ROOT}/scripts/check-subrepo-state.sh" "${ROOT}" --summary-json
run_capture evidence_bundle "${ROOT}/scripts/evidence-bundle.sh" "${ROOT}" --format json
run_capture pilot_readiness "${ADK_DIR}/scripts/pilot-readiness.sh" --summary-json
run_capture fallback_sunset "${ADK_DIR}/scripts/check-fallback-sunset.sh" --summary-json
run_capture runtime_boundary "${ADK_DIR}/scripts/check-runtime-boundary.sh" --summary-json
run_capture codex_live "${ROOT}/scripts/check-codex-adk-live.sh" "${ROOT}" --summary-json
run_capture session_coach "${ROOT}/scripts/session-coach.sh" "${ROOT}" --summary-json

compact_summary() {
  local file="$1"
  local summary
  summary="$(tr '\n' ' ' <"${file}" | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c "1-${MAX_SUMMARY_CHARS}")"
  if [[ "$(wc -c <"${file}" | tr -d ' ')" -gt "${MAX_SUMMARY_CHARS}" ]]; then
    summary="${summary}..."
  fi
  printf '%s' "${summary}"
}

overall="pass"
for name in stale_refs subrepo_state evidence_bundle pilot_readiness fallback_sunset runtime_boundary codex_live session_coach; do
  if [[ "$(cat "${TMP_DIR}/${name}.rc")" -ne 0 ]]; then
    overall="needs-fix"
  fi
done

top_actions=()
if [[ "$(cat "${TMP_DIR}/stale_refs.rc")" -ne 0 ]]; then
  top_actions+=("清理 active 文档中的旧版本、旧路径、旧脚本或直写运行目录示例")
fi
if rg -q '"unexpected_dirty":[1-9]' "${TMP_DIR}/subrepo_state.out"; then
  top_actions+=("处理 unexpected dirty 子仓或刷新 dirty baseline 指纹")
fi
if rg -q '"device_needs_fix":[1-9]' "${TMP_DIR}/pilot_readiness.out"; then
  top_actions+=("补齐 production-field 真实设备/HIL/OTA/现场证据")
fi
if rg -q '"replacement_score":6[0-9]' "${TMP_DIR}/fallback_sunset.out"; then
  top_actions+=("补 Codex live gap，已满分能力先推进 candidate-sunset 观察")
fi
if rg -q '"missing_required":[1-9]' "${TMP_DIR}/codex_live.out"; then
  top_actions+=("将缺失的 adk 等价 skill 经 ~/codex apply 到 ~/.codex")
fi
if rg -q '"priority":"high"' "${TMP_DIR}/session_coach.out"; then
  top_actions+=("会话过长或上下文压力高，执行收口与新会话接力")
fi
if [[ "${#top_actions[@]}" -eq 0 ]]; then
  top_actions+=("维持周期复核，下一次按 phase-gate next_review_by 执行")
fi

if [[ "${FORMAT}" == "json" ]]; then
  printf '{\n'
  printf '  "status": %s,\n' "$(json_string "${overall}")"
  printf '  "checks": [\n'
  first=1
  for name in stale_refs subrepo_state evidence_bundle pilot_readiness fallback_sunset runtime_boundary codex_live session_coach; do
    [[ "${first}" -eq 1 ]] || printf ',\n'
    first=0
    printf '    {"name": %s, "exit_code": %s, "summary": %s}' \
      "$(json_string "${name}")" \
      "$(cat "${TMP_DIR}/${name}.rc")" \
      "$(json_string "$(compact_summary "${TMP_DIR}/${name}.out")")"
  done
  printf '\n  ],\n'
  printf '  "top_actions": [\n'
  first=1
  for action in "${top_actions[@]}"; do
    [[ "${first}" -eq 1 ]] || printf ',\n'
    first=0
    printf '    %s' "$(json_string "${action}")"
  done
  printf '\n  ]\n'
  printf '}\n'
else
  echo "# Governance Health"
  echo
  echo "- status: ${overall}"
  echo
  echo "| Check | Exit Code | Summary |"
  echo "|---|---:|---|"
  for name in stale_refs subrepo_state evidence_bundle pilot_readiness fallback_sunset runtime_boundary codex_live session_coach; do
    summary="$(compact_summary "${TMP_DIR}/${name}.out")"
    printf '| %s | %s | %s |\n' "${name}" "$(cat "${TMP_DIR}/${name}.rc")" "${summary}"
  done
  echo
  echo "## Top Actions"
  for action in "${top_actions[@]}"; do
    echo "- ${action}"
  done
fi
