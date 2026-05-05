#!/usr/bin/env bash
set -euo pipefail

# 健康检查脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
健康检查脚本

Usage:
  ./scripts/health-check.sh <command> [options]

Commands:
  check-all              执行所有健康检查
  check-structure        检查目录结构
  check-dependencies     检查依赖
  check-configuration    检查配置
  check-tests            检查测试
  check-quality          检查质量

Options:
  --verbose              详细输出
  --fix                  自动修复问题
  -h, --help             显示帮助

Examples:
  ./scripts/health-check.sh check-all
  ./scripts/health-check.sh check-structure --verbose
  ./scripts/health-check.sh check-tests --fix
USAGE
}

# 检查目录结构
check_structure() {
    local verbose="$1"
    
    log_info "检查目录结构..."
    
    local errors=()
    
    # 检查必需目录
    local required_dirs=(
        "agents"
        "skills"
        "optional-skills"
        "scripts"
        "tests"
        "docs"
        "templates"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$ROOT_DIR/$dir" ]]; then
            errors+=("缺失目录: $dir")
        elif [[ "$verbose" == "true" ]]; then
            log_info "目录存在: $dir"
        fi
    done
    
    # 检查必需文件
    local required_files=(
        "manifest.yaml"
        "README.md"
        "CONTEXT.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$ROOT_DIR/$file" ]]; then
            errors+=("缺失文件: $file")
        elif [[ "$verbose" == "true" ]]; then
            log_info "文件存在: $file"
        fi
    done
    
    # 输出结果
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "目录结构检查通过"
        return 0
    else
        log_error "目录结构检查失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查依赖
check_dependencies() {
    local verbose="$1"
    
    log_info "检查依赖..."
    
    local errors=()
    
    # 检查Bash版本
    local bash_version
    bash_version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ $(echo "$bash_version >= 4.0" | bc) -eq 0 ]]; then
        errors+=("Bash版本过低: $bash_version (需要 4.0+)")
    elif [[ "$verbose" == "true" ]]; then
        log_info "Bash版本: $bash_version"
    fi
    
    # 检查Git
    if ! command -v git &> /dev/null; then
        errors+=("未安装Git")
    elif [[ "$verbose" == "true" ]]; then
        log_info "Git已安装: $(git --version)"
    fi
    
    # 检查其他工具
    local tools=("tar" "gzip" "grep" "sed" "awk")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            errors+=("未安装$tool")
        elif [[ "$verbose" == "true" ]]; then
            log_info "$tool已安装"
        fi
    done
    
    # 输出结果
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "依赖检查通过"
        return 0
    else
        log_error "依赖检查失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查配置
