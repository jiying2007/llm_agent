#!/usr/bin/env bash
set -euo pipefail

# 子仓库质量自动分级脚本
# 用法: bash scripts/check-repo-quality.sh [--report] [--auto-disable]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="$ROOT_DIR/subrepos/registry.csv"
REPORT="$ROOT_DIR/subrepos/repo-grading-report.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

AUTO_DISABLE=false
GENERATE_REPORT=false

for arg in "$@"; do
    case "$arg" in
        --auto-disable) AUTO_DISABLE=true ;;
        --report) GENERATE_REPORT=true ;;
        --help|-h)
            echo "用法: bash scripts/check-repo-quality.sh [--report] [--auto-disable]"
            echo "  --report        生成 Markdown 报告"
            echo "  --auto-disable  自动禁用 D 级仓库"
            exit 0
            ;;
    esac
done

TODAY=$(date +%Y-%m-%d)
NOW_EPOCH=$(date -d "$TODAY" +%s)

echo "=== 子仓库质量分级 ($TODAY) ==="
echo ""

# 读取 registry (跳过表头)
tail -n +2 "$REGISTRY" | while IFS=',' read -r repo group pri sync branch enabled notes status owner reviewed policy rest; do
    # 跳过 self 和已 disabled
    [[ "$repo" == "agent-dev-kit" ]] && continue
    [[ "$repo" == "codex" ]] && continue

    repo_path="$ROOT_DIR/$repo"
    [[ ! -d "$repo_path" ]] && continue

    # 采集指标
    last_commit=$(cd "$repo_path" && git log -1 --format='%ad' --date=short 2>/dev/null || echo "1970-01-01")
    total_commits=$(cd "$repo_path" && git rev-list --count HEAD 2>/dev/null || echo 0)
    has_agents=$(test -f "$repo_path/AGENTS.md" && echo 1 || echo 0)
    skill_count=$(find "$repo_path" -name 'SKILL.md' -not -path '*/.git/*' 2>/dev/null | wc -l)

    # 计算距今天数
    last_epoch=$(date -d "$last_commit" +%s 2>/dev/null || echo 0)
    days_since=$(( (NOW_EPOCH - last_epoch) / 86400 ))

    # 评分
    score=0

    # 活跃度
    if [[ $days_since -le 7 ]]; then score=$((score + 30))
    elif [[ $days_since -le 30 ]]; then score=$((score + 25))
    elif [[ $days_since -le 60 ]]; then score=$((score + 15))
    elif [[ $days_since -le 120 ]]; then score=$((score + 5))
    fi

    # 内容丰富度
    if [[ $total_commits -ge 100 ]]; then score=$((score + 25))
    elif [[ $total_commits -ge 20 ]]; then score=$((score + 15))
    elif [[ $total_commits -ge 5 ]]; then score=$((score + 8))
    fi

    # 使命相关性
    case "$group" in
        workflow-core|agent-ecosystem|skill-pool) score=$((score + 25)) ;;
        knowledge|delivery) score=$((score + 15)) ;;
        config|reference|runtime-target) score=$((score + 5)) ;;
    esac

    # 可用性
    if [[ "$enabled" == "no" ]]; then score=$((score - 20)); fi

    # 独特性加分
    case "$repo" in
        superpowers|superpowers-zh|OpenSpec|agent-skills|mattpocock-skills) score=$((score + 10)) ;;
    esac

    # 重叠扣分
    case "$repo" in
        Migrationed_skills) score=$((score - 10)) ;;
    esac

    # 分级
    if [[ $score -ge 70 ]]; then grade="S"
    elif [[ $score -ge 55 ]]; then grade="A"
    elif [[ $score -ge 40 ]]; then grade="B"
    elif [[ $score -ge 20 ]]; then grade="C"
    else grade="D"
    fi

    # 输出
    color="$NC"
    case "$grade" in
        S) color="$GREEN" ;;
        A) color="$CYAN" ;;
        B) color="$NC" ;;
        C) color="$YELLOW" ;;
        D) color="$RED" ;;
    esac

    printf "${color}[%s]${NC} %-30s score=%-3d days=%-4d commits=%-5d group=%-18s enabled=%s\n"         "$grade" "$repo" "$score" "$days_since" "$total_commits" "$group" "$enabled"

    # 自动禁用 D 级
    if [[ "$AUTO_DISABLE" == "true" && "$grade" == "D" && "$enabled" == "yes" ]]; then
        echo -e "  ${RED}[AUTO-DISABLE]${NC} Disabling $repo (grade=D)"
        sed -i "s/^$repo,/$repo,/" "$REGISTRY"
    fi
done

echo ""
echo "=== 分级完成 ==="
echo "报告: $REPORT"
echo "用法: bash scripts/check-repo-quality.sh --report --auto-disable"
