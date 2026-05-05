#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# generate-weekly-report.sh
# 自动生成周报，汇总本周变更
# 用法: bash scripts/generate-weekly-report.sh [WORKSPACE_ROOT]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
cd "$WORKSPACE_ROOT"

DATE_TODAY="$(date +%Y-%m-%d)"
REPORT_PATH="reports/weekly-report-${DATE_TODAY}.md"
REGISTRY_CSV="subrepos/registry.csv"
ADOPTION_MATRIX="subrepos/adoption-matrix.md"
CHECK_SCRIPTS="scripts"

# ── helper ──────────────────────────────────────────────────────────────────
log() { echo "[weekly-report] $*"; }

mkdir -p reports

# ── 1. 本周 git 提交摘要 ───────────────────────────────────────────────────
log "收集最近 7 天 git 提交..."
GIT_LOG=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
    GIT_LOG="$(git log --since='7 days ago' --oneline --no-merges 2>/dev/null || true)"
fi
GIT_COMMIT_COUNT="$(echo "$GIT_LOG" | grep -c '[^ ]' || echo 0)"

# ── 2. 子仓同步状态 ───────────────────────────────────────────────────────
log "读取 registry.csv 同步状态..."
REGISTRY_TABLE=""
TOTAL_REPOS=0
ENABLED_REPOS=0
DISABLED_REPOS=0
if [[ -f "$REGISTRY_CSV" ]]; then
    while IFS=',' read -r repo group priority sync_mode branch enabled notes status owner last_reviewed intake_policy; do
        [[ "$repo" == "repo" ]] && continue  # skip header
        TOTAL_REPOS=$((TOTAL_REPOS + 1))
        if [[ "$enabled" == "yes" ]]; then
            ENABLED_REPOS=$((ENABLED_REPOS + 1))
            # 检查子仓目录是否存在
            local_status="ok"
            if [[ ! -d "$repo" ]]; then
                local_status="missing"
            fi
            REGISTRY_TABLE+="| $repo | $group | $priority | $sync_mode | $enabled | $status | $local_status |
"
        else
            DISABLED_REPOS=$((DISABLED_REPOS + 1))
        fi
    done < "$REGISTRY_CSV"
fi

# ── 3. adoption-matrix 变更 ───────────────────────────────────────────────
log "检查 adoption-matrix 变更..."
MATRIX_DIFF=""
if [[ -f "$ADOPTION_MATRIX" ]]; then
    # 获取 matrix 文件近 7 天的 git 变更
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        MATRIX_DIFF="$(git log --since='7 days ago' --oneline -- "$ADOPTION_MATRIX" 2>/dev/null || true)"
    fi
    MATRIX_LINES="$(wc -l < "$ADOPTION_MATRIX")"
    # 统计各类决策
    ADOPT_COUNT="$(grep -c '| adopt |' "$ADOPTION_MATRIX" || echo 0)"
    OBSERVE_COUNT="$(grep -c '| observe |' "$ADOPTION_MATRIX" || echo 0)"
    REJECT_COUNT="$(grep -c '| reject |' "$ADOPTION_MATRIX" || echo 0)"
    DONE_COUNT="$(grep -c '| done |' "$ADOPTION_MATRIX" || echo 0)"
    PENDING_COUNT="$(grep -c '| pending |' "$ADOPTION_MATRIX" || echo 0)"
    BLOCKED_COUNT="$(grep -c '| blocked |' "$ADOPTION_MATRIX" || echo 0)"
else
    ADOPT_COUNT=0; OBSERVE_COUNT=0; REJECT_COUNT=0
    DONE_COUNT=0; PENDING_COUNT=0; BLOCKED_COUNT=0
    MATRIX_LINES=0
fi
MATRIX_CHANGE_COUNT="$(echo "$MATRIX_DIFF" | grep -c '[^ ]' || echo 0)"

# ── 4. 质量门禁状态 ───────────────────────────────────────────────────────
log "运行质量门禁快速检查..."
GATE_REPORT=""
GATE_PASS=true

# health-check.sh
if [[ -x "$CHECK_SCRIPTS/health-check.sh" ]]; then
    GATE_REPORT+="### health-check.sh
"
    if HC_OUTPUT="$($CHECK_SCRIPTS/health-check.sh . 2>&1)" ; then
        GATE_REPORT+="PASS: 健康检查通过
"
    else
        GATE_PASS=false
        GATE_REPORT+="FAIL: 健康检查未通过
