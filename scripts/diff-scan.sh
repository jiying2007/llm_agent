#!/usr/bin/env bash
set -e
set -u

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SINCE_DAYS="${2:-7}"
OUT="${3:-${ROOT}/reports/weekly-change-report.md}"
REGISTRY="${ROOT}/subrepos/registry.csv"
FORCE_FLAG="${4:-}"
GATE_FILE="${ROOT}/subrepos/phase-gate.env"
FORCE=0

if [[ "${FORCE_FLAG}" == "--force" ]]; then
  FORCE=1
fi

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[ERROR] registry not found: ${REGISTRY}" >&2
  exit 1
fi

allow_sync="yes"
phase_name="unknown"
if [[ -f "${GATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${GATE_FILE}"
  allow_sync="${allow_upstream_sync:-no}"
  phase_name="${phase:-unknown}"
fi

if [[ "${allow_sync}" != "yes" && "${FORCE}" -ne 1 ]]; then
  echo "[BLOCK] upstream diff scan disabled by phase gate" >&2
  echo "[INFO] phase=${phase_name} allow_upstream_sync=${allow_sync}" >&2
  echo "[INFO] run scripts/check-adk-harden-readiness.sh first" >&2
  echo "[INFO] override once: scripts/diff-scan.sh . ${SINCE_DAYS} ${OUT} --force" >&2
  exit 3
fi

mkdir -p "$(dirname "${OUT}")"
today="$(date +%F)"

{
  echo "# 子仓增量变更周报"
  echo
  echo "- 生成日期：${today}"
  echo "- 扫描窗口：最近 ${SINCE_DAYS} 天"
  echo "- 规则：仅保留 AGENTS/SKILL/README/workflow/scripts 相关变更"
  echo "- 阶段：${phase_name}"
  echo "- 强制模式：${FORCE}"
  echo
} > "${OUT}"

found=0

while IFS=',' read -r repo group priority sync_mode branch enabled notes status owner last_reviewed_on intake_policy; do
  if [[ "${repo}" == "repo" || -z "${repo}" || "${enabled}" != "yes" || "${status}" == "disabled" ]]; then
    continue
  fi

  repo_path="${ROOT}/${repo}"
  if [[ ! -d "${repo_path}/.git" ]]; then
    continue
  fi

  raw="$(git -C "${repo_path}" log --since="${SINCE_DAYS} days ago" --name-only --pretty=format: 2>/dev/null || true)"
  changes="$(printf "%s\n" "${raw}" | sed '/^$/d' | rg -N '(^AGENTS\.md$|(^|/)SKILL\.md$|(^|/)README\.md$|(^|/)workflows?/|(^|/)scripts?/|(^|/)control/workflows/)' | sort -u || true)"

  if [[ -z "${changes}" ]]; then
    continue
  fi

  ((found+=1))
  {
    echo "## ${repo}"
    echo
    echo "- 分组：${group}"
    echo "- 优先级：${priority}"
    echo "- 状态：${status}"
    echo "- owner：${owner}"
    echo "- intake_policy：${intake_policy}"
    echo "- 上次复审：${last_reviewed_on}"
    echo "- 关注说明：${notes}"
    echo "- 变更文件："
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      echo "  - ${line}"
    done <<< "${changes}"
    echo "- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）"
    echo
  } >> "${OUT}"
done < "${REGISTRY}"

if ((found == 0)); then
  {
    echo "## 本周期无命中变更"
    echo
    echo "- 结论：未扫描到目标范围内的增量。"
    echo
  } >> "${OUT}"
fi

echo "[OK] report generated: ${OUT}"
