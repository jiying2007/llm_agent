#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# devkit.sh — llm_agent 工作区统一入口
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- 颜色 -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 帮助 -------------------------------------------------------------------
show_help() {
  cat <<'EOF'
llm_agent devkit — 工作区统一入口

用法: devkit.sh <子命令> [选项]

子命令:
  check [--smoke|--quick|--full] 一键运行所有门禁检查
                                   --smoke  最小健康面
                                   --quick  跳过重复的耗时综合/release gate（默认）
                                   --full   运行全部检查

  onboard <repo-path> [--adopt|--observe]
                                 新仓库接入治理

  sync [fetch|pull|status]       子仓同步
                                   fetch   拉取远端更新（默认）
                                   pull    对 sync_mode=pull 的子仓执行 ff-only 拉取
                                   status  查看同步状态

  diff [days]                    扫描高价值变更（默认 7 天）

  health [--summary-json]        工作区健康检查
  runtime-live [--summary-json]  检查 adk 在目标运行态中的 live footprint
  coach [--summary-json] [--deep]
                                 长会话、token 压力和资产变更收口提醒

  weekly-report                  生成周报

  cleanup [--dry-run]            清理过期报告
                                   --dry-run  仅预览，不实际删除

  help                           显示此帮助信息

示例:
  devkit.sh check --quick
  devkit.sh onboard ../my-repo --adopt
  devkit.sh sync fetch
  devkit.sh diff 14
  devkit.sh health
  devkit.sh cleanup --dry-run
EOF
}

# --- 子命令: check ----------------------------------------------------------
cmd_check() {
  local mode="--quick"
  for arg in "$@"; do
    case "${arg}" in
      --smoke) mode="--smoke" ;;
      --quick) mode="--quick" ;;
      --full)  mode="--full" ;;
      *)       echo "[WARN] check 未知参数: ${arg}" >&2 ;;
    esac
  done

  local check_script="${SCRIPT_DIR}/check-all.sh"
  if [[ ! -x "${check_script}" ]]; then
    echo -e "${RED}[ERROR] check-all.sh 不存在或不可执行: ${check_script}${NC}" >&2
    exit 1
  fi

  bash "${check_script}" ${mode}
}

# --- 子命令: onboard --------------------------------------------------------
cmd_onboard() {
  if [[ $# -lt 1 ]]; then
    echo -e "${RED}[ERROR] 用法: devkit.sh onboard <repo-path> [--adopt|--observe]${NC}" >&2
    exit 1
  fi

  local repo_path="$1"
  shift

  local onboard_script="${SCRIPT_DIR}/new-repo-onboard.sh"
  if [[ ! -x "${onboard_script}" ]]; then
    echo -e "${RED}[ERROR] new-repo-onboard.sh 不存在或不可执行${NC}" >&2
    exit 1
  fi

  bash "${onboard_script}" "${repo_path}" "$@"
}

# --- 子命令: sync -----------------------------------------------------------
cmd_sync() {
  local action="${1:-fetch}"

  local sync_script="${SCRIPT_DIR}/sync-subrepos.sh"
  if [[ ! -x "${sync_script}" ]]; then
    echo -e "${RED}[ERROR] sync-subrepos.sh 不存在或不可执行${NC}" >&2
    exit 1
  fi

  bash "${sync_script}" "${WORKSPACE_ROOT}" "${action}"
}

# --- 子命令: diff -----------------------------------------------------------
cmd_diff() {
  local days="${1:-7}"

  local diff_script="${SCRIPT_DIR}/diff-scan.sh"
  if [[ ! -x "${diff_script}" ]]; then
    echo -e "${RED}[ERROR] diff-scan.sh 不存在或不可执行${NC}" >&2
    exit 1
  fi

  bash "${diff_script}" "${WORKSPACE_ROOT}" "${days}" "reports/weekly-change-report.md"
}

# --- 子命令: health ---------------------------------------------------------
cmd_health() {
  local health_script="${SCRIPT_DIR}/health-check.sh"
  if [[ ! -x "${health_script}" ]]; then
    echo -e "${RED}[ERROR] health-check.sh 不存在或不可执行${NC}" >&2
    exit 1
  fi

  bash "${health_script}" check-all --root "${WORKSPACE_ROOT}" "$@"
}

# --- 子命令: runtime-live --------------------------------------------------
cmd_runtime_live() {
  bash "${SCRIPT_DIR}/check-runtime-live-footprint.sh" "${WORKSPACE_ROOT}" "$@"
}

# --- 子命令: coach ----------------------------------------------------------
cmd_coach() {
  bash "${SCRIPT_DIR}/session-coach.sh" "${WORKSPACE_ROOT}" "$@"
}

# --- 子命令: weekly-report --------------------------------------------------
cmd_weekly_report() {
  local report_script="${SCRIPT_DIR}/generate-weekly-report.sh"
  if [[ ! -x "${report_script}" ]]; then
    echo -e "${RED}[ERROR] generate-weekly-report.sh 不存在或不可执行${NC}" >&2
    echo -e "${YELLOW}提示: 该脚本尚未创建，请手动生成周报或创建该脚本。${NC}" >&2
    exit 1
  fi

  bash "${report_script}" "${WORKSPACE_ROOT}"
}

# --- 子命令: cleanup --------------------------------------------------------
cmd_cleanup() {
  local dry_run=""
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="--dry-run" ;;
    esac
  done

  local cleanup_script="${SCRIPT_DIR}/cleanup-reports.sh"
  if [[ ! -x "${cleanup_script}" ]]; then
    echo -e "${RED}[ERROR] cleanup-reports.sh 不存在或不可执行${NC}" >&2
    echo -e "${YELLOW}提示: 该脚本尚未创建，请手动清理报告或创建该脚本。${NC}" >&2
    exit 1
  fi

  bash "${cleanup_script}" "${WORKSPACE_ROOT}" ${dry_run}
}

# --- 主入口 -----------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  show_help
  exit 0
fi

SUBCMD="$1"
shift

case "${SUBCMD}" in
  check)        cmd_check "$@" ;;
  onboard)      cmd_onboard "$@" ;;
  sync)         cmd_sync "$@" ;;
  diff)         cmd_diff "$@" ;;
  health)       cmd_health "$@" ;;
  runtime-live)   cmd_runtime_live "$@" ;;
  coach)        cmd_coach "$@" ;;
  weekly-report) cmd_weekly_report "$@" ;;
  cleanup)      cmd_cleanup "$@" ;;
  help|-h|--help) show_help ;;
  *)
    echo -e "${RED}[ERROR] 未知子命令: ${SUBCMD}${NC}" >&2
    echo "运行 'devkit.sh help' 查看可用命令。" >&2
    exit 1
    ;;
esac
