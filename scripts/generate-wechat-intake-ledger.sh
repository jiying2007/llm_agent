#!/usr/bin/env bash
set -euo pipefail

# generate-wechat-intake-ledger.sh
#
# Build an article-level intake ledger for wechat-articles. This is a
# read/classify/report step only: it must not absorb article content into ADK
# assets and must not onboard external code automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT="${ROOT}/reports/wechat-article-intake.jsonl"
NEXT_BATCH="${ROOT}/reports/wechat-absorb-next-batch.md"
DECISIONS="${ROOT}/reports/wechat-article-decisions.tsv"
BATCH_SIZE=10
WRITE_BATCH=1

usage() {
  cat <<USAGE
Usage:
  scripts/generate-wechat-intake-ledger.sh [options]

Options:
  --root <path>          Workspace root. Defaults to this repository.
  --out <path>           Output JSONL ledger. Defaults to reports/wechat-article-intake.jsonl.
  --next-batch <path>    Output next-batch Markdown report. Defaults to reports/wechat-absorb-next-batch.md.
  --decisions <path>     Optional reviewed decisions TSV. Defaults to reports/wechat-article-decisions.tsv.
  --batch-size <n>       Number of P0/P1 items in next-batch report. Defaults to 10.
  --no-batch-report      Generate only the JSONL ledger.
  -h, --help             Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "[FAIL] --root requires a path" >&2; exit 1; }
      ROOT="$(cd "$2" && pwd)"
      OUT="${ROOT}/reports/wechat-article-intake.jsonl"
      NEXT_BATCH="${ROOT}/reports/wechat-absorb-next-batch.md"
      DECISIONS="${ROOT}/reports/wechat-article-decisions.tsv"
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || { echo "[FAIL] --out requires a path" >&2; exit 1; }
      OUT="$2"
      shift 2
      ;;
    --next-batch)
      [[ $# -ge 2 ]] || { echo "[FAIL] --next-batch requires a path" >&2; exit 1; }
      NEXT_BATCH="$2"
      shift 2
      ;;
    --decisions)
      [[ $# -ge 2 ]] || { echo "[FAIL] --decisions requires a path" >&2; exit 1; }
      DECISIONS="$2"
      shift 2
      ;;
    --batch-size)
      [[ $# -ge 2 ]] || { echo "[FAIL] --batch-size requires a number" >&2; exit 1; }
      BATCH_SIZE="$2"
      [[ "${BATCH_SIZE}" =~ ^[0-9]+$ ]] || { echo "[FAIL] invalid --batch-size: ${BATCH_SIZE}" >&2; exit 1; }
      shift 2
      ;;
    --no-batch-report)
      WRITE_BATCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ARTICLES_DIR="${ROOT}/wechat-articles"
[[ -d "${ARTICLES_DIR}" ]] || {
  echo "[FAIL] missing wechat-articles directory: ${ARTICLES_DIR}" >&2
  exit 1
}

mkdir -p "$(dirname "${OUT}")"
if [[ "${WRITE_BATCH}" -eq 1 ]]; then
  mkdir -p "$(dirname "${NEXT_BATCH}")"
fi

json_string() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "${value}"
}

has_pattern() {
  local pattern="$1"
  local file="$2"
  rg -qi "${pattern}" "${file}" 2>/dev/null
}

text_has_pattern() {
  local pattern="$1"
  local value="$2"
  printf '%s\n' "${value}" | rg -qi "${pattern}" 2>/dev/null
}

join_by_semicolon() {
  local IFS=";"
  printf '%s' "$*"
}

safe_md_cell() {
  local value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//|/／}"
  printf '%s' "${value}"
}

tmp_ledger="$(mktemp)"
tmp_batch="$(mktemp)"
tmp_batch_p0="$(mktemp)"
tmp_batch_p1="$(mktemp)"
trap 'rm -f "${tmp_ledger}" "${tmp_batch}" "${tmp_batch_p0}" "${tmp_batch_p1}"' EXIT

declare -A priority_counts=()
declare -A batch_counts=()
declare -A category_counts=()
declare -A risk_counts=()
declare -A candidate_counts=()
declare -A decision_override=()
declare -A status_override=()
declare -A target_override=()
declare -A evidence_override=()

article_count=0
external_count=0

if [[ -f "${DECISIONS}" ]]; then
  while IFS=$'\t' read -r row_id row_decision row_status row_target row_evidence _row_notes; do
    [[ -n "${row_id:-}" ]] || continue
    [[ "${row_id}" == "id" ]] && continue
    decision_override["${row_id}"]="${row_decision:-}"
    status_override["${row_id}"]="${row_status:-reviewed}"
    target_override["${row_id}"]="${row_target:-pending}"
    evidence_override["${row_id}"]="${row_evidence:-${DECISIONS#${ROOT}/}}"
  done < "${DECISIONS}"
fi

: > "${tmp_batch_p0}"
: > "${tmp_batch_p1}"

while IFS= read -r -d '' file; do
  article_count=$((article_count + 1))
  rel="${file#${ROOT}/}"
  category="${rel#wechat-articles/}"
  category="${category%%/*}"
  if [[ "${category}" == "${rel}" ]]; then
    category="root"
  fi

  title="$(awk '
    /^# / {
      sub(/^# +/, "")
      print
      exit
    }
  ' "${file}" 2>/dev/null || true)"
  if [[ -z "${title}" ]]; then
    title="$(basename "${file}" .md)"
  fi

  chars="$(wc -m < "${file}" | tr -d ' ')"
  code_links="$(rg -o 'https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+|github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "${file}" 2>/dev/null | sed 's#^https://##' | sed 's#[),，。；;].*$##' | sort -u | paste -sd ';' - | cut -c1-500 || true)"

  topics=()
  has_pattern '上下文|context|compact|压缩|token|RTK|日志|预算|省 Token|省token|工具输出' "${file}" && topics+=("context-token")
  has_pattern '记忆|memory|复盘|lesson|经验库|After Action Review|AAR|自我进化' "${file}" && topics+=("memory-governance")
  has_pattern 'Skill|AGENTS|SOP|Prompt|工作流|workflow|MCP|Agent|Sub-agent|subagent' "${file}" && topics+=("skill-agent-workflow")
  has_pattern '多 Agent|多智能体|parallel|并行|worktree|worker|子代理|Sub-agent|subagent' "${file}" && topics+=("multi-agent")
  has_pattern 'PR|review|代码审查|Code Review|Git|提交|commit' "${file}" && topics+=("review-git")
  has_pattern '测试|CI|门禁|发布|release|eval|质量|验证|check' "${file}" && topics+=("test-release-quality")
  has_pattern '安全|密钥|权限|sandbox|供应链|越权|注入|API key|凭证' "${file}" && topics+=("security")
  has_pattern '嵌入式|MCU|SoC|BSP|设备|机器人|TinyML|Edge AI|边缘' "${file}" && topics+=("embedded-relevance")
  has_pattern 'Gemini|Claude|GPT|DeepSeek|Qwen|模型|发布|资讯|横评' "${file}" && topics+=("tool-news")

  topics_joined="$(join_by_semicolon "${topics[@]:-uncategorized}")"
  title_signal="${title} $(basename "${file}")"
  external_code=false
  if [[ -n "${code_links}" ]]; then
    external_code=true
    external_count=$((external_count + 1))
  fi

  priority="P2"
  batch="P2-reference-only"
  candidate_type="reference-only"
  risk="low"
  decision="reference-only-pending"

  if text_has_pattern '上下文|context|compact|压缩|token|RTK|日志|预算|省[[:space:]]*Token|省token|失忆|记忆|memory|复盘|lesson|AAR|自我进化' "${title_signal}"; then
    priority="P0"
    batch="P0-context-memory-token"
    candidate_type="governance-rule-or-script"
    risk="medium"
    decision="pending-triage"
  elif text_has_pattern 'Skill|Skills|AGENTS|SOP|Prompt|工作流|workflow|MCP|CLAUDE\.md|cursorrules|规则实践|项目规则' "${title_signal}"; then
    priority="P0"
    batch="P0-skill-agent-sop"
    candidate_type="skill-or-workflow-enhancement"
    risk="medium"
    decision="pending-triage"
  elif text_has_pattern '多[[:space:]]*Agent|多智能体|parallel|并行|worktree|worker|子代理|Sub-agent|subagent|代码审查|Code Review|PR Review|Git管理|多人协作' "${title_signal}"; then
    priority="P1"
    batch="P1-multi-agent-review"
    candidate_type="workflow-enhancement"
    risk="medium"
    decision="pending-triage"
  elif text_has_pattern '测试|CI|门禁|发布|release|eval|质量|验证|零[[:space:]]*Bug' "${title_signal}"; then
    priority="P1"
    batch="P1-test-release-quality"
    candidate_type="gate-or-test-enhancement"
    risk="medium"
    decision="pending-triage"
  fi

  if [[ "${external_code}" == "true" ]]; then
    risk="high"
    if [[ "${candidate_type}" == "reference-only" ]]; then
      priority="P2"
      batch="P2-external-code-candidates"
      candidate_type="external-code-review"
      decision="pending-security-review"
    fi
  fi

  id="$(printf 'wechat-%04d' "${article_count}")"
  if [[ -n "${decision_override[${id}]:-}" ]]; then
    decision="${decision_override[${id}]}"
    status="${status_override[${id}]:-reviewed}"
    target_asset="${target_override[${id}]:-pending}"
    evidence="${evidence_override[${id}]:-${DECISIONS#${ROOT}/}}"
  else
    status="queued"
    target_asset="pending"
    evidence="reports/wechat-absorb-next-batch.md"
  fi

  priority_counts["${priority}"]=$(( ${priority_counts["${priority}"]:-0} + 1 ))
  batch_counts["${batch}"]=$(( ${batch_counts["${batch}"]:-0} + 1 ))
  category_counts["${category}"]=$(( ${category_counts["${category}"]:-0} + 1 ))
  risk_counts["${risk}"]=$(( ${risk_counts["${risk}"]:-0} + 1 ))
  candidate_counts["${candidate_type}"]=$(( ${candidate_counts["${candidate_type}"]:-0} + 1 ))

  printf '{' >> "${tmp_ledger}"
  printf '"id":%s,' "$(json_string "${id}")" >> "${tmp_ledger}"
  printf '"path":%s,' "$(json_string "${rel}")" >> "${tmp_ledger}"
  printf '"category":%s,' "$(json_string "${category}")" >> "${tmp_ledger}"
  printf '"title":%s,' "$(json_string "${title}")" >> "${tmp_ledger}"
  printf '"chars":%s,' "${chars}" >> "${tmp_ledger}"
  printf '"priority":%s,' "$(json_string "${priority}")" >> "${tmp_ledger}"
  printf '"batch":%s,' "$(json_string "${batch}")" >> "${tmp_ledger}"
  printf '"topics":%s,' "$(json_string "${topics_joined}")" >> "${tmp_ledger}"
  printf '"candidate_type":%s,' "$(json_string "${candidate_type}")" >> "${tmp_ledger}"
  printf '"risk":%s,' "$(json_string "${risk}")" >> "${tmp_ledger}"
  printf '"external_code":%s,' "${external_code}" >> "${tmp_ledger}"
  printf '"external_code_policy":%s,' "$(json_string "report-only-until-security-review")" >> "${tmp_ledger}"
  printf '"code_links":%s,' "$(json_string "${code_links}")" >> "${tmp_ledger}"
  printf '"decision":%s,' "$(json_string "${decision}")" >> "${tmp_ledger}"
  printf '"status":%s,' "$(json_string "${status}")" >> "${tmp_ledger}"
  printf '"target_asset":%s,' "$(json_string "${target_asset}")" >> "${tmp_ledger}"
  printf '"evidence":%s' "$(json_string "${evidence}")" >> "${tmp_ledger}"
  printf '}\n' >> "${tmp_ledger}"

  if [[ "${WRITE_BATCH}" -eq 1 && "${status}" == "queued" ]]; then
    if [[ "${priority}" == "P0" || "${priority}" == "P1" ]]; then
      batch_target="${tmp_batch_p1}"
      [[ "${priority}" == "P0" ]] && batch_target="${tmp_batch_p0}"
      printf '| %s | %s | %s | %s | %s | %s | %s | `%s` |\n' \
        "${id}" \
        "$(safe_md_cell "${category}")" \
        "${priority}" \
        "$(safe_md_cell "${batch}")" \
        "$(safe_md_cell "${candidate_type}")" \
        "${risk}" \
        "$(safe_md_cell "${title}")" \
        "${rel}" >> "${batch_target}"
    fi
  fi
done < <(find "${ARTICLES_DIR}" -type f -name '*.md' ! -path "${ARTICLES_DIR}/_reports/*" ! -name 'INDEX.md' ! -name 'REPORT.md' -print0 | sort -z)

mv "${tmp_ledger}" "${OUT}"

if [[ "${WRITE_BATCH}" -eq 1 ]]; then
  {
    echo "# WeChat Article Absorption Next Batch"
    echo
    echo "- 数据源：\`wechat-articles/\`"
    echo "- Ledger：\`${OUT#${ROOT}/}\`"
    echo "- 批次策略：优先 P0/P1；外部代码仅登记，不自动纳入子仓。"
    echo "- 批次上限：${BATCH_SIZE}"
    echo
    echo "## Summary"
    echo
    echo "| Metric | Count |"
    echo "|---|---:|"
    echo "| articles | ${article_count} |"
    echo "| external_code_mentions | ${external_count} |"
    for key in "${!priority_counts[@]}"; do
      echo "| priority:${key} | ${priority_counts[${key}]} |"
    done | sort
    for key in "${!risk_counts[@]}"; do
      echo "| risk:${key} | ${risk_counts[${key}]} |"
    done | sort
    echo
    echo "## Batch Distribution"
    echo
    echo "| Batch | Count |"
    echo "|---|---:|"
    for key in "${!batch_counts[@]}"; do
      echo "| ${key} | ${batch_counts[${key}]} |"
    done | sort
    echo
    echo "## Next Batch Candidates"
    echo
    {
      echo "| id | category | priority | batch | candidate | risk | title | path |"
      echo "|---|---|---|---|---|---|---|---|"
      head -n "${BATCH_SIZE}" "${tmp_batch_p0}"
      p0_count="$(head -n "${BATCH_SIZE}" "${tmp_batch_p0}" | wc -l | tr -d ' ')"
      remaining=$((BATCH_SIZE - p0_count))
      if [[ "${remaining}" -gt 0 ]]; then
        head -n "${remaining}" "${tmp_batch_p1}"
      fi
    } > "${tmp_batch}"
    cat "${tmp_batch}"
    echo
    echo "## Absorption Gate"
    echo
    echo "- 每篇文章先生成候选摘要，不复制原文到 adk 核心资产。"
    echo "- 已有等价能力时只允许增强现有 skill/workflow/script，不新增平行资产。"
    echo "- 含 GitHub/源码/安装命令的条目先进入供应链审查，默认不新增子仓。"
    echo "- 每批完成后运行 \`rtk scripts/check-all.sh --quick\` 与相关 \`agent-dev-kit\` 门禁。"
  } > "${NEXT_BATCH}"
fi

echo "[OK] wechat intake ledger generated: ${OUT}"
if [[ "${WRITE_BATCH}" -eq 1 ]]; then
  echo "[OK] next batch report generated: ${NEXT_BATCH}"
fi
echo "[OK] articles=${article_count} external_code_mentions=${external_count}"
