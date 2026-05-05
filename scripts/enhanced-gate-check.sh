#!/usr/bin/env bash
set -euo pipefail

# 增强门禁检查脚本
# 借鉴artifact-gated-agents的标准化产物标签体系和门禁机制

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 使用说明
usage() {
    cat <<USAGE
增强门禁检查脚本

Usage:
  ./scripts/enhanced-gate-check.sh <command> [options]

Commands:
  check-artifacts    检查产物完整性
  check-gates        检查门禁条件
  check-roles        检查角色职责
  check-workflow     检查工作流状态
  validate-all       执行所有检查

Options:
  --change <change-id>   # 变更ID
  --stage <stage>        # 检查阶段
  --strict               # 严格模式
  -h, --help             # 显示帮助

Examples:
  ./scripts/enhanced-gate-check.sh check-artifacts --change modbus-tcp
  ./scripts/enhanced-gate-check.sh check-gates --change modbus-tcp --stage proposed
  ./scripts/enhanced-gate-check.sh validate-all --change modbus-tcp --strict
USAGE
}

# 检查单个文件中的artifact标签
check_artifact_in_file() {
    local file="$1"
    local artifact="$2"
    
    if grep -q "\[artifact:${artifact}\]" "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查artifact状态字段
check_artifact_status() {
    local file="$1"
    local artifact="$2"
    
    # 提取artifact块中的status字段
    local status
    status=$(awk -v artifact="${artifact}" '
        $0 ~ "^[[]artifact:" artifact "[]]" {in_block=1; next}
        in_block && $0 ~ "^[[]artifact:" {in_block=0}
        in_block && $0 ~ "^status:" {
            value=$0
            sub("^status:[ ]*", "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "$file" 2>/dev/null || true)
    
    echo "$status"
}

# 检查artifact完整性
check_artifacts() {
    local change_dir="$1"
    local stage="$2"
    local strict="$3"
    
    log_info "检查产物完整性: $change_dir"
    
    local required_artifacts=()
    local missing_artifacts=()
    local invalid_artifacts=()
    
    # 根据阶段确定必需的产物
    case "$stage" in
        proposed)
            required_artifacts=("PRD" "UserStory" "TaskBreakdown")
            ;;
        applied)
            required_artifacts=("PRD" "UserStory" "TaskBreakdown" "ImplementationPlan")
            ;;
        verified)
            required_artifacts=("PRD" "UserStory" "TaskBreakdown" "ImplementationPlan" "TestReport")
            ;;
        review-passed)
            required_artifacts=("PRD" "UserStory" "TaskBreakdown" "ImplementationPlan" "TestReport" "ReviewReport")
            ;;
        *)
            required_artifacts=("PRD" "UserStory" "TaskBreakdown" "ImplementationPlan" "TestReport" "ReviewReport")
            ;;
    esac
    
    # 检查每个必需的artifact
    for artifact in "${required_artifacts[@]}"; do
        local found=false
        local status_valid=true
        
        # 在所有md文件中查找artifact
        for file in "$change_dir"/*.md; do
            if [[ -f "$file" ]]; then
                if check_artifact_in_file "$file" "$artifact"; then
                    found=true
                    
                    # 检查状态字段
                    local status
                    status=$(check_artifact_status "$file" "$artifact")
                    
                    if [[ -z "$status" ]]; then
                        status_valid=false
                        invalid_artifacts+=("$artifact (缺少status字段)")
                    elif [[ "$strict" == "true" && "$status" != "READY" && "$status" != "PASS" ]]; then
                        status_valid=false
                        invalid_artifacts+=("$artifact (status=$status, 需要READY或PASS)")
                    fi
                    break
                fi
            fi
        done
        
        if [[ "$found" == "false" ]]; then
            missing_artifacts+=("$artifact")
        elif [[ "$status_valid" == "false" ]]; then
            # 已经添加到invalid_artifacts
            :
        fi
    done
    
    # 输出检查结果
    if [[ ${#missing_artifacts[@]} -eq 0 && ${#invalid_artifacts[@]} -eq 0 ]]; then
        log_success "产物检查通过"
        return 0
    else
        if [[ ${#missing_artifacts[@]} -gt 0 ]]; then
            log_error "缺失产物:"
            for artifact in "${missing_artifacts[@]}"; do
                echo "  - $artifact"
            done
        fi
        
        if [[ ${#invalid_artifacts[@]} -gt 0 ]]; then
            log_error "无效产物:"
            for artifact in "${invalid_artifacts[@]}"; do
                echo "  - $artifact"
            done
        fi
        
        return 1
    fi
}

# 检查门禁条件
check_gates() {
    local change_dir="$1"
    local stage="$2"
    local strict="$3"
    
    log_info "检查门禁条件: $change_dir (阶段: $stage)"
    
    local gate_errors=()
    
    # 检查状态文件
    local state_file="$change_dir/state.yaml"
    if [[ ! -f "$state_file" ]]; then
        gate_errors+=("缺少状态文件: state.yaml")
    else
        local current_stage
        current_stage=$(awk '/^stage:/ {print $2; exit}' "$state_file" 2>/dev/null || true)
        
        if [[ -z "$current_stage" ]]; then
            gate_errors+=("状态文件中缺少stage字段")
        elif [[ "$strict" == "true" && "$current_stage" != "$stage" ]]; then
            gate_errors+=("当前阶段($current_stage)与要求阶段($stage)不匹配")
        fi
    fi
    
    # 检查必需文件
    local required_files=("proposal.md" "design.md" "tasks.md" "checklist.md" "negative-results.md")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$change_dir/$file" ]]; then
            gate_errors+=("缺少必需文件: $file")
        fi
    done
    
    # 检查历史记录
    local history_file="$change_dir/history.log"
    if [[ ! -f "$history_file" ]]; then
        gate_errors+=("缺少历史记录文件: history.log")
    fi
    
    # 输出检查结果
    if [[ ${#gate_errors[@]} -eq 0 ]]; then
        log_success "门禁检查通过"
        return 0
    else
        log_error "门禁检查失败:"
        for error in "${gate_errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查角色职责
check_roles() {
    local change_dir="$1"
    
    log_info "检查角色职责: $change_dir"
    
    local role_errors=()
    
    # 检查每个artifact的owner字段
    for file in "$change_dir"/*.md; do
        if [[ -f "$file" ]]; then
            # 提取所有artifact块
            local artifacts
            artifacts=$(grep -o '\[artifact:[A-Za-z]*\]' "$file" 2>/dev/null || true)
            
            for artifact in $artifacts; do
                local artifact_name
                artifact_name=$(echo "$artifact" | sed 's/\[artifact:\(.*\)\]/\1/')
                
                # 提取owner字段
                local owner
                owner=$(awk -v artifact="${artifact_name}" '
                    $0 ~ "^[[]artifact:" artifact "[]]" {in_block=1; next}
                    in_block && $0 ~ "^[[]artifact:" {in_block=0}
                    in_block && $0 ~ "^owner:" {
                        value=$0
                        sub("^owner:[ ]*", "", value)
                        gsub(/^"|"$/, "", value)
                        print value
                        exit
                    }
                ' "$file" 2>/dev/null || true)
                
                if [[ -z "$owner" ]]; then
                    role_errors+=("$artifact_name 缺少owner字段")
                fi
            done
        fi
    done
    
    # 输出检查结果
    if [[ ${#role_errors[@]} -eq 0 ]]; then
        log_success "角色职责检查通过"
        return 0
    else
        log_error "角色职责检查失败:"
        for error in "${role_errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查工作流状态
check_workflow() {
    local change_dir="$1"
    
    log_info "检查工作流状态: $change_dir"
    
    local workflow_errors=()
    
    # 检查状态文件
    local state_file="$change_dir/state.yaml"
    if [[ ! -f "$state_file" ]]; then
        workflow_errors+=("缺少状态文件")
    else
        local current_stage
        current_stage=$(awk '/^stage:/ {print $2; exit}' "$state_file" 2>/dev/null || true)
        local owner
        owner=$(awk '/^owner:/ {print $2; exit}' "$state_file" 2>/dev/null || true)
        local updated_at
        updated_at=$(awk '/^updated_at:/ {print $2; exit}' "$state_file" 2>/dev/null || true)
        
        if [[ -z "$current_stage" ]]; then
            workflow_errors+=("状态文件中缺少stage字段")
        fi
        
        if [[ -z "$owner" ]]; then
            workflow_errors+=("状态文件中缺少owner字段")
        fi
        
        if [[ -z "$updated_at" ]]; then
            workflow_errors+=("状态文件中缺少updated_at字段")
        fi
    fi
    
    # 检查历史记录
    local history_file="$change_dir/history.log"
    if [[ ! -f "$history_file" ]]; then
        workflow_errors+=("缺少历史记录文件")
    else
        local history_lines
        history_lines=$(wc -l < "$history_file" 2>/dev/null || echo "0")
        if [[ "$history_lines" -eq 0 ]]; then
            workflow_errors+=("历史记录文件为空")
        fi
    fi
    
    # 输出检查结果
    if [[ ${#workflow_errors[@]} -eq 0 ]]; then
        log_success "工作流状态检查通过"
        return 0
    else
        log_error "工作流状态检查失败:"
        for error in "${workflow_errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 执行所有检查
validate_all() {
    local change_dir="$1"
    local stage="$2"
    local strict="$3"
    
    log_info "执行所有检查: $change_dir"
    
    local all_passed=true
    
    # 检查产物完整性
    if ! check_artifacts "$change_dir" "$stage" "$strict"; then
        all_passed=false
    fi
    
    # 检查门禁条件
    if ! check_gates "$change_dir" "$stage" "$strict"; then
        all_passed=false
    fi
    
    # 检查角色职责
    if ! check_roles "$change_dir"; then
        all_passed=false
    fi
    
    # 检查工作流状态
    if ! check_workflow "$change_dir"; then
        all_passed=false
    fi
    
    # 输出最终结果
    if [[ "$all_passed" == "true" ]]; then
        log_success "所有检查通过"
        return 0
    else
        log_error "检查失败，请修复上述问题"
        return 1
    fi
}

# 主函数
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    local change_id=""
    local stage=""
    local strict="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --change)
                change_id="$2"
                shift 2
                ;;
            --stage)
                stage="$2"
                shift 2
                ;;
            --strict)
                strict="true"
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
    
    # 验证change_id
    if [[ -z "$change_id" ]]; then
        log_error "缺少--change参数"
        exit 1
    fi
    
    # 构建变更目录路径
    local change_dir="$ROOT_DIR/docs/changes/$change_id"
    
    if [[ ! -d "$change_dir" ]]; then
        log_error "变更目录不存在: $change_dir"
        exit 1
    fi
    
    # 执行命令
    case "$command" in
        check-artifacts)
            if [[ -z "$stage" ]]; then
                stage="proposed"
            fi
            check_artifacts "$change_dir" "$stage" "$strict"
            ;;
        check-gates)
            if [[ -z "$stage" ]]; then
                stage="proposed"
            fi
            check_gates "$change_dir" "$stage" "$strict"
            ;;
        check-roles)
            check_roles "$change_dir"
            ;;
        check-workflow)
            check_workflow "$change_dir"
            ;;
        validate-all)
            if [[ -z "$stage" ]]; then
                stage="proposed"
            fi
            validate_all "$change_dir" "$stage" "$strict"
            ;;
        *)
            log_error "未知命令: $command"
            usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"