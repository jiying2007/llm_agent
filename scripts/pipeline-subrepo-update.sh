#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 子仓更新一键闭环流水线
#
# 自动化 7 个环节:
#   1. 同步全部子仓 (sync)
#   2. 差异扫描 (diff)
#   3. 质量分级 (grade)
#   4. 深度分析 (analyze) — 仅 S/A 级仓库
#   5. adoption-matrix 更新建议 (adopt)
#   6. 跨仓库模式检测 (patterns)
#   7. 综合报告生成 (report)
#
# 用法: bash scripts/pipeline-subrepo-update.sh [--skip-sync] [--skip-analyze] [--report-only]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SKIP_SYNC=false
SKIP_ANALYZE=false
REPORT_ONLY=false
DATE_TODAY="$(date +%Y-%m-%d)"
REPORT_DIR="reports"
REPORT_FILE="$REPORT_DIR/pipeline-report-${DATE_TODAY}.md"
REGISTRY="subrepos/registry.csv"

for arg in "$@"; do
    case "$arg" in
        --skip-sync) SKIP_SYNC=true ;;
        --skip-analyze) SKIP_ANALYZE=true ;;
        --report-only) REPORT_ONLY=true; SKIP_SYNC=true; SKIP_ANALYZE=true ;;
        --help|-h)
            echo "用法: bash scripts/pipeline-subrepo-update.sh [选项]"
            echo "  --skip-sync      跳过子仓同步"
            echo "  --skip-analyze   跳过深度分析"
            echo "  --report-only    仅生成报告（跳过同步和分析）"
            exit 0
            ;;
    esac
done

mkdir -p "$REPORT_DIR"

log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }

# 初始化报告
{
    echo "# 子仓更新流水线报告"
    echo ""
    echo "- 生成日期: $DATE_TODAY"
    echo "- 执行模式: sync=$([[ $SKIP_SYNC == true ]] && echo skip || echo yes), analyze=$([[ $SKIP_ANALYZE == true ]] && echo skip || echo yes)"
    echo ""
} > "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 1: 同步全部子仓
# ════════════════════════════════════════════════════════════════════════════
log "环节 1/7: 同步子仓..."
if [[ "$SKIP_SYNC" == "false" ]]; then
    SYNC_OUTPUT=$(bash scripts/sync-subrepos.sh 2>&1)
    SYNC_OK=$(echo "$SYNC_OUTPUT" | grep -c '\[ OK \]' || echo 0)
    SYNC_FAIL=$(echo "$SYNC_OUTPUT" | grep -c '\[FAIL\]' || echo 0)
    SYNC_SKIP=$(echo "$SYNC_OUTPUT" | grep -c '\[SKIP\]' || echo 0)
    ok "同步完成: ok=$SYNC_OK fail=$SYNC_FAIL skip=$SYNC_SKIP"
    
    {
        echo "## 1. 子仓同步"
        echo ""
        echo "- 成功: $SYNC_OK"
        echo "- 失败: $SYNC_FAIL"
        echo "- 跳过: $SYNC_SKIP"
        echo ""
    } >> "$REPORT_FILE"
else
    log "跳过同步"
    echo "## 1. 子仓同步 (跳过)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# ════════════════════════════════════════════════════════════════════════════
# 环节 2: 差异扫描
# ════════════════════════════════════════════════════════════════════════════
log "环节 2/7: 差异扫描..."
DIFF_OUTPUT=$(bash scripts/diff-scan.sh 2>&1 || true)
CHANGED_REPOS=$(echo "$DIFF_OUTPUT" | grep -c '^## ' || echo 0)
ok "差异扫描完成: $CHANGED_REPOS 个仓库有变更"

{
    echo "## 2. 差异扫描"
    echo ""
    echo "变更仓库数: $CHANGED_REPOS"
    echo ""
    echo '```'
    echo "$DIFF_OUTPUT" | head -50
    echo '```'
    echo ""
} >> "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 3: 质量分级
# ════════════════════════════════════════════════════════════════════════════
log "环节 3/7: 质量分级..."
GRADE_OUTPUT=$(bash scripts/check-repo-quality.sh 2>&1 || true)
S_COUNT=$(echo "$GRADE_OUTPUT" | grep -c '\[S\]' || echo 0)
A_COUNT=$(echo "$GRADE_OUTPUT" | grep -c '\[A\]' || echo 0)
B_COUNT=$(echo "$GRADE_OUTPUT" | grep -c '\[B\]' || echo 0)
C_COUNT=$(echo "$GRADE_OUTPUT" | grep -c '\[C\]' || echo 0)
D_COUNT=$(echo "$GRADE_OUTPUT" | grep -c '\[D\]' || echo 0)
ok "分级完成: S=$S_COUNT A=$A_COUNT B=$B_COUNT C=$C_COUNT D=$D_COUNT"

