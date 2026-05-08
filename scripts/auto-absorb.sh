#!/usr/bin/env bash
# auto-absorb.sh — AI 自动吸收 + 人工审核
# 用法: bash scripts/auto-absorb.sh [repo_name]
# 模式:
#   --auto     全自动（跳过审核点，适合 CI）
#   --dry-run  只分析不执行（默认）
#   --apply    执行吸收（每个审核点暂停等确认）

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LLM_AGENT_ROOT="$(dirname "$SCRIPT_DIR")"
GDK_ROOT="$LLM_AGENT_ROOT/agent-dev-kit"
REPORT_DIR="$LLM_AGENT_ROOT/reports"
BACKUP_DIR="$LLM_AGENT_ROOT/.absorb-backup/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR"

REPO_NAME="${1:-}"
MODE="${2:---dry-run}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC} $*"; }

# ============================================================
# 审核点机制
# ============================================================
REVIEW_LOG="$REPORT_DIR/absorb-review-$(date +%Y%m%d_%H%M%S).md"
REVIEW_COUNT=0
APPROVED_COUNT=0
SKIPPED_COUNT=0

review_point() {
    local action="$1"
    local detail="$2"
    local risk="${3:-low}"
    REVIEW_COUNT=$((REVIEW_COUNT + 1))

    echo "### 审核点 #$REVIEW_COUNT: $action" >> "$REVIEW_LOG"
    echo "- 风险级别: $risk" >> "$REVIEW_LOG"
    echo "- 详情: $detail" >> "$REVIEW_LOG"

    if [[ "$MODE" == "--auto" ]]; then
        echo "- 决策: 自动批准" >> "$REVIEW_LOG"
        APPROVED_COUNT=$((APPROVED_COUNT + 1))
        return 0
    elif [[ "$MODE" == "--dry-run" ]]; then
        echo "- 决策: 预演模式，跳过执行" >> "$REVIEW_LOG"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 1
    else
        echo ""
        log_warn "审核点 #$REVIEW_COUNT: $action (风险: $risk)"
        echo "  详情: $detail"
        read -p "  批准? [y/N/s(跳过)] " choice
        case "$choice" in
            y|Y) echo "- 决策: 人工批准" >> "$REVIEW_LOG"; APPROVED_COUNT=$((APPROVED_COUNT + 1)); return 0 ;;
            s|S) echo "- 决策: 人工跳过" >> "$REVIEW_LOG"; SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); return 1 ;;
            *)   echo "- 决策: 人工拒绝" >> "$REVIEW_LOG"; SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); return 1 ;;
        esac
    fi
}

# ============================================================
# 自动吸收函数
# ============================================================

# 吸收单个文件
absorb_file() {
    local src="$1"
    local dst="$2"
    local desc="$3"

    if [[ ! -f "$src" ]]; then
        log_warn "源文件不存在: $src"
        return 1
    fi

    # 备份目标文件（如果存在）
    if [[ -f "$dst" ]]; then
        local backup_path="$BACKUP_DIR/$(basename "$dst")"
        cp "$dst" "$backup_path"
    fi

    mkdir -p "$(dirname "$dst")"

    if review_point "吸收文件" "$desc" "low"; then
        cp "$src" "$dst"
        log_ok "已吸收: $(basename "$dst")"
        return 0
    fi
    return 1
}

# 合并文档（追加到目标文件）
merge_doc() {
    local src="$1"
    local dst="$2"
    local section_title="$3"

    if [[ ! -f "$src" ]]; then
        log_warn "源文档不存在: $src"
        return 1
    fi

    if review_point "合并文档" "将 $section_title 合并到 $(basename "$dst")" "low"; then
        mkdir -p "$(dirname "$dst")"
        echo "" >> "$dst"
        echo "## $section_title" >> "$dst"
        echo "" >> "$dst"
        echo "*来源: $(basename "$src") — 自动吸收于 $(date +%Y-%m-%d)*" >> "$dst"
        echo "" >> "$dst"
        cat "$src" >> "$dst"
        log_ok "已合并: $section_title → $(basename "$dst")"
        return 0
    fi
    return 1
}

# 提取跨仓库模式
extract_pattern() {
    local repo="$1"
    local pattern_name="$2"
    local pattern_desc="$3"
    local skill_name="adk-${pattern_name}"

    local skill_dir="$GDK_ROOT/skills/$skill_name"
    if [[ -d "$skill_dir" ]]; then
        log_info "Skill 已存在: $skill_name，跳过"
        return 0
    fi

    if review_point "提取模式" "从 $repo 提取模式: $pattern_name → skills/$skill_name" "medium"; then
        mkdir -p "$skill_dir"
        cat > "$skill_dir/SKILL.md" << EOF
---
name: $skill_name
description: $pattern_desc (从 $repo 提取)
---

# $pattern_name

## 来源
- 仓库: $repo
- 提取时间: $(date +%Y-%m-%d)
- 提取方式: auto-absorb.sh 自动识别

## 模式描述
$pattern_desc

## 待完善
- [ ] 添加详细使用说明
- [ ] 添加示例代码
- [ ] 添加测试用例
EOF
        log_ok "已提取模式: $skill_name"
        return 0
    fi
    return 1
}

# ============================================================
# 主流程
# ============================================================