\`\`\`
$HC_OUTPUT
\`\`\`
"
    fi
    GATE_REPORT+="
"
fi

# check-adoption-matrix-status.sh
if [[ -x "$CHECK_SCRIPTS/check-adoption-matrix-status.sh" ]]; then
    GATE_REPORT+="### check-adoption-matrix-status.sh
"
    if MS_OUTPUT="$($CHECK_SCRIPTS/check-adoption-matrix-status.sh . 2>&1)" ; then
        GATE_REPORT+="PASS: adoption-matrix 状态合规
"
    else
        GATE_PASS=false
        GATE_REPORT+="FAIL: adoption-matrix 存在问题
\`\`\`
$MS_OUTPUT
\`\`\`
"
    fi
    GATE_REPORT+="
"
fi

# check-agents-coverage.sh
if [[ -x "$CHECK_SCRIPTS/check-agents-coverage.sh" ]]; then
    GATE_REPORT+="### check-agents-coverage.sh
"
    if AC_OUTPUT="$($CHECK_SCRIPTS/check-agents-coverage.sh . 2>&1)" ; then
        GATE_REPORT+="PASS: AGENTS 覆盖检查通过
"
    else
        GATE_PASS=false
        GATE_REPORT+="FAIL: AGENTS 覆盖不足
\`\`\`
$AC_OUTPUT
\`\`\`
"
    fi
    GATE_REPORT+="
"
fi

if $GATE_PASS; then
    GATE_STATUS="PASS"
else
    GATE_STATUS="FAIL"
fi

# ── 5. 生成报告 ──────────────────────────────────────────────────────────
log "写入报告: $REPORT_PATH"

cat > "$REPORT_PATH" << REPORT_EOF
# 周报: $DATE_TODAY

> 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')

## 1. 本周 Git 提交摘要（最近 7 天）

本周共 **${GIT_COMMIT_COUNT}** 次提交。

REPORT_EOF

if [[ -n "$GIT_LOG" ]]; then
    cat >> "$REPORT_PATH" << 'MARKER'
```
MARKER
    echo "$GIT_LOG" >> "$REPORT_PATH"
    cat >> "$REPORT_PATH" << 'MARKER'
```
MARKER
else
    echo "本周无提交记录。" >> "$REPORT_PATH"
fi

cat >> "$REPORT_PATH" << REPORT_EOF

## 2. 子仓同步状态

- 总仓库数: ${TOTAL_REPOS}
- 启用 (enabled=yes): ${ENABLED_REPOS}
- 禁用: ${DISABLED_REPOS}

| 仓库 | 分组 | 优先级 | 同步模式 | 启用 | 状态 | 本地目录 |
|---|---|---|---|---|---|---|
REPORT_EOF

echo "$REGISTRY_TABLE" >> "$REPORT_PATH"

cat >> "$REPORT_PATH" << REPORT_EOF

## 3. Adoption-Matrix 变更

- 总条目数: ${MATRIX_LINES}
- 本周相关提交: ${MATRIX_CHANGE_COUNT}
- 决策分布: adopt=${ADOPT_COUNT} / observe=${OBSERVE_COUNT} / reject=${REJECT_COUNT}
- 验收状态: done=${DONE_COUNT} / pending=${PENDING_COUNT} / blocked=${BLOCKED_COUNT}

REPORT_EOF

if [[ "$MATRIX_CHANGE_COUNT" -gt 0 ]]; then
    echo "本周相关提交记录:" >> "$REPORT_PATH"
    echo '```' >> "$REPORT_PATH"
    echo "$MATRIX_DIFF" >> "$REPORT_PATH"
    echo '```' >> "$REPORT_PATH"
else
    echo "本周 adoption-matrix 无变更。" >> "$REPORT_PATH"
fi

cat >> "$REPORT_PATH" << REPORT_EOF

## 4. 质量门禁状态

**综合状态: ${GATE_STATUS}**

${GATE_REPORT}
---

*本报告由 scripts/generate-weekly-report.sh 自动生成*
REPORT_EOF

log "完成! 报告已输出到: $REPORT_PATH"
echo "========================================="
echo "周报已生成: $REPORT_PATH"
echo "提交数: $GIT_COMMIT_COUNT"
echo "启用子仓: $ENABLED_REPOS / $TOTAL_REPOS"
echo "门禁状态: $GATE_STATUS"
echo "========================================="