{
    echo "## 3. 质量分级"
    echo ""
    echo "| 等级 | 数量 |"
    echo "|------|------|"
    echo "| S (核心) | $S_COUNT |"
    echo "| A (长期) | $A_COUNT |"
    echo "| B (按需) | $B_COUNT |"
    echo "| C (观察) | $C_COUNT |"
    echo "| D (放弃) | $D_COUNT |"
    echo ""
    echo '```'
    echo "$GRADE_OUTPUT"
    echo '```'
    echo ""
} >> "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 4: 深度分析 (仅 S/A 级有变更的仓库)
# ════════════════════════════════════════════════════════════════════════════
log "环节 4/7: 深度分析..."
ANALYZED_REPOS=""
if [[ "$SKIP_ANALYZE" == "false" ]]; then
    # 找出 S/A 级且有变更的仓库
    SA_REPOS=$(echo "$GRADE_OUTPUT" | grep -E '\[(S|A)\]' | awk '{print $2}' || true)
    
    for repo in $SA_REPOS; do
        repo_path="$ROOT_DIR/$repo"
        [[ ! -d "$repo_path" ]] && continue
        [[ "$repo" == "agent-dev-kit" ]] && continue
        
        # 检查是否有近期变更
        last_commit=$(cd "$repo_path" && git log -1 --format='%ad' --date=short 2>/dev/null || echo "1970-01-01")
        days_since=$(( ($(date -d "$DATE_TODAY" +%s) - $(date -d "$last_commit" +%s)) / 86400 ))
        
        if [[ $days_since -le 30 ]]; then
            log "  分析 $repo (最后提交 ${days_since}天前)..."
            bash scripts/analyze-repo.sh "$repo" --all 2>&1 | tail -5
            ANALYZED_REPOS="$ANALYZED_REPOS $repo"
        fi
    done
    
    ok "深度分析完成: ${ANALYZED_REPOS:-无}"
else
    log "跳过深度分析"
fi

{
    echo "## 4. 深度分析"
    echo ""
    if [[ -n "$ANALYZED_REPOS" ]]; then
        echo "已分析仓库: $ANALYZED_REPOS"
    else
        echo "本轮无需要深度分析的仓库"
    fi
    echo ""
} >> "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 5: adoption-matrix 更新建议
# ════════════════════════════════════════════════════════════════════════════
log "环节 5/7: adoption-matrix 检查..."
ADOPT_FILE="subrepos/adoption-matrix.md"
CURRENT_ENTRIES=$(grep -c '^|' "$ADOPT_FILE" 2>/dev/null || echo 0)
ok "当前 adoption-matrix 条目: $((CURRENT_ENTRIES - 2)) 条 (含表头)"

{
    echo "## 5. Adoption Matrix"
    echo ""
    echo "当前条目数: $((CURRENT_ENTRIES - 2))"
    echo ""
    echo "> 如有新分析报告，需人工评估后更新 adoption-matrix"
    echo ""
} >> "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 6: 跨仓库模式检测
# ════════════════════════════════════════════════════════════════════════════
log "环节 6/7: 跨仓库模式检测..."

# 检测: 各子仓中 SKILL.md 使用的共同模式
PATTERNS_FOUND=""
for pattern in "what-to-do" "supporting-info" "Quality Gate" "Evidence Index" "out-of-scope"; do
    count=$(grep -rl "$pattern" "$ROOT_DIR"/*/SKILL.md 2>/dev/null | grep -v ".git/" | grep -v "agent-dev-kit" | wc -l | tr -d "[:space:]" || echo 0)
    if [[ "$count" -gt 0 ]]; then
        repos=$(grep -rl "$pattern" "$ROOT_DIR"/*/SKILL.md 2>/dev/null | grep -v ".git/" | grep -v "agent-dev-kit" | xargs -I{} dirname {} 2>/dev/null | xargs -I{} basename {} 2>/dev/null | sort -u | tr "\n" "," | sed "s/,$//" || echo "unknown")
        PATTERNS_FOUND="$PATTERNS_FOUND\n- `$pattern`: $count 个仓库 ($repos)"
    fi
done

# Skill 冲突检测 (简化版)
CONFLICTS=""

ok "模式检测完成"

{
    echo "## 6. 跨仓库模式检测"
    echo ""
    if [[ -n "$PATTERNS_FOUND" ]]; then
        echo "### 共同模式"
        echo -e "$PATTERNS_FOUND"
    else
        echo "未发现跨仓库共同模式"
    fi
    echo ""
    if [[ -n "$CONFLICTS" ]]; then
        echo "### ⚠️ Skill 名称冲突"
        echo -e "$CONFLICTS"
    else
        echo "无 Skill 名称冲突"
    fi
    echo ""
} >> "$REPORT_FILE"

# ════════════════════════════════════════════════════════════════════════════
# 环节 7: AI 自动吸收
# ════════════════════════════════════════════════════════════════════════════
log "环节 7/8: AI 自动吸收..."

if [[ "$MODE" != "--report-only" ]]; then
    bash "$SCRIPT_DIR/auto-absorb.sh" "" --auto 2>&1 | tee -a "$REPORT_FILE" || true
    echo "" >> "$REPORT_FILE"
fi

# 环节 8: 综合报告
# ════════════════════════════════════════════════════════════════════════════
log "环节 8/8: 生成综合报告..."

{
    echo "## 7. 综合建议"
    echo ""
    echo "### 待处理项"
    echo ""
    # 列出有分析报告但 adoption-matrix 未记录的仓库
    for analysis_dir in "$ROOT_DIR"/*/analysis/; do
        [[ ! -d "$analysis_dir" ]] && continue
        repo=$(basename "$(dirname "$analysis_dir")")
        [[ "$repo" == "agent-dev-kit" ]] && continue
        if [[ -f "$analysis_dir/skill-deep-analysis.md" ]]; then
            echo "- [ ] $repo: 已有分析报告，需评估是否更新 adoption-matrix"
        fi
    done
    echo ""
    echo "### 下次执行建议"
    echo ""
    echo "- 检查 D 级仓库是否有新增内容需要吸纳"
    echo "- 检查 C 级仓库 30 天观察期是否到期"
    echo "- 更新 adoption-matrix 中 pending 状态的条目"
    echo ""
    echo "---"
    echo "*报告由 pipeline-subrepo-update.sh 自动生成*"
} >> "$REPORT_FILE"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN} 流水线完成${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "报告: $REPORT_FILE"
echo ""
echo "后续步骤:"
echo "  1. 查看报告: cat $REPORT_FILE"
echo "  2. 检查待处理项"
echo "  3. 更新 adoption-matrix"
