#!/usr/bin/env bash
set -euo pipefail

# 子仓库深度分析脚本
# 用法: bash scripts/analyze-repo.sh <repo-name> [--prompt] [--skill] [--all]
#
# 功能:
#   --prompt  仅执行 Prompt 逆向分析
#   --skill   仅执行 Skill 深度拆解
#   --all     执行全部分析（默认）
#
# 输出: subrepos/<repo-name>/analysis/ 目录下

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADK="$ROOT_DIR/agent-dev-kit"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "用法: bash scripts/analyze-repo.sh <repo-name> [--prompt] [--skill] [--all]"
    echo ""
    echo "选项:"
    echo "  --prompt   仅执行 Prompt 逆向分析 (adk-repo-prompt-analyzer)"
    echo "  --skill    仅执行 Skill 深度拆解 (adk-skill-deep-analyzer)"
    echo "  --all      执行全部分析（默认）"
    echo ""
    echo "示例:"
    echo "  bash scripts/analyze-repo.sh superpowers"
    echo "  bash scripts/analyze-repo.sh agent-skills --prompt"
    echo "  bash scripts/analyze-repo.sh mattpocock-skills --skill"
    exit 1
}

[[ $# -lt 1 ]] && usage

REPO="$1"
shift
MODE="all"
for arg in "$@"; do
    case "$arg" in
        --prompt) MODE="prompt" ;;
        --skill)  MODE="skill" ;;
        --all)    MODE="all" ;;
        --help|-h) usage ;;
    esac
done

REPO_PATH="$ROOT_DIR/$REPO"
[[ ! -d "$REPO_PATH" ]] && echo -e "${RED}[ERROR]${NC} 仓库不存在: $REPO_PATH" && exit 1

ANALYSIS_DIR="$REPO_PATH/analysis"
mkdir -p "$ANALYSIS_DIR"

echo -e "${CYAN}=== 子仓库深度分析: $REPO ===${NC}"
echo "模式: $MODE"
echo "输出: $ANALYSIS_DIR/"
echo ""

# ── Prompt 逆向分析 ──
if [[ "$MODE" == "all" || "$MODE" == "prompt" ]]; then
    echo -e "${YELLOW}[1/2] Prompt 逆向分析 (adk-repo-prompt-analyzer)${NC}"
    echo "  阶段 1: 项目结构探索..."
    
    # 基础结构统计
    total_files=$(find "$REPO_PATH" -not -path '*/.git/*' -type f | wc -l)
    md_files=$(find "$REPO_PATH" -name '*.md' -not -path '*/.git/*' | wc -l)
    skill_files=$(find "$REPO_PATH" -name 'SKILL.md' -not -path '*/.git/*' | wc -l)
    agent_files=$(find "$REPO_PATH" -name 'AGENTS.md' -not -path '*/.git/*' | wc -l)
    script_files=$(find "$REPO_PATH" -name '*.sh' -o -name '*.py' -o -name '*.js' | grep -v '.git/' | wc -l)
    
    echo "  文件: total=$total_files, md=$md_files, skill=$skill_files, agent=$agent_files, scripts=$script_files"
    
    echo "  阶段 2: 提示词识别..."
    # 搜索 prompt 相关文件
    prompt_files=$(find "$REPO_PATH" -not -path '*/.git/*' -type f \( -name '*prompt*' -o -name '*system*' -o -name '*instruction*' -o -name 'SKILL.md' -o -name 'AGENTS.md' \) | head -20)
    
    # 搜索代码中的 prompt 变量
    prompt_vars=$(grep -rn 'system_prompt\|user_prompt\|messages\|content=' "$REPO_PATH" --include='*.py' --include='*.js' --include='*.ts' 2>/dev/null | grep -v '.git/' | head -10)
    
    echo "  阶段 3: 生成报告..."
    {
        echo "# Prompt 逆向分析: $REPO"
        echo ""
        echo "- 生成日期: $(date +%Y-%m-%d)"
        echo "- 分析工具: adk-repo-prompt-analyzer"
        echo ""
        echo "## 项目结构"
        echo ""
        echo "| 指标 | 数值 |"
        echo "|------|------|"
        echo "| 总文件数 | $total_files |"
        echo "| Markdown | $md_files |"
        echo "| SKILL.md | $skill_files |"
        echo "| AGENTS.md | $agent_files |"
        echo "| 脚本文件 | $script_files |"
        echo ""
        echo "## Prompt 相关文件"
        echo ""
        echo '```'
        echo "$prompt_files"
        echo '```'
        echo ""
        echo "## 代码中的 Prompt 变量"
        echo ""
        if [[ -n "$prompt_vars" ]]; then
            echo '```'
            echo "$prompt_vars"
            echo '```'
        else
            echo "未发现代码级 prompt 变量（纯文档仓库）"
        fi
        echo ""
        echo "## 上下文工程模式"
        echo ""
        echo "> 待 AI Agent 补充分析: 渐进式加载、条件注入、模板填充等模式"
        echo ""
        echo "## 可借鉴点"
        echo ""
        echo "> 待 AI Agent 补充: 从以上数据提炼可被 adk 吸收的设计模式"
    } > "$ANALYSIS_DIR/prompt-analysis.md"
    
    echo -e "  ${GREEN}[完成]${NC} → $ANALYSIS_DIR/prompt-analysis.md"
    echo ""
