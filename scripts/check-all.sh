#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# check-all.sh — 一键运行所有 check-* 脚本，汇总结果
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SAME_RUN_EVIDENCE_LIB="${SCRIPT_DIR}/lib/same-run-evidence.sh"

if [[ ! -f "${SAME_RUN_EVIDENCE_LIB}" ]]; then
  echo "[ERROR] missing same-run evidence library: ${SAME_RUN_EVIDENCE_LIB}" >&2
  exit 1
fi
# shellcheck source=scripts/lib/same-run-evidence.sh
source "${SAME_RUN_EVIDENCE_LIB}"

# --- 参数解析 ---------------------------------------------------------------
CHECK_MODE="full"
VERBOSE_MODE=0
RESULT_JSON=""
MAX_FAILURE_LINES="${LLM_AGENT_CHECK_FAILURE_LINES:-40}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke) CHECK_MODE="smoke" ;;
    --quick) CHECK_MODE="quick" ;;
    --full) CHECK_MODE="full" ;;
    --verbose) VERBOSE_MODE=1 ;;
    --result-json)
      RESULT_JSON="${2:-}"
      [[ -n "${RESULT_JSON}" ]] || {
        echo "[ERROR] --result-json requires a path" >&2
        exit 1
      }
      shift
      ;;
    --max-failure-lines)
      MAX_FAILURE_LINES="${2:-}"
      shift
      ;;
    -h|--help)
      echo "用法: $(basename "$0") [--smoke|--quick|--full] [--verbose] [--result-json <path>] [--max-failure-lines <n>]"
      echo ""
      echo "选项:"
      echo "  --smoke     最小健康面：锁、阶段、子仓、doc、runtime、pilot/fallback 摘要"
      echo "  --quick     跳过耗时脚本（check-adk-harden-readiness.sh、check-workspace-entrypoints.sh）"
      echo "  --full      运行全部 check-* 脚本（默认）"
      echo "  --verbose   显示每个脚本的完整输出"
      echo "  --result-json <path>  写入机器可读结果与耗时"
      echo "  --max-failure-lines <n>  非 verbose 失败时展示的最大日志行数（默认 40）"
      echo "  --help      显示此帮助信息"
      exit 0
      ;;
    *)
      echo "[ERROR] 未知参数: $1" >&2
      exit 1
      ;;
  esac
  shift
done

[[ "${MAX_FAILURE_LINES}" =~ ^[0-9]+$ ]] || {
  echo "[ERROR] --max-failure-lines must be numeric" >&2
  exit 1
}

# --- 自动发现 check-* 脚本 --------------------------------------------------
SKIP_SCRIPTS=()
SMOKE_SCRIPTS=()
case "${CHECK_MODE}" in
  smoke)
    SMOKE_SCRIPTS=(
      "check-adk-lock.sh"
      "check-phase-gate.sh"
      "check-subrepo-state.sh"
      "check-reference-dirty-triage.sh"
      "check-doc-sync.sh"
      "check-adoption-real-assets.sh"
      "check-adk-target-evidence.sh"
      "check-runtime-targets.sh"
      "check-runtime-routing.sh"
      "check-runtime-health.sh"
      "check-runtime-live-footprint.sh"
      "check-evidence-bundle.sh"
    )
    ;;
  quick)
    SKIP_SCRIPTS+=(
      "check-adk-harden-readiness.sh"
      "check-adk-performance-ops.sh"
      "check-evidence-bundle.sh"
      "check-root-regression.sh"
      "check-token-budget.sh"
      "check-workspace-entrypoints.sh"
    )
    ;;
  full) ;;
esac

contains_item() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

discover_check_scripts() {
  local scripts=()
  for f in "${SCRIPT_DIR}"/check-*.sh; do
    [[ -f "${f}" ]] || continue
    local base
    base="$(basename "${f}")"
    # 跳过自身（check-all.sh 不会出现，因为名字符合 check-*.sh 但自身也叫 check-all.sh）
    [[ "${base}" == "check-all.sh" ]] && continue
    if [[ "${CHECK_MODE}" == "smoke" ]] && ! contains_item "${base}" "${SMOKE_SCRIPTS[@]}"; then
      continue
    fi
    # 跳过 --quick 模式下需要排除的脚本
    contains_item "${base}" "${SKIP_SCRIPTS[@]:-}" && continue
    scripts+=("${f}")
  done
  printf '%s\n' "${scripts[@]}"
}

# --- 执行 -------------------------------------------------------------------
declare -a RESULT_NAMES=()
declare -a RESULT_STATUS=()
declare -a RESULT_DURATION=()
declare -a RESULT_EXIT_CODE=()
declare -a REUSED_CONSUMERS=()
declare -a REUSED_PRODUCERS=()
TOTAL=0
PASSED=0
FAILED=0
RUN_STARTED_AT="$(date +%s)"
RUN_TMP="$(mktemp -d)"
SAME_RUN_EVIDENCE_DIR="${RUN_TMP}/same-run-evidence"
SAME_RUN_REUSE_REPORT="${RUN_TMP}/same-run-reuse.tsv"
SAME_RUN_INITIAL_FINGERPRINT=""
SAME_RUN_PRODUCER_START_TOKEN=""
SAME_RUN_READY=0
SAME_RUN_ELIGIBLE=0

cleanup() {
  rm -rf "${RUN_TMP}"
}
trap cleanup EXIT

: >"${SAME_RUN_REUSE_REPORT}"
chmod 600 "${SAME_RUN_REUSE_REPORT}"

if [[ "${CHECK_MODE}" == "full" ]]; then
  if SAME_RUN_INITIAL_FINGERPRINT="$(llm_agent_workspace_fingerprint "${WORKSPACE_ROOT}")" \
    && SAME_RUN_PRODUCER_START_TOKEN="$(llm_agent_process_start_token "$$")" \
    && llm_agent_same_run_init \
      "${SAME_RUN_EVIDENCE_DIR}" \
      "$$" \
      "${SAME_RUN_PRODUCER_START_TOKEN}" \
      "${WORKSPACE_ROOT}" \
      "${SAME_RUN_INITIAL_FINGERPRINT}"; then
    SAME_RUN_READY=1
  else
    echo "[WARN] same-run evidence initialization failed; full gate will execute without reuse" >&2
  fi
fi

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

write_result_json() {
  [[ -n "${RESULT_JSON}" ]] || return 0
  local run_finished_at elapsed_seconds first i run_status
  run_finished_at="$(date +%s)"
  elapsed_seconds=$((run_finished_at - RUN_STARTED_AT))
  run_status="pass"
  [[ "${FAILED}" -eq 0 ]] || run_status="fail"
  mkdir -p "$(dirname "${RESULT_JSON}")"
  {
    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "suite": "llm-agent-check-all",\n'
    printf '  "mode": %s,\n' "$(json_string "${CHECK_MODE}")"
    printf '  "status": %s,\n' "$(json_string "${run_status}")"
    printf '  "total": %s,\n' "${TOTAL}"
    printf '  "pass": %s,\n' "${PASSED}"
    printf '  "fail": %s,\n' "${FAILED}"
    printf '  "elapsed_seconds": %s,\n' "${elapsed_seconds}"
    printf '  "same_run_reuse": {\n'
    printf '    "eligible": %s,\n' "$([[ "${SAME_RUN_ELIGIBLE}" -eq 1 ]] && printf true || printf false)"
    printf '    "count": %s,\n' "${#REUSED_CONSUMERS[@]}"
    printf '    "checks": [\n'
    first=1
    for i in "${!REUSED_CONSUMERS[@]}"; do
      [[ "${first}" -eq 1 ]] || printf ',\n'
      first=0
      printf '      {"consumer": %s, "producer": %s}' \
        "$(json_string "${REUSED_CONSUMERS[$i]}")" \
        "$(json_string "${REUSED_PRODUCERS[$i]}")"
    done
    printf '\n    ]\n'
    printf '  },\n'
    printf '  "checks": [\n'
    first=1
    for i in "${!RESULT_NAMES[@]}"; do
      [[ "${first}" -eq 1 ]] || printf ',\n'
      first=0
      printf '    {"name": %s, "status": %s, "exit_code": %s, "elapsed_seconds": %s}' \
        "$(json_string "${RESULT_NAMES[$i]}")" \
        "$(json_string "$(printf '%s' "${RESULT_STATUS[$i]}" | tr '[:upper:]' '[:lower:]')")" \
        "${RESULT_EXIT_CODE[$i]}" \
        "${RESULT_DURATION[$i]}"
    done
    printf '\n  ]\n'
    printf '}\n'
  } >"${RESULT_JSON}"
}

echo "=============================================="
echo " llm_agent 一键门禁检查"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
case "${CHECK_MODE}" in
  smoke) echo " 模式: --smoke（最小健康面）" ;;
  quick) echo " 模式: --quick（跳过耗时综合脚本）" ;;
  full)  echo " 模式: --full（全部脚本）" ;;
esac
echo "=============================================="
echo ""

while IFS= read -r script_path; do
  [[ -z "${script_path}" ]] && continue
  script_name="$(basename "${script_path}")"
  TOTAL=$((TOTAL + 1))

  echo -n "▶ ${script_name} ..."

  # 执行脚本，捕获输出和退出码
  tmpfile="${RUN_TMP}/${script_name}.out"
  exit_code=0
  started_at="$(date +%s)"
  check_command=(bash "${script_path}" "${WORKSPACE_ROOT}")
  if [[ "${script_name}" == "check-workspace-entrypoints.sh" && "${SAME_RUN_READY}" -eq 1 ]]; then
    current_fingerprint=""
    if current_fingerprint="$(llm_agent_workspace_fingerprint "${WORKSPACE_ROOT}")" \
      && [[ "${current_fingerprint}" == "${SAME_RUN_INITIAL_FINGERPRINT}" ]]; then
      SAME_RUN_ELIGIBLE=1
      check_command=(
        env
        "LLM_AGENT_SAME_RUN_EVIDENCE_DIR=${SAME_RUN_EVIDENCE_DIR}"
        "LLM_AGENT_SAME_RUN_PRODUCER_PID=$$"
        "LLM_AGENT_SAME_RUN_PRODUCER_START=${SAME_RUN_PRODUCER_START_TOKEN}"
        "LLM_AGENT_SAME_RUN_REUSE_REPORT=${SAME_RUN_REUSE_REPORT}"
        bash "${script_path}" "${WORKSPACE_ROOT}"
      )
    fi
  fi
  if [[ ${VERBOSE_MODE} -eq 1 ]]; then
    echo ""
    echo "--- ${script_name} 输出开始 ---"
    if "${check_command[@]}" 2>&1 | tee "${tmpfile}"; then
      exit_code=0
    else
      exit_code=$?
    fi
    echo "--- ${script_name} 输出结束 ---"
  else
    if "${check_command[@]}" > "${tmpfile}" 2>&1; then
      exit_code=0
    else
      exit_code=$?
    fi
  fi

  finished_at="$(date +%s)"
  duration_seconds=$((finished_at - started_at))

  RESULT_NAMES+=("${script_name}")
  RESULT_DURATION+=("${duration_seconds}")
  RESULT_EXIT_CODE+=("${exit_code}")
  if [[ ${exit_code} -eq 0 ]]; then
    RESULT_STATUS+=("PASS")
    PASSED=$((PASSED + 1))
    echo " PASS"
  else
    RESULT_STATUS+=("FAIL")
    FAILED=$((FAILED + 1))
    echo " FAIL (exit=${exit_code})"
    if [[ ${VERBOSE_MODE} -eq 0 && -s "${tmpfile}" && ${MAX_FAILURE_LINES} -gt 0 ]]; then
      echo "  ${script_name} failure log (last ${MAX_FAILURE_LINES} lines):"
      tail -n "${MAX_FAILURE_LINES}" "${tmpfile}" | sed 's/^/    /'
    fi
  fi

  if [[ "${SAME_RUN_READY}" -eq 1 && "${script_name}" != "check-workspace-entrypoints.sh" ]]; then
    if ! llm_agent_same_run_record \
      "${SAME_RUN_EVIDENCE_DIR}" \
      "$$" \
      "${SAME_RUN_PRODUCER_START_TOKEN}" \
      "${WORKSPACE_ROOT}" \
      "${SAME_RUN_INITIAL_FINGERPRINT}" \
      "${script_name}" \
      "${script_path}" \
      "${exit_code}" \
      "${tmpfile}"; then
      SAME_RUN_READY=0
      echo "[WARN] same-run evidence recording failed; remaining checks will execute without reuse" >&2
    fi
  fi

  if [[ "${script_name}" == "check-workspace-entrypoints.sh" \
    && -f "${SAME_RUN_REUSE_REPORT}" \
    && ! -L "${SAME_RUN_REUSE_REPORT}" ]]; then
    while IFS=$'\t' read -r reused_consumer reused_producer; do
      [[ -n "${reused_consumer}" && -n "${reused_producer}" ]] || continue
      REUSED_CONSUMERS+=("${reused_consumer}")
      REUSED_PRODUCERS+=("${reused_producer}")
    done <"${SAME_RUN_REUSE_REPORT}"
  fi
done < <(discover_check_scripts)

# --- 汇总表 -----------------------------------------------------------------
echo ""
echo "=============================================="
echo " 检查汇总"
echo "=============================================="
printf '%-42s %-8s %s\n' "脚本" "状态" "耗时(s)"
printf '%-42s %-8s %s\n' "------------------------------------------" "--------" "-------"
for i in "${!RESULT_NAMES[@]}"; do
  local_status="${RESULT_STATUS[$i]}"
  marker="✅"
  [[ "${local_status}" == "FAIL" ]] && marker="❌"
  printf '%-42s %-8s %-3s %s\n' "${RESULT_NAMES[$i]}" "${local_status}" "${RESULT_DURATION[$i]}" "${marker}"
done

echo "------------------------------------------"
echo "总计: ${TOTAL}   通过: ${PASSED}   失败: ${FAILED}"
if [[ "${CHECK_MODE}" == "full" ]]; then
  echo "同运行证据复用: ${#REUSED_CONSUMERS[@]}（eligible=$([[ "${SAME_RUN_ELIGIBLE}" -eq 1 ]] && printf true || printf false)）"
fi

case "${CHECK_MODE}" in
  smoke) echo "提示: --smoke 只覆盖最小健康面，不替代完整回归。" ;;
  quick) echo "提示: --quick 已跳过 ADK quick suite、evidence/token/WeChat、harden readiness 和 workspace aggregate；提交/发布前需单独执行对应门禁或 --full。" ;;
esac

echo ""
write_result_json

if [[ ${FAILED} -eq 0 ]]; then
  echo "🎉 全部通过！"
  exit 0
else
  echo "⚠️  有 ${FAILED} 项未通过，请检查上方详细输出。"
  exit 1
fi