check_configuration() {
    local verbose="$1"
    
    log_info "检查配置..."
    
    local errors=()
    
    # 检查manifest.yaml
    if [[ ! -f "$ROOT_DIR/manifest.yaml" ]]; then
        errors+=("缺失manifest.yaml")
    else
        # 检查必需字段
        local required_fields=("version" "profiles" "agents" "skills")
        for field in "${required_fields[@]}"; do
            if ! grep -q "^$field:" "$ROOT_DIR/manifest.yaml"; then
                errors+=("manifest.yaml缺少$field字段")
            elif [[ "$verbose" == "true" ]]; then
                log_info "manifest.yaml包含$field字段"
            fi
        done
    fi
    
    # 检查CONTEXT.md
    if [[ ! -f "$ROOT_DIR/CONTEXT.md" ]]; then
        errors+=("缺失CONTEXT.md")
    else
        # 检查核心概念
        local concepts=("Agent" "Skill" "Profile" "Workflow" "Artifact" "Gate")
        for concept in "${concepts[@]}"; do
            if ! grep -q "$concept" "$ROOT_DIR/CONTEXT.md"; then
                errors+=("CONTEXT.md缺少$concept概念")
            elif [[ "$verbose" == "true" ]]; then
                log_info "CONTEXT.md包含$concept概念"
            fi
        done
    fi
    
    # 输出结果
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "配置检查通过"
        return 0
    else
        log_error "配置检查失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查测试
check_tests() {
    local verbose="$1"
    local fix="$2"
    
    log_info "检查测试..."
    
    local errors=()
    
    # 检查测试目录
    if [[ ! -d "$ROOT_DIR/tests" ]]; then
        errors+=("缺失tests目录")
    else
        # 检查测试文件
        local test_files
        test_files=$(find "$ROOT_DIR/tests" -name "test_*.sh" -type f)
        
        if [[ -z "$test_files" ]]; then
            errors+=("没有测试文件")
        elif [[ "$verbose" == "true" ]]; then
            local test_count
            test_count=$(echo "$test_files" | wc -l)
            log_info "发现 $test_count 个测试文件"
        fi
        
        # 检查run_all.sh
        if [[ ! -f "$ROOT_DIR/tests/run_all.sh" ]]; then
            errors+=("缺失tests/run_all.sh")
        elif [[ "$verbose" == "true" ]]; then
            log_info "tests/run_all.sh存在"
        fi
    fi
    
    # 运行测试
    if [[ "$fix" == "true" ]]; then
        log_info "运行测试..."
        if bash "$ROOT_DIR/tests/run_all.sh" >/dev/null 2>&1; then
            log_success "测试通过"
        else
            errors+=("测试失败")
        fi
    fi
    
    # 输出结果
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "测试检查通过"
        return 0
    else
        log_error "测试检查失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 检查质量
check_quality() {
    local verbose="$1"
    
    log_info "检查质量..."
    
    local errors=()
    
    # 运行质量检查脚本
    if [[ -f "$ROOT_DIR/scripts/quality-gate-check.sh" ]]; then
        if ! bash "$ROOT_DIR/scripts/quality-gate-check.sh" check-all >/dev/null 2>&1; then
            errors+=("质量门禁检查失败")
        elif [[ "$verbose" == "true" ]]; then
            log_info "质量门禁检查通过"
        fi
    else
        errors+=("缺失quality-gate-check.sh脚本")
    fi
    
    # 运行验证脚本
    if [[ -f "$ROOT_DIR/scripts/validate_assets.sh" ]]; then
        if ! bash "$ROOT_DIR/scripts/validate_assets.sh" --strict >/dev/null 2>&1; then
            errors+=("资产验证失败")
        elif [[ "$verbose" == "true" ]]; then
            log_info "资产验证通过"
        fi
    else
        errors+=("缺失validate_assets.sh脚本")
    fi
    
    # 输出结果
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "质量检查通过"
        return 0
    else
        log_error "质量检查失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# 执行所有健康检查
check_all() {
    local verbose="$1"
    local fix="$2"
    
    log_info "执行所有健康检查..."
    
    local all_passed=true
    
    if ! check_structure "$verbose"; then
        all_passed=false
    fi
    
    if ! check_dependencies "$verbose"; then
        all_passed=false
    fi
    
    if ! check_configuration "$verbose"; then
        all_passed=false
    fi
    
    if ! check_tests "$verbose" "$fix"; then
        all_passed=false
    fi
    
    if ! check_quality "$verbose"; then
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        log_success "所有健康检查通过"
        return 0
    else
        log_error "健康检查失败"
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
    
    local verbose="false"
    local fix="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                verbose="true"
                shift
                ;;
            --fix)
                fix="true"
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
    
    case "$command" in
        check-all)
            check_all "$verbose" "$fix"
            ;;
        check-structure)
            check_structure "$verbose"
            ;;
        check-dependencies)
            check_dependencies "$verbose"
            ;;
        check-configuration)
            check_configuration "$verbose"
            ;;
        check-tests)
            check_tests "$verbose" "$fix"
            ;;
        check-quality)
            check_quality "$verbose"
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