fi

# ── Skill 深度拆解 ──
if [[ "$MODE" == "all" || "$MODE" == "skill" ]]; then
    echo -e "${YELLOW}[2/2] Skill 深度拆解 (adk-skill-deep-analyzer)${NC}"
    echo "  阶段 1: 结构扫描..."
    
    # 遍历所有 SKILL.md
    skill_list=""
    while IFS= read -r skill_md; do
        skill_dir=$(dirname "$skill_md")
        skill_name=$(basename "$skill_dir")
        skill_lines=$(wc -l < "$skill_md")
        has_scripts=$(test -d "$skill_dir/scripts" && echo "Y" || echo "N")
        has_refs=$(test -d "$skill_dir/references" && echo "Y" || echo "N")
        has_assets=$(test -d "$skill_dir/assets" && echo "Y" || echo "N")
        skill_list="$skill_list|$skill_name|$skill_lines|scripts=$has_scripts|refs=$has_refs|assets=$has_assets"
    done < <(find "$REPO_PATH" -name 'SKILL.md' -not -path '*/.git/*' 2>/dev/null)
    
    echo "  阶段 2: 生成报告..."
    {
        echo "# Skill 深度拆解: $REPO"
        echo ""
        echo "- 生成日期: $(date +%Y-%m-%d)"
        echo "- 分析工具: adk-skill-deep-analyzer"
        echo ""
        echo "## Skill 清单"
        echo ""
        echo "| Skill | 行数 | Scripts | References | Assets |"
        echo "|-------|------|---------|------------|--------|"
        if [[ -n "$skill_list" ]]; then
            echo "$skill_list" | while IFS='|' read -r _ name lines scripts refs assets; do
                echo "| $name | $lines | $scripts | $refs | $assets |"
            done
        else
            echo "| (无 SKILL.md) | - | - | - | - |"
        fi
        echo ""
        echo "## Skill 类型分布"
        echo ""
        echo "> 待 AI Agent 补充分析: 轻量知识型 / 流程编排型 / 工具集成型 / 混合型"
        echo ""
        echo "## 独特解法提炼"
        echo ""
        echo "> 待 AI Agent 补充: 通用做法 vs Skill 做法 vs 设计巧思 vs 适用边界"
        echo ""
        echo "## 5 维评分"
        echo ""
        echo "| 维度 | 分数 | 证据 |"
        echo "|------|------|------|"
        echo "| 痛点精准度 | /20 | 待评 |"
        echo "| 工作流清晰度 | /20 | 待评 |"
        echo "| 上下文效率 | /20 | 待评 |"
        echo "| 资源设计 | /20 | 待评 |"
        echo "| 可扩展性 | /20 | 待评 |"
        echo ""
        echo "## 可借鉴点"
        echo ""
        echo "> 待 AI Agent 补充: 提炼可被 adk 吸收的设计模式"
    } > "$ANALYSIS_DIR/skill-deep-analysis.md"
    
    echo -e "  ${GREEN}[完成]${NC} → $ANALYSIS_DIR/skill-deep-analysis.md"
    echo ""
fi

# ── 生成入口索引 ──
{
    echo "# 分析索引: $REPO"
    echo ""
    echo "- 生成日期: $(date +%Y-%m-%d)"
    echo "- 分析模式: $MODE"
    echo ""
    echo "## 分析报告"
    echo ""
    if [[ -f "$ANALYSIS_DIR/prompt-analysis.md" ]]; then
        echo "- [Prompt 逆向分析](prompt-analysis.md)"
    fi
    if [[ -f "$ANALYSIS_DIR/skill-deep-analysis.md" ]]; then
        echo "- [Skill 深度拆解](skill-deep-analysis.md)"
    fi
    echo ""
    echo "## 后续步骤"
    echo ""
    echo "1. AI Agent 读取上述报告，补充"待分析"部分"
    echo "2. 提取可借鉴点，更新 adoption-matrix.md"
    echo "3. 有价值内容吸纳到 agent-dev-kit"
} > "$ANALYSIS_DIR/README.md"

echo -e "${GREEN}=== 分析完成 ===${NC}"
echo "报告目录: $ANALYSIS_DIR/"
echo "后续: 让 AI Agent 读取报告并补充分析结论"
