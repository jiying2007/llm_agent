#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install-pre-commit-hook.sh
# 安装 git pre-commit hook，执行自动化质量检查
# 用法: bash scripts/install-pre-commit-hook.sh [WORKSPACE_ROOT]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
cd "$WORKSPACE_ROOT"

log() { echo "[install-pre-commit-hook] $*"; }

# ── 检查是否为 git 仓库 ──────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "错误: 当前目录不是 git 仓库: $WORKSPACE_ROOT" >&2
    exit 1
fi

GIT_DIR="$(git rev-parse --git-dir)"
HOOK_PATH="$GIT_DIR/hooks/pre-commit"
HOOKS_DIR="$GIT_DIR/hooks"

mkdir -p "$HOOKS_DIR"

# ── 备份已有 hook ─────────────────────────────────────────────────────────
if [[ -f "$HOOK_PATH" ]]; then
    BACKUP_PATH="${HOOK_PATH}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$HOOK_PATH" "$BACKUP_PATH"
    log "已备份现有 hook 到: $BACKUP_PATH"
fi

# ── 写入 pre-commit hook ─────────────────────────────────────────────────
cat > "$HOOK_PATH" << 'HOOK_EOF'
#!/usr/bin/env bash
set -euo pipefail

# pre-commit hook: 自动化质量检查
# 安装来源: scripts/install-pre-commit-hook.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAIL_COUNT=0

fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "========================================="
echo " pre-commit 质量检查"
echo "========================================="

# ── 检查 1: Shell 脚本语法检查 (bash -n) ──────────────────────────────────
echo ""
echo "--- 检查 Shell 脚本语法 ---"
SHELL_CHECK_PASSED=true
for shfile in $(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.sh$' || true); do
    if [[ -f "$shfile" ]]; then
        if bash -n "$shfile" 2>/dev/null; then
            pass "$shfile"
        else
            fail "$shfile: 语法错误 (bash -n)"
            SHELL_CHECK_PASSED=false
        fi
    fi
done
if $SHELL_CHECK_PASSED; then
    # 即使没有 .sh 文件变更，也对 scripts/ 下全部做一次检查
    SCRIPTS_DIR="scripts"
    if [[ -d "$SCRIPTS_DIR" ]]; then
        for shfile in "$SCRIPTS_DIR"/*.sh; do
            [[ -f "$shfile" ]] || continue
            if bash -n "$shfile" 2>/dev/null; then
                pass "$shfile"
            else
                fail "$shfile: 语法错误 (bash -n)"
            fi
        done
    fi
fi

# ── 检查 2: AGENTS.md 中引用的文件是否存在 ────────────────────────────────
echo ""
echo "--- 检查 AGENTS.md 引用文件 ---"
AGENTS_FILE="AGENTS.md"
if [[ -f "$AGENTS_FILE" ]]; then
    # 提取 markdown 中反引号路径引用（排除表格分隔符和纯链接标记）
    REFS_PASSED=true
    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        # 去除可能的尾部标点
        ref="${ref%%)*}"
        ref="${ref%%;*}"
        ref="${ref%% *}"
        [[ -z "$ref" ]] && continue
        # 跳过明显不是文件路径的项
        [[ "$ref" == http* ]] && continue
        [[ "$ref" == '#'* ]] && continue
        [[ "$ref" == *'|'* ]] && continue
        [[ ${#ref} -lt 3 ]] && continue
        # 检查文件/目录是否存在
        if [[ ! -e "$ref" ]]; then
            warn "AGENTS.md 引用不存在: $ref"
            # 只警告，不算失败（部分路径可能在子仓内）
        fi
    done < <(grep -oP '`[^`]+`' "$AGENTS_FILE" | sed 's/`//g' | grep -E '\.(md|sh|py|csv|json|yaml|yml|env)' | sort -u)
    pass "AGENTS.md 引用检查完成"
else
    warn "AGENTS.md 不存在，跳过引用检查"
fi

# ── 检查 3: registry.csv 格式检查 ─────────────────────────────────────────
echo ""
echo "--- 检查 registry.csv 格式 ---"
REGISTRY_FILE="subrepos/registry.csv"
if [[ -f "$REGISTRY_FILE" ]]; then
    REG_PASSED=true

    # 检查 header 行
    EXPECTED_HEADER="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade"
    ACTUAL_HEADER="$(head -1 "$REGISTRY_FILE")"
    # 兼容 11 列(旧)和 12 列(新，含 grade)
    EXPECTED_HEADER_OLD="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy"
    if [[ "$ACTUAL_HEADER" == "$EXPECTED_HEADER" || "$ACTUAL_HEADER" == "$EXPECTED_HEADER_OLD" ]]; then
        pass "registry.csv 表头格式正确"
    else
        fail "registry.csv 表头不匹配"
        echo "  期望: $EXPECTED_HEADER"
        echo "  实际: $ACTUAL_HEADER"
        REG_PASSED=false
    fi

    # 检查每行列数
    LINE_NUM=1
    EXPECTED_COLS=12
    EXPECTED_COLS_OLD=11
    while IFS= read -r line; do
        LINE_NUM=$((LINE_NUM + 1))
        [[ -z "$line" ]] && continue
        # 跳过注释行
        [[ "$line" == '#'* ]] && continue
        ACTUAL_COLS="$(echo "$line" | awk -F',' '{print NF}')"
        if [[ "$ACTUAL_COLS" -ne "$EXPECTED_COLS" && "$ACTUAL_COLS" -ne "$EXPECTED_COLS_OLD" ]]; then
            fail "registry.csv 第 ${LINE_NUM} 行: 期望 ${EXPECTED_COLS} 或 ${EXPECTED_COLS_OLD} 列，实际 ${ACTUAL_COLS} 列"
            REG_PASSED=false
        fi
    done < <(tail -n +2 "$REGISTRY_FILE")

    # 检查 enabled 字段值 (兼容 11/12 列)
    while IFS=',' read -r repo group priority sync_mode branch enabled notes status owner last_reviewed intake_policy grade; do
        [[ "$repo" == "repo" ]] && continue
        if [[ "$enabled" != "yes" && "$enabled" != "no" ]]; then
            fail "registry.csv: 仓库 '$repo' enabled 字段值非法: '$enabled' (应为 yes/no)"
            REG_PASSED=false
        fi
        if [[ "$status" != "active" && "$status" != "disabled" ]]; then
            fail "registry.csv: 仓库 '$repo' status 字段值非法: '$status' (应为 active/disabled)"
            REG_PASSED=false
        fi
    done < "$REGISTRY_FILE"

    if $REG_PASSED; then
        pass "registry.csv 格式检查通过"
    fi
else
    warn "registry.csv 不存在，跳过格式检查"
fi

# ── 汇总 ────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}pre-commit 检查失败 ($FAIL_COUNT 项未通过)${NC}"
    echo "修复后重新提交，或使用 git commit --no-verify 跳过检查。"
    exit 1
else
    echo -e "${GREEN}pre-commit 检查全部通过${NC}"
    exit 0
fi
HOOK_EOF

chmod +x "$HOOK_PATH"

log "pre-commit hook 已安装到: $HOOK_PATH"
echo ""
echo "========================================="
echo "pre-commit hook 安装成功!"
echo "路径: $HOOK_PATH"
echo ""
echo "检查项:"
echo "  1. Shell 脚本语法 (bash -n)"
echo "  2. AGENTS.md 引用文件存在性"
echo "  3. registry.csv 格式正确性"
echo ""
echo "跳过检查: git commit --no-verify"
echo "卸载: rm $HOOK_PATH"
echo "========================================="
