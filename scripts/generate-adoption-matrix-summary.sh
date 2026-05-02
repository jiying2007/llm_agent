#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${2:-${ROOT}/reports/adoption-matrix-summary.md}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"
now="$(date '+%F %T %Z')"

totals="$(awk -F'|' '
  /^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {
    state=$10; gsub(/^ +| +$/, "", state)
    decision=$9; gsub(/^ +| +$/, "", decision)
    total++
    state_count[state]++
    decision_count[decision]++
  }
  END {
    printf "%d|%d|%d|%d|%d|%d|%d\n",
      total+0,
      state_count["done"]+0,
      state_count["pending"]+0,
      state_count["blocked"]+0,
      decision_count["adopt"]+0,
      decision_count["observe"]+0,
      decision_count["reject"]+0
  }
' "${MATRIX}")"

IFS='|' read -r total done pending blocked adopt observe reject <<< "${totals}"

{
  echo "# Adoption Matrix 状态汇总"
  echo
  echo "- 生成时间：${now}"
  echo "- 数据源：\`subrepos/adoption-matrix.md\`"
  echo
  echo "## 总览"
  echo
  echo "| 指标 | 数量 |"
  echo "|---|---|"
  echo "| 总记录（真实） | ${total} |"
  echo "| done | ${done} |"
  echo "| pending | ${pending} |"
  echo "| blocked | ${blocked} |"
  echo "| adopt | ${adopt} |"
  echo "| observe | ${observe} |"
  echo "| reject | ${reject} |"
  echo
  echo "## 按类别分布"
  echo
  echo "| 类别标签 | done | pending | blocked | 总计 |"
  echo "|---|---:|---:|---:|---:|"
  awk -F'|' '
    /^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {
      tag=$4; gsub(/^ +| +$/, "", tag)
      state=$10; gsub(/^ +| +$/, "", state)
      tags[tag]=1
      count[tag]++
      if (state=="done") done[tag]++
      if (state=="pending") pending[tag]++
      if (state=="blocked") blocked[tag]++
    }
    END {
      for (tag in tags) {
        printf "| %s | %d | %d | %d | %d |\n",
          tag, done[tag]+0, pending[tag]+0, blocked[tag]+0, count[tag]+0
      }
    }
  ' "${MATRIX}" | sort
  echo
  echo "## Blocked 明细"
  echo
} > "${OUT}"

blocked_rows="$(awk -F'|' '
  /^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ && $0 ~ /\| blocked \|/ {
    repo=$3; gsub(/^ +| +$/, "", repo)
    capability=$5; gsub(/^ +| +$/, "", capability)
    decision=$9; gsub(/^ +| +$/, "", decision)
    state=$10; gsub(/^ +| +$/, "", state)
    evidence=$12; gsub(/^ +| +$/, "", evidence)
    printf "| %s | %s | %s | %s |\n", repo, capability, state, evidence
  }
' "${MATRIX}")"

if [[ -n "${blocked_rows}" ]]; then
  {
    echo "| 来源仓库 | 候选能力 | 状态 | 证据 |"
    echo "|---|---|---|---|"
    echo "${blocked_rows}"
  } >> "${OUT}"
else
  {
    echo "- 当前无 blocked 记录。"
  } >> "${OUT}"
fi

echo "[OK] adoption summary generated: ${OUT}"
