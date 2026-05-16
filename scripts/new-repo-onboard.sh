#!/usr/bin/env bash
# new-repo-onboard.sh — 新仓库接入 llm_agent 自动化脚本
# 用法: scripts/new-repo-onboard.sh <repo-path> [--adopt|--observe|--selective|--pilot]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${ROOT}/subrepos/registry.csv"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"
AGENTS="${ROOT}/AGENTS.md"
DATE=$(date +%Y-%m-%d)

# ── 参数解析 ──
REPO_PATH="${1:-}"
POLICY="${2:---observe}"

if [[ -z "${REPO_PATH}" ]]; then
  echo "用法: $0 <repo-path> [--adopt|--observe|--selective|--pilot]"
  echo ""
  echo "  <repo-path>   仓库绝对路径或相对路径"
  echo "  --adopt       intake_policy = adopt-first"
  echo "  --observe     intake_policy = observe-first (默认)"
  echo "  --selective   intake_policy = selective-adopt"
  echo "  --pilot       intake_policy = pilot-first"
  exit 1
fi

# 解析绝对路径
REPO_PATH="$(cd "${REPO_PATH}" 2>/dev/null && pwd)" || {
  echo "[ERROR] 仓库路径不存在: ${REPO_PATH}" >&2
  exit 1
}

REPO_NAME="$(basename "${REPO_PATH}")"
DEFAULT_BRANCH="$(git -C "${REPO_PATH}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "main")"

# 转换 policy 参数
case "${POLICY}" in
  --adopt)     INTAKE_POLICY="adopt-first" ;;
  --observe)   INTAKE_POLICY="observe-first" ;;
  --selective) INTAKE_POLICY="selective-adopt" ;;
  --pilot)     INTAKE_POLICY="pilot-first" ;;
  *)           echo "[ERROR] 未知策略: ${POLICY}" >&2; exit 1 ;;
esac

echo "=========================================="
echo " 新仓库接入: ${REPO_NAME}"
echo " 路径: ${REPO_PATH}"
echo " 策略: ${INTAKE_POLICY}"
echo " 日期: ${DATE}"
echo "=========================================="

# ── Step 0: 检查是否已注册 ──
if grep -q "^${REPO_NAME}," "${REGISTRY}" 2>/dev/null; then
  echo "[WARN] ${REPO_NAME} 已在 registry.csv 中注册，跳过"
else
  echo "[Step 1/5] 注册到 registry.csv"
  echo "${REPO_NAME},reference,P2,pull,${DEFAULT_BRANCH},yes,新接入参考仓库,active,unassigned,${DATE},${INTAKE_POLICY},C" >> "${REGISTRY}"
  echo "  -> 已添加到 registry.csv"
fi

# ── Step 2: 生成仓库 AGENTS.md（如果不存在） ──
echo "[Step 2/5] 检查仓库 AGENTS.md"
REPO_AGENTS="${REPO_PATH}/AGENTS.md"
if [[ -f "${REPO_AGENTS}" ]]; then
  if rg -q "^## llm_agent 接入信息$" "${REPO_AGENTS}"; then
    echo "  -> AGENTS.md 已存在接入标记，跳过"
  else
    echo "  -> AGENTS.md 已存在，追加接入标记"
    cat >> "${REPO_AGENTS}" << 'AGENTSEOF'

---

## llm_agent 接入信息

> 此仓库已被 llm_agent 工作区纳入治理。

AGENTSEOF
  fi
else
  echo "  -> 生成基础 AGENTS.md"
  cat > "${REPO_AGENTS}" << AGENTSEOF
# ${REPO_NAME}

## 仓库定位

由 llm_agent 工作区自动接入，待深度分析。

- 接入日期: ${DATE}
- 接入策略: ${INTAKE_POLICY}
- 治理状态: observe-first

## 接入后待办

- [ ] 深度分析 AGENT|SKILL|PROFILE|WORKFLOW
- [ ] 评估对 agent-dev-kit 的借鉴价值
- [ ] 更新 adoption-matrix 决策
AGENTSEOF
fi

# ── Step 3: 更新 adoption-matrix.md ──
echo "[Step 3/5] 更新 adoption-matrix"
if grep -q "${REPO_NAME}" "${MATRIX}" 2>/dev/null; then
  echo "  -> 已在 adoption-matrix 中，跳过"
else
  echo "| ${DATE} | ${REPO_NAME} | reference | 待深度分析 | 待评估 | 待评估 | 待评估 | observe | pending | agent-dev-kit | intake-${REPO_NAME}-${DATE}.md |" >> "${MATRIX}"
  echo "  -> 已添加到 adoption-matrix"
fi

# ── Step 4: 运行基础检查 ──
echo "[Step 4/5] 运行基础检查"
if [[ -x "${ROOT}/scripts/check-agents-coverage.sh" ]]; then
  bash "${ROOT}/scripts/check-agents-coverage.sh" "${ROOT}" || true
fi

# ── Step 5: 输出接入报告 ──
echo "[Step 5/5] 生成接入报告"
REPORT="${ROOT}/reports/intake-${REPO_NAME}-${DATE}.md"
cat > "${REPORT}" << REPORTEOF
# 新仓库接入报告

| 字段 | 值 |
|------|-----|
| 仓库名 | ${REPO_NAME} |
| 路径 | ${REPO_PATH} |
| 接入日期 | ${DATE} |
| 接入策略 | ${INTAKE_POLICY} |
| 注册状态 | $(grep -c "^${REPO_NAME}," "${REGISTRY}" && echo "已注册" || echo "未注册") |

## 后续步骤

1. **深度分析**: 对仓库做全量 AGENT|SKILL|PROFILE|WORKFLOW 分析
2. **评估价值**: 确定对 adk 的借鉴点和风险
3. **决策**: 在 adoption-matrix 中更新 decision 和 status
4. **实装**（如 adopt）: 在 agent-dev-kit 中落地借鉴点
5. **验证**: 运行 \`scripts/check-adk-harden-readiness.sh . --require-pilot\`
REPORTEOF

echo ""
echo "=========================================="
echo " 接入完成: ${REPO_NAME}"
echo "=========================================="
echo ""
echo "产出文件:"
echo "  注册: ${REGISTRY}"
echo "  分析: ${REPO_AGENTS}"
echo "  矩阵: ${MATRIX}"
echo "  报告: ${REPORT}"
echo ""
echo "下一步:"
echo "  1. 对 ${REPO_NAME} 做深度分析（AGENT|SKILL|PROFILE|WORKFLOW）"
echo "  2. 更新 adoption-matrix.md 中的决策和状态"
echo "  3. 如果决定 adopt，在 agent-dev-kit 中实装借鉴点"
echo "  4. 运行 scripts/check-adk-harden-readiness.sh . --require-pilot 验证"
