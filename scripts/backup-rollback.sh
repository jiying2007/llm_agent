#!/usr/bin/env bash
set -euo pipefail

# 安装备份和回滚脚本

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
安装备份和回滚脚本

Usage:
  ./scripts/backup-rollback.sh <command> [options]

Commands:
  backup                 创建备份
  restore                恢复备份
  list                   列出备份
  rollback               回滚到指定版本
  verify                 验证备份完整性

Options:
  --target <target>      安装目标目录
  --backup-dir <dir>     备份目录
  --version <version>    版本号
  --force                强制执行
  -h, --help             显示帮助

Examples:
  ./scripts/backup-rollback.sh backup --target ~/.codex
  ./scripts/backup-rollback.sh restore --target ~/.codex --version 20260505
  ./scripts/backup-rollback.sh list --target ~/.codex
  ./scripts/backup-rollback.sh rollback --target ~/.codex --version 20260505
USAGE
}

# 创建备份
create_backup() {
    local target="$1"
    local backup_dir="$2"
    local version="$3"
    
    log_info "创建备份: $target -> $backup_dir"
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 生成备份文件名
    local backup_file="$backup_dir/backup-${version}-$(date +%Y%m%d%H%M%S).tar.gz"
    
    # 创建备份
    if [[ -d "$target" ]]; then
        tar -czf "$backup_file" -C "$(dirname "$target")" "$(basename "$target")"
        log_success "备份创建成功: $backup_file"
        
        # 创建备份元数据
        cat > "$backup_dir/backup-${version}-$(date +%Y%m%d%H%M%S).meta" <<EOF
version: $version
target: $target
backup_file: $backup_file
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
created_by: $(whoami)
EOF
        
        return 0
    else
        log_error "目标目录不存在: $target"
        return 1
    fi
}

# 恢复备份
restore_backup() {
    local target="$1"
    local backup_dir="$2"
    local version="$3"
    local force="$4"
    
    log_info "恢复备份: $version -> $target"
    
    # 查找备份文件
    local backup_file
    backup_file=$(find "$backup_dir" -name "backup-${version}-*.tar.gz" | sort -r | head -1)
    
    if [[ -z "$backup_file" ]]; then
        log_error "未找到版本 $version 的备份"
        return 1
    fi
    
    # 检查目标目录
    if [[ -d "$target" && "$force" != "true" ]]; then
        log_warning "目标目录已存在: $target"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消恢复"
            return 0
        fi
    fi
    
    # 恢复备份
    if [[ -d "$target" ]]; then
        rm -rf "$target"
    fi
    
    tar -xzf "$backup_file" -C "$(dirname "$target")"
    log_success "备份恢复成功: $backup_file"
    
    return 0
}

# 列出备份
list_backups() {
    local backup_dir="$1"
    
    log_info "列出备份: $backup_dir"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "备份目录不存在: $backup_dir"
        return 0
    fi
    
    # 列出备份文件
    local backups
    backups=$(find "$backup_dir" -name "backup-*.tar.gz" | sort -r)
    
    if [[ -z "$backups" ]]; then
        log_warning "没有找到备份"
        return 0
    fi
    
    echo "可用备份:"
    echo "======================================"
    
    for backup in $backups; do
        local filename
        filename=$(basename "$backup")
        local version
        version=$(echo "$filename" | sed -n 's/backup-\([^-]*\)-.*/\1/p')
        local date
        date=$(echo "$filename" | sed -n 's/backup-[^-]*-\([0-9]*\)\.tar\.gz/\1/p')
        
        echo "版本: $version"
        echo "日期: $date"
        echo "文件: $backup"
        echo "======================================"
    done
    
    return 0
}

# 回滚到指定版本
rollback_version() {
    local target="$1"
    local backup_dir="$2"
    local version="$3"
    local force="$4"
    
    log_info "回滚到版本: $version"
    
    # 创建当前状态的备份
    local current_version="pre-rollback-$(date +%Y%m%d%H%M%S)"
    create_backup "$target" "$backup_dir" "$current_version"
    
    # 恢复指定版本
    restore_backup "$target" "$backup_dir" "$version" "$force"
    
    log_success "回滚完成"
    
    return 0
}

# 验证备份完整性
verify_backup() {
    local backup_dir="$1"
    local version="$2"
    
    log_info "验证备份完整性: $version"
    
    # 查找备份文件
    local backup_file
    backup_file=$(find "$backup_dir" -name "backup-${version}-*.tar.gz" | sort -r | head -1)
    
    if [[ -z "$backup_file" ]]; then
        log_error "未找到版本 $version 的备份"
        return 1
    fi
    
    # 验证备份文件
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_success "备份文件完整: $backup_file"
        return 0
    else
        log_error "备份文件损坏: $backup_file"
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
    
    local target=""
    local backup_dir="$ROOT_DIR/.backups"
    local version=""
    local force="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                target="$2"
                shift 2
                ;;
            --backup-dir)
                backup_dir="$2"
                shift 2
                ;;
            --version)
                version="$2"
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
        backup)
            if [[ -z "$target" ]]; then
                log_error "缺少--target参数"
                exit 1
            fi
            version="${version:-$(date +%Y%m%d)}"
            create_backup "$target" "$backup_dir" "$version"
            ;;
        restore)
            if [[ -z "$target" || -z "$version" ]]; then
                log_error "缺少--target或--version参数"
                exit 1
            fi
            restore_backup "$target" "$backup_dir" "$version" "$force"
            ;;
        list)
            list_backups "$backup_dir"
            ;;
        rollback)
            if [[ -z "$target" || -z "$version" ]]; then
                log_error "缺少--target或--version参数"
                exit 1
            fi
            rollback_version "$target" "$backup_dir" "$version" "$force"
            ;;
        verify)
            if [[ -z "$version" ]]; then
                log_error "缺少--version参数"
                exit 1
            fi
            verify_backup "$backup_dir" "$version"
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