main() {
    log_info "=== AI 自动吸收流水线 ==="
    log_info "模式: $MODE"
    log_info "目标仓库: ${REPO_NAME:-全部}"
    echo ""

    echo "# 自动吸收审核日志" > "$REVIEW_LOG"
    echo "- 时间: $(date)" >> "$REVIEW_LOG"
    echo "- 模式: $MODE" >> "$REVIEW_LOG"
    echo "- 目标: ${REPO_NAME:-全部}" >> "$REVIEW_LOG"
    echo "" >> "$REVIEW_LOG"

    # ---- 阶段 1: 吸收 superpowers ----
    if [[ -z "$REPO_NAME" || "$REPO_NAME" == "superpowers" ]]; then
        log_info "阶段 1: 吸收 superpowers"
        local sp_dir="$LLM_AGENT_ROOT/skills-superpowers"

        if [[ -d "$sp_dir" ]]; then
            # 吸收核心文档
            absorb_file "$sp_dir/AGENTS.md" \
                "$GDK_ROOT/docs/reference/superpowers-agents.md" \
                "superpowers 的 AGENTS.md 含贡献规范（94% PR 拒绝率策略）"

            # 吸收 workflow 文档
            if [[ -d "$sp_dir/docs/workflows" ]]; then
                for wf in "$sp_dir/docs/workflows"/*.md; do
                    [[ -f "$wf" ]] || continue
                    local wf_name=$(basename "$wf" .md)
                    absorb_file "$wf" \
                        "$GDK_ROOT/docs/workflows/superpowers-$wf_name.md" \
                        "superpowers workflow: $wf_name"
                done
            fi

            # 吸收 best practices
            if [[ -d "$sp_dir/docs/best-practices" ]]; then
                for bp in "$sp_dir/docs/best-practices"/*.md; do
                    [[ -f "$bp" ]] || continue
                    local bp_name=$(basename "$bp" .md)
                    absorb_file "$bp" \
                        "$GDK_ROOT/docs/best-practices/superpowers-$bp_name.md" \
                        "superpowers best practice: $bp_name"
                done
            fi
        else
            log_warn "superpowers 目录不存在: $sp_dir"
        fi
        echo ""
    fi

    # ---- 阶段 2: 吸收 workspace 文档 ----
    if [[ -z "$REPO_NAME" || "$REPO_NAME" == "workspace" ]]; then
        log_info "阶段 2: 吸收 workspace 文档"

        # 10 个可直接合并的文档
        local -A WORKSPACE_DOCS=(
            ["docs/llm-agent-maintenance-guide.md"]="docs/runbooks/workspace-maintenance-guide.md"
            ["docs/setup-gitlab-runner.md"]="docs/runbooks/gitlab-runner-setup.md"
            ["reports/codex-pilot-report.md"]="docs/runbooks/codex-pilot-evidence.md"
            ["subrepos/adoption-matrix.md"]="docs/reference-adoption-matrix.md"
            ["codex-cookbook/codex-cookbook.md"]="docs/best-practices-cookbook.md"
            ["ai-coding-guide/cheatsheet.md"]="docs/reference/tool-cheatsheet.md"
            ["scripts/README.md"]="docs/runbooks/workspace-scripts-guide.md"
            ["artifact-gated-agents/AGENTS.md"]="docs/runbooks/artifact-gated-protocol-full.md"
        )

        for src_rel in "${!WORKSPACE_DOCS[@]}"; do
            local src="$LLM_AGENT_ROOT/$src_rel"
            local dst="$GDK_ROOT/${WORKSPACE_DOCS[$src_rel]}"
            absorb_file "$src" "$dst" "workspace 文档: $src_rel"
        done

        # AGENTS.md 需要特殊处理（提取意图路由表）
        if [[ -f "$LLM_AGENT_ROOT/AGENTS.md" ]]; then
            absorb_file "$LLM_AGENT_ROOT/AGENTS.md" \
                "$GDK_ROOT/docs/workspace-governance.md" \
                "workspace AGENTS.md 含意图路由表和治理全景"
        fi
        echo ""
    fi

    # ---- 阶段 3: 跨仓库模式检测 ----
    log_info "阶段 3: 跨仓库模式检测"

    # 检测常见模式
    local -A PATTERNS=(
        ["artifact-gating"]="Artifact 门禁协议：统一标签+状态+交接"
        ["pilot-framework"]="Pilot 试跑框架：场景+证据+门禁"
        ["intake-workflow"]="子仓接入工作流：扫描+分析+决策"
    )

    for pattern in "${!PATTERNS[@]}"; do
        extract_pattern "workspace" "$pattern" "${PATTERNS[$pattern]}"
    done
    echo ""

    # ---- 阶段 4: 生成审核报告 ----
    log_info "阶段 4: 生成审核报告"

    cat >> "$REVIEW_LOG" << EOF

## 吸收统计

| 指标 | 数量 |
|------|------|
| 审核点总数 | $REVIEW_COUNT |
| 已批准 | $APPROVED_COUNT |
| 已跳过 | $SKIPPED_COUNT |
| 备份目录 | $BACKUP_DIR |

## 回滚方法

\`\`\`bash
# 回滚所有变更
cp -r $BACKUP_DIR/* $GDK_ROOT/
\`\`\`
EOF

    log_ok "审核报告: $REVIEW_LOG"
    log_ok "备份目录: $BACKUP_DIR"
    echo ""
    log_info "=== 吸收完成 ==="
    log_info "总审核点: $REVIEW_COUNT | 批准: $APPROVED_COUNT | 跳过: $SKIPPED_COUNT"
}

main "$@"
