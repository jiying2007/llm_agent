#!/usr/bin/env bash
set -euo pipefail

# 版本锁定和升级路径脚本

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
版本锁定和升级路径脚本

Usage:
  ./scripts/version-manager.sh <command> [options]

Commands:
  current                显示当前版本
  lock                   锁定版本
  unlock                 解锁版本
  upgrade                升级版本
  downgrade              降级版本
  compare                比较版本
  changelog              生成变更日志

Options:
  --version <version>    版本号
  --target <target>      目标版本
  --force                强制执行
  -h, --help             显示帮助

Examples:
  ./scripts/version-manager.sh current
  ./scripts/version-manager.sh lock --version 1.0.0
  ./scripts/version-manager.sh upgrade --target 1.1.0
  ./scripts/version-manager.sh compare --version 1.0.0 --target 1.1.0
USAGE
}

# 获取当前版本
get_current_version() {
    if [[ -f "$ROOT_DIR/manifest.yaml" ]]; then
        grep "^version:" "$ROOT_DIR/manifest.yaml" | awk '{print $2}' | tr -d '"'
    else
        echo "unknown"
    fi
}

# 显示当前版本
show_current_version() {
    local version
    version=$(get_current_version)
    log_info "当前版本: $version"
    echo "$version"
}

# 锁定版本
lock_version() {
    local version="$1"
    
    log_info "锁定版本: $version"
    
    # 更新manifest.yaml
    if [[ -f "$ROOT_DIR/manifest.yaml" ]]; then
        sed -i "s/^version:.*$/version: $version/" "$ROOT_DIR/manifest.yaml"
        log_success "版本已锁定: $version"
    else
        log_error "manifest.yaml不存在"
        return 1
    fi
    
    # 创建版本锁定文件
    cat > "$ROOT_DIR/.version-lock" <<EOF
version: $version
locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
locked_by: $(whoami)
EOF
    
    log_success "版本锁定文件已创建: .version-lock"
    return 0
}

# 解锁版本
unlock_version() {
    log_info "解锁版本"
    
    # 删除版本锁定文件
    if [[ -f "$ROOT_DIR/.version-lock" ]]; then
        rm -f "$ROOT_DIR/.version-lock"
        log_success "版本已解锁"
    else
        log_warning "版本锁定文件不存在"
    fi
    
    return 0
}

# 升级版本
upgrade_version() {
    local target_version="$1"
    local force="$2"
    
    log_info "升级版本到: $target_version"
    
    # 获取当前版本
    local current_version
    current_version=$(get_current_version)
    
    # 检查版本锁定
    if [[ -f "$ROOT_DIR/.version-lock" && "$force" != "true" ]]; then
        log_error "版本已锁定，使用--force强制升级"
        return 1
    fi
    
    # 比较版本
    if [[ "$current_version" == "$target_version" ]]; then
        log_warning "目标版本与当前版本相同"
        return 0
    fi
    
    # 创建备份
    if [[ -f "$ROOT_DIR/scripts/backup-rollback.sh" ]]; then
        bash "$ROOT_DIR/scripts/backup-rollback.sh" backup --target "$ROOT_DIR" --version "$current_version"
    fi
    
    # 更新版本
    lock_version "$target_version"
    
    # 运行升级脚本（如果存在）
    if [[ -f "$ROOT_DIR/scripts/upgrade.sh" ]]; then
        log_info "运行升级脚本..."
        bash "$ROOT_DIR/scripts/upgrade.sh" "$current_version" "$target_version"
    fi
    
    log_success "版本升级完成: $current_version -> $target_version"
    return 0
}

