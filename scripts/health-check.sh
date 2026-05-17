#!/usr/bin/env bash
set -euo pipefail

# health-check.sh — llm_agent 工作区级健康检查
#
# 支持两种调用方式：
#   scripts/health-check.sh check-all [--root <path>]
#   scripts/health-check.sh <workspace-root>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="${DEFAULT_ROOT}"
COMMAND="check-all"
VERBOSE=false
FIX=false
SUMMARY_JSON=false

log_info() { echo "[INFO] $*"; }
log_success() { echo "[PASS] $*"; }
log_warning() { echo "[WARN] $*"; }
log_error() { echo "[FAIL] $*" >&2; }

usage() {
  cat <<USAGE
健康检查脚本

Usage:
  scripts/health-check.sh [command] [--root <workspace-root>] [options]
  scripts/health-check.sh <workspace-root>

Commands:
  check-all              执行所有健康检查（默认）
  check-structure        检查目录结构
  check-dependencies     检查依赖
  check-configuration    检查配置
  check-tests            检查测试/门禁入口
  check-quality          检查脚本语法和轻量质量项

Options:
  --root <path>          指定工作区根目录
  --verbose              输出更多细节
  --summary-json         输出低 token JSON 摘要，不展开逐项日志
  --fix                  保留兼容参数；当前不做自动修复
  -h, --help             显示帮助
USAGE
}

is_command() {
  case "${1:-}" in
    check-all|check-structure|check-dependencies|check-configuration|check-tests|check-quality)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

parse_args() {
  if [[ $# -gt 0 ]]; then
    if is_command "$1"; then
      COMMAND="$1"
      shift
    elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
      usage
      exit 0
    elif [[ -d "$1" ]]; then
      ROOT_DIR="$(cd "$1" && pwd)"
      shift
      if [[ $# -gt 0 ]] && is_command "$1"; then
        COMMAND="$1"
        shift
      fi
    fi
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root)
        [[ $# -ge 2 ]] || { log_error "--root requires a path"; exit 1; }
        ROOT_DIR="$(cd "$2" && pwd)"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --summary-json)
        SUMMARY_JSON=true
        shift
        ;;
      --fix)
        FIX=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "未知参数: $1"
        usage
        exit 1
        ;;
    esac
  done
}

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "${value}"
}

emit_summary_json() {
  local registry="${ROOT_DIR}/subrepos/registry.csv"
  local branch adk_version locked_commit gitlink_commit active_repos disabled_repos gitlinks check_scripts
  branch="$(git -C "${ROOT_DIR}" branch --show-current 2>/dev/null || true)"
  adk_version="$(awk -F': ' '$1=="version"{print $2; exit}' "${ROOT_DIR}/agent-dev-kit/manifest.yaml" 2>/dev/null || true)"
  locked_commit="$(awk -F'=' '$1=="agent-dev-kit.commit"{print $2; exit}' "${ROOT_DIR}/adk.lock" 2>/dev/null || true)"
  gitlink_commit="$(git -C "${ROOT_DIR}" ls-files -s agent-dev-kit 2>/dev/null | awk '$1=="160000"{print $2; exit}')"
  active_repos="$(awk -F',' 'NR>1 && $6=="yes" && $8=="active"{count++} END{print count+0}' "${registry}" 2>/dev/null || echo 0)"
  disabled_repos="$(awk -F',' 'NR>1 && ($6!="yes" || $8!="active"){count++} END{print count+0}' "${registry}" 2>/dev/null || echo 0)"
  gitlinks="$(git -C "${ROOT_DIR}" ls-files -s 2>/dev/null | awk '$1=="160000"{count++} END{print count+0}')"
  check_scripts="$(find "${ROOT_DIR}/scripts" -maxdepth 1 -type f -name 'check-*.sh' 2>/dev/null | wc -l | tr -d ' ')"

  local strict_state="unknown"
  if [[ -n "${locked_commit}" && -n "${gitlink_commit}" && "${locked_commit}" == "${gitlink_commit}" ]]; then
    strict_state="ok"
  elif [[ -n "${locked_commit}" || -n "${gitlink_commit}" ]]; then
    strict_state="drift"
  fi

  printf '{'
  printf '"root":%s,' "$(json_string "${ROOT_DIR}")"
  printf '"branch":%s,' "$(json_string "${branch}")"
  printf '"adk_version":%s,' "$(json_string "${adk_version}")"
  printf '"adk_lock_state":%s,' "$(json_string "${strict_state}")"
  printf '"active_repos":%s,' "${active_repos}"
  printf '"disabled_repos":%s,' "${disabled_repos}"
  printf '"tracked_subrepos":%s,' "${gitlinks}"
  printf '"check_scripts":%s' "${check_scripts}"
  printf '}\n'
}

require_file() {
  local path="$1"
  [[ -f "${ROOT_DIR}/${path}" ]] || { log_error "缺失文件: ${path}"; return 1; }
  "${VERBOSE}" && log_info "文件存在: ${path}"
  return 0
}

require_dir() {
  local path="$1"
  [[ -d "${ROOT_DIR}/${path}" ]] || { log_error "缺失目录: ${path}"; return 1; }
  "${VERBOSE}" && log_info "目录存在: ${path}"
  return 0
}

check_structure() {
  local failed=0
  log_info "检查工作区目录结构: ${ROOT_DIR}"

  local dirs=(
    "agent-dev-kit"
    "docs"
    "reports"
    "scripts"
    "subrepos"
  )
  local files=(
    "README.md"
    ".gitmodules"
    "adk.lock"
    "AGENTS.md"
    "subrepos/registry.csv"
    "subrepos/adoption-matrix.md"
    "subrepos/phase-gate.env"
    "scripts/check-all.sh"
    "agent-dev-kit/manifest.yaml"
  )

  for dir in "${dirs[@]}"; do
    require_dir "${dir}" || failed=1
  done
  for file in "${files[@]}"; do
    require_file "${file}" || failed=1
  done

  (( failed == 0 )) && log_success "目录结构检查通过"
  return "${failed}"
}

check_dependencies() {
  local failed=0
  log_info "检查依赖"

  if (( BASH_VERSINFO[0] < 4 )); then
    log_error "Bash 版本过低: ${BASH_VERSION} (需要 4.0+)"
    failed=1
  else
    "${VERBOSE}" && log_info "Bash: ${BASH_VERSION}"
  fi

  local tools=(git rg awk sed sort find wc mktemp)
  for tool in "${tools[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      log_error "缺失依赖: ${tool}"
      failed=1
    else
      "${VERBOSE}" && log_info "依赖存在: ${tool}"
    fi
  done

  (( failed == 0 )) && log_success "依赖检查通过"
  return "${failed}"
}

check_configuration() {
  local failed=0
  local registry="${ROOT_DIR}/subrepos/registry.csv"
  local gate="${ROOT_DIR}/subrepos/phase-gate.env"
  local expected_header="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade"
  log_info "检查治理配置"

  if [[ "$(head -n 1 "${registry}")" != "${expected_header}" ]]; then
    log_error "registry.csv 表头不匹配"
    failed=1
  fi

  local bad_rows
  bad_rows="$(awk -F',' 'NR > 1 && NF != 12 {print NR ":" NF ":" $0}' "${registry}")"
  if [[ -n "${bad_rows}" ]]; then
    log_error "registry.csv 存在非 12 列记录"
    printf '%s\n' "${bad_rows}" >&2
    failed=1
  fi

  if ! awk -F',' '$1=="codex" && $6=="no" && $8=="disabled" && $11=="pilot-first" {found=1} END {exit found ? 0 : 1}' "${registry}"; then
    log_error "codex registry 行未保持 disabled/pilot-first"
    failed=1
  fi

  local gitlink_count
  local submodule_count
  gitlink_count="$(git -C "${ROOT_DIR}" ls-files -s | awk '$1=="160000"{count++} END{print count+0}')"
  submodule_count="$(git -C "${ROOT_DIR}" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${gitlink_count}" != "${submodule_count}" ]]; then
    log_error ".gitmodules path 数量(${submodule_count})与 gitlink 数量(${gitlink_count})不一致"
    failed=1
  fi

  if ! rg -q '^allow_upstream_sync=(yes|no)$' "${gate}"; then
    log_error "phase-gate.env 缺少合法 allow_upstream_sync"
    failed=1
  fi

  (( failed == 0 )) && log_success "治理配置检查通过"
  return "${failed}"
}

check_tests() {
  local failed=0
  log_info "检查测试和门禁入口"

  local scripts=(
    "scripts/check-all.sh"
    "scripts/check-adk-harden-readiness.sh"
    "scripts/check-global-codex-target-policy.sh"
    "scripts/check-workspace-entrypoints.sh"
    "agent-dev-kit/tests/run_all.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ ! -f "${ROOT_DIR}/${script}" ]]; then
      log_error "缺失测试/门禁入口: ${script}"
      failed=1
    else
      "${VERBOSE}" && log_info "入口存在: ${script}"
    fi
  done

  (( failed == 0 )) && log_success "测试和门禁入口检查通过"
  return "${failed}"
}

check_quality() {
  local failed=0
  log_info "检查脚本语法"

  while IFS= read -r script; do
    if ! bash -n "${script}"; then
      log_error "Shell 语法错误: ${script#${ROOT_DIR}/}"
      failed=1
    fi
  done < <(find "${ROOT_DIR}/scripts" "${ROOT_DIR}/agent-dev-kit/scripts" -maxdepth 1 -type f -name '*.sh' | sort)

  if "${FIX}"; then
    log_warning "--fix 当前为兼容参数，不自动修改文件"
  fi

  (( failed == 0 )) && log_success "脚本语法检查通过"
  return "${failed}"
}

check_all() {
  local failed=0
  check_structure || failed=1
  check_dependencies || failed=1
  check_configuration || failed=1
  check_tests || failed=1
  check_quality || failed=1

  if (( failed == 0 )); then
    log_success "工作区健康检查通过"
  else
    log_error "工作区健康检查失败"
  fi
  return "${failed}"
}

parse_args "$@"

if "${SUMMARY_JSON}"; then
  emit_summary_json
  exit 0
fi

case "${COMMAND}" in
  check-all) check_all ;;
  check-structure) check_structure ;;
  check-dependencies) check_dependencies ;;
  check-configuration) check_configuration ;;
  check-tests) check_tests ;;
  check-quality) check_quality ;;
  *) log_error "未知命令: ${COMMAND}"; usage; exit 1 ;;
esac
