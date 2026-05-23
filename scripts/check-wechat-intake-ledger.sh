#!/usr/bin/env bash
set -euo pipefail

# check-wechat-intake-ledger.sh
# Ensures every archived WeChat article is represented by the generated intake
# ledger and that external-code candidates remain report-only before review.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
LEDGER="${ROOT}/reports/wechat-article-intake.jsonl"
GENERATOR="${ROOT}/scripts/generate-wechat-intake-ledger.sh"
ARTICLES_DIR="${ROOT}/wechat-articles"
DECISIONS="${ROOT}/reports/wechat-article-decisions.tsv"

[[ -x "${GENERATOR}" || -f "${GENERATOR}" ]] || {
  echo "[FAIL] missing generator: ${GENERATOR}" >&2
  exit 1
}

[[ -d "${ARTICLES_DIR}" ]] || {
  echo "[FAIL] missing wechat-articles directory: ${ARTICLES_DIR}" >&2
  exit 1
}

[[ -f "${LEDGER}" ]] || {
  echo "[FAIL] missing ledger: ${LEDGER}" >&2
  echo "Run: rtk scripts/generate-wechat-intake-ledger.sh" >&2
  exit 1
}

article_count="$(find "${ARTICLES_DIR}" -type f -name '*.md' ! -path "${ARTICLES_DIR}/_reports/*" ! -name 'INDEX.md' ! -name 'REPORT.md' | wc -l | tr -d ' ')"
ledger_count="$(wc -l < "${LEDGER}" | tr -d ' ')"

if [[ "${article_count}" -lt 300 ]]; then
  echo "[FAIL] unexpected article count: ${article_count} (<300)" >&2
  exit 1
fi

if [[ "${ledger_count}" != "${article_count}" ]]; then
  echo "[FAIL] ledger/article count mismatch: ledger=${ledger_count} articles=${article_count}" >&2
  exit 1
fi

missing_keys="$(rg -n -v '"id":|"path":|"priority":|"batch":|"candidate_type":|"decision":|"status":|"target_asset":' "${LEDGER}" || true)"
if [[ -n "${missing_keys}" ]]; then
  echo "[FAIL] ledger has rows missing required keys" >&2
  echo "${missing_keys}" >&2
  exit 1
fi

external_policy_violations="$(rg '"external_code":true' "${LEDGER}" | rg -v '"external_code_policy":"report-only-until-security-review"' || true)"
if [[ -n "${external_policy_violations}" ]]; then
  echo "[FAIL] external code rows must remain report-only before security review" >&2
  echo "${external_policy_violations}" >&2
  exit 1
fi

if [[ -f "${DECISIONS}" ]]; then
  unknown_decisions="$(
    while IFS=$'\t' read -r row_id _row_decision _row_status _row_target _row_evidence _row_notes; do
      [[ -n "${row_id:-}" ]] || continue
      [[ "${row_id}" == "id" ]] && continue
      if ! rg -q "\"id\":\"${row_id}\"" "${LEDGER}"; then
        printf '%s\n' "${row_id}"
      fi
    done < "${DECISIONS}"
  )"
  if [[ -n "${unknown_decisions}" ]]; then
    echo "[FAIL] decisions file references unknown article ids" >&2
    echo "${unknown_decisions}" >&2
    exit 1
  fi
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
bash "${GENERATOR}" --root "${ROOT}" --out "${tmp}" --decisions "${DECISIONS}" --no-batch-report >/dev/null
if ! cmp -s "${tmp}" "${LEDGER}"; then
  echo "[FAIL] ledger is stale; regenerate it with:" >&2
  echo "  rtk scripts/generate-wechat-intake-ledger.sh" >&2
  exit 1
fi

echo "[OK] wechat intake ledger healthy: articles=${article_count}"
