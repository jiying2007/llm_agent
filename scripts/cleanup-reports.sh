#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# cleanup-reports.sh
# 清理/归档旧报告
# 用法:
#   bash scripts/cleanup-reports.sh [WORKSPACE_ROOT] [--dry-run] [--days N]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT=""
DRY_RUN=false
DAYS=30

# ── 参数解析 ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --days)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                DAYS="$2"
                shift 2
            else
                echo "错误: --days 需要一个正整数参数" >&2
                exit 1
            fi
            ;;
        -*)
            echo "未知参数: $1" >&2
            echo "用法: bash scripts/cleanup-reports.sh [WORKSPACE_ROOT] [--dry-run] [--days N]" >&2
            exit 1
            ;;
        *)
            if [[ -z "$WORKSPACE_ROOT" ]]; then
                WORKSPACE_ROOT="$1"
            fi
            shift
            ;;
    esac
done

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(dirname "$SCRIPT_DIR")}"
cd "$WORKSPACE_ROOT"

REPORTS_DIR="reports"
ARCHIVE_DIR="reports/archive"

log() { echo "[cleanup-reports] $*"; }

# ── 检查 reports 目录 ────────────────────────────────────────────────────
if [[ ! -d "$REPORTS_DIR" ]]; then
    log "reports/ 目录不存在，无需清理。"
    exit 0
fi

# ── 查找过期文件 ─────────────────────────────────────────────────────────
MOVED_COUNT=0
SKIPPED_COUNT=0

log "扫描 ${REPORTS_DIR}/ 中超过 ${DAYS} 天的报告..."
if $DRY_RUN; then
    log "[DRY-RUN 模式] 只显示会移动的文件，不会实际操作。"
fi

find "$REPORTS_DIR" -maxdepth 1 -type f -mtime +"$DAYS" -name "*.md" | sort | while read -r filepath; do
    filename="$(basename "$filepath")"

    # 跳过 .template.md 文件
    if [[ "$filename" == *.template.md ]]; then
        log "  SKIP (模板文件): $filepath"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    if $DRY_RUN; then
        log "  WOULD MOVE: $filepath -> $ARCHIVE_DIR/$filename"
    else
        mkdir -p "$ARCHIVE_DIR"
        mv "$filepath" "$ARCHIVE_DIR/$filename"
        log "  MOVED: $filepath -> $ARCHIVE_DIR/$filename"
    fi
    MOVED_COUNT=$((MOVED_COUNT + 1))
done

# ── 汇总 ────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
if $DRY_RUN; then
    echo "[DRY-RUN] 模拟清理完成"
else
    echo "清理完成"
fi
echo "  阈值: ${DAYS} 天"
echo "  将移动文件数: ${MOVED_COUNT}"
echo "  跳过文件数 (模板): ${SKIPPED_COUNT}"
echo "========================================="
