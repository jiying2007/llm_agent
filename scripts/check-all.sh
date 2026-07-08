#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# check-all.sh — 一键运行所有 check-* 脚本，汇总结果
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- 参数解析 ---------------------------------------------------------------
CHECK_MODE="full"
VERBOSE_MODE=0

for arg in "$@"; do
  case "${arg}" in
    --smoke) CHECK_MODE="smoke" ;;
    --quick) CHECK_MODE="quick" ;;
    --full) CHECK_MODE="full" ;;
    --verbose) VERBOSE_MODE=1 ;;
    -h|--help)
      echo "用法: $(basename "$0") [--smoke|--quick|--full] [--verbose]"
      echo ""
      echo "选项:"
      echo "  --smoke     最小健康面：锁、阶段、子仓、doc、runtime、pilot/fallback 摘要"
      echo "  --quick     跳过耗时脚本（check-adk-harden-readiness.sh、check-workspace-entrypoints.sh）"
      echo "  --full      运行全部 check-* 脚本（默认）"
      echo "  --verbose   显示每个脚本的完整输出"
      echo "  --help      显示此帮助信息"
      exit 0
      ;;
    *)
      echo "[ERROR] 未知参数: ${arg}" >&2
      exit 1
      ;;
  esac
done

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
      "check-runtime-live-footprint.sh"
      "check-evidence-bundle.sh"
    )
    ;;
  quick)
    SKIP_SCRIPTS+=("check-adk-harden-readiness.sh" "check-workspace-entrypoints.sh")
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
TOTAL=0
PASSED=0
FAILED=0

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
  tmpfile="$(mktemp)"
  exit_code=0
  if [[ ${VERBOSE_MODE} -eq 1 ]]; then
    echo ""
    echo "--- ${script_name} 输出开始 ---"
    if bash "${script_path}" "${WORKSPACE_ROOT}" 2>&1 | tee "${tmpfile}"; then
      exit_code=0
    else
      exit_code=$?
    fi
    echo "--- ${script_name} 输出结束 ---"
  else
    if bash "${script_path}" "${WORKSPACE_ROOT}" > "${tmpfile}" 2>&1; then
      exit_code=0
    else
      exit_code=$?
    fi
  fi

  rm -f "${tmpfile}"

  RESULT_NAMES+=("${script_name}")
  if [[ ${exit_code} -eq 0 ]]; then
    RESULT_STATUS+=("PASS")
    PASSED=$((PASSED + 1))
    echo " PASS"
  else
    RESULT_STATUS+=("FAIL")
    FAILED=$((FAILED + 1))
    echo " FAIL (exit=${exit_code})"
  fi
done < <(discover_check_scripts)

# --- 汇总表 -----------------------------------------------------------------
echo ""
echo "=============================================="
echo " 检查汇总"
echo "=============================================="
printf '%-42s %s\n' "脚本" "状态"
printf '%-42s %s\n' "------------------------------------------" "--------"
for i in "${!RESULT_NAMES[@]}"; do
  local_status="${RESULT_STATUS[$i]}"
  marker="✅"
  [[ "${local_status}" == "FAIL" ]] && marker="❌"
  printf '%-42s %s %s\n' "${RESULT_NAMES[$i]}" "${local_status}" "${marker}"
done

echo "------------------------------------------"
echo "总计: ${TOTAL}   通过: ${PASSED}   失败: ${FAILED}"

case "${CHECK_MODE}" in
  smoke) echo "提示: --smoke 只覆盖最小健康面，不替代完整回归。" ;;
  quick) echo "提示: --quick 模式已跳过 check-adk-harden-readiness.sh 和 check-workspace-entrypoints.sh。" ;;
esac

echo ""

if [[ ${FAILED} -eq 0 ]]; then
  echo "🎉 全部通过！"
  exit 0
else
  echo "⚠️  有 ${FAILED} 项未通过，请检查上方详细输出。"
  exit 1
fi