# 降级版本
downgrade_version() {
    local target_version="$1"
    local force="$2"
    
    log_info "降级版本到: $target_version"
    
    # 获取当前版本
    local current_version
    current_version=$(get_current_version)
    
    # 检查版本锁定
    if [[ -f "$ROOT_DIR/.version-lock" && "$force" != "true" ]]; then
        log_error "版本已锁定，使用--force强制降级"
        return 1
    fi
    
    # 比较版本
    if [[ "$current_version" == "$target_version" ]]; then
        log_warning "目标版本与当前版本相同"
        return 0
    fi
    
    # 创建备份
    if [[ -f "$ROOT_DIR/scripts/backup-rollback.sh" ]]; then
        bash "$ROOT_DIR/scripts/backup-rollback.sh" backup --target "$ROOT_DIR" --version "$current_version"
    fi
    
    # 更新版本
    lock_version "$target_version"
    
    # 运行降级脚本（如果存在）
    if [[ -f "$ROOT_DIR/scripts/downgrade.sh" ]]; then
        log_info "运行降级脚本..."
        bash "$ROOT_DIR/scripts/downgrade.sh" "$current_version" "$target_version"
    fi
    
    log_success "版本降级完成: $current_version -> $target_version"
    return 0
}

# 比较版本
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    log_info "比较版本: $version1 vs $version2"
    
    # 解析版本号
    local IFS='.'
    read -ra v1 <<< "$version1"
    read -ra v2 <<< "$version2"
    
    # 比较主版本号
    if [[ ${v1[0]} -gt ${v2[0]} ]]; then
        echo "$version1 > $version2"
    elif [[ ${v1[0]} -lt ${v2[0]} ]]; then
        echo "$version1 < $version2"
    else
        # 比较次版本号
        if [[ ${v1[1]} -gt ${v2[1]} ]]; then
            echo "$version1 > $version2"
        elif [[ ${v1[1]} -lt ${v2[1]} ]]; then
            echo "$version1 < $version2"
        else
            # 比较修订版本号
            if [[ ${v1[2]} -gt ${v2[2]} ]]; then
                echo "$version1 > $version2"
            elif [[ ${v1[2]} -lt ${v2[2]} ]]; then
                echo "$version1 < $version2"
            else
                echo "$version1 == $version2"
            fi
        fi
    fi
}

# 生成变更日志
generate_changelog() {
    local version="$1"
    
    log_info "生成变更日志: $version"
    
    # 创建变更日志文件
    local changelog_file="$ROOT_DIR/CHANGELOG-$version.md"
    
    cat > "$changelog_file" <<EOF
# 变更日志 - $version

## 版本信息
- 版本号: $version
- 发布日期: $(date +%Y-%m-%d)
- 维护者: $(whoami)

## 变更内容

### 新增功能
- 待补充

### 改进优化
- 待补充

### 修复问题
- 待补充

### 已知问题
- 待补充

## 升级指南

### 从上一版本升级
1. 备份当前版本
2. 下载新版本
3. 运行升级脚本
4. 验证升级结果

### 回滚指南
1. 使用备份恢复
2. 运行回滚脚本
3. 验证回滚结果

## 相关链接
- 文档: docs/
- 问题反馈: issues/
- 贡献指南: docs/CONTRIBUTING.md
EOF
    
    log_success "变更日志已生成: $changelog_file"
    return 0
}

# 主函数
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    local version=""
    local target=""
    local force="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                version="$2"
                shift 2
                ;;
            --target)
                target="$2"
                shift 2
                ;;
            --force)
                force="true"
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
        current)
            show_current_version
            ;;
        lock)
            if [[ -z "$version" ]]; then
                log_error "缺少--version参数"
                exit 1
            fi
            lock_version "$version"
            ;;
        unlock)
            unlock_version
            ;;
        upgrade)
            if [[ -z "$target" ]]; then
                log_error "缺少--target参数"
                exit 1
            fi
            upgrade_version "$target" "$force"
            ;;
        downgrade)
            if [[ -z "$target" ]]; then
                log_error "缺少--target参数"
                exit 1
            fi
            downgrade_version "$target" "$force"
            ;;
        compare)
            if [[ -z "$version" || -z "$target" ]]; then
                log_error "缺少--version或--target参数"
                exit 1
            fi
            compare_versions "$version" "$target"
            ;;
        changelog)
            version="${version:-$(get_current_version)}"
            generate_changelog "$version"
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