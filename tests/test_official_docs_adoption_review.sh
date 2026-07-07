#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-official-docs-adoption-review.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p \
  "${TMP_DIR}/agent-dev-kit/manifests" \
  "${TMP_DIR}/agent-dev-kit/docs" \
  "${TMP_DIR}/agent-dev-kit/skills/example-skill" \
  "${TMP_DIR}/subrepos"

touch "${TMP_DIR}/agent-dev-kit/skills/example-skill/SKILL.md"

write_manifest() {
  local expires_at="$1"
  local review_status_line="$2"
  cat >"${TMP_DIR}/agent-dev-kit/manifests/official_docs_freshness_gates.json" <<EOF
{
  "schema_version": "1.0.0",
  "review_policy": {
    "allowed_domains": ["developers.openai.com", "platform.openai.com"],
    "required_fields": ["url", "retrieved_at", "review_status", "expires_at", "adoption_scope"],
    "review_status_values": ["adopted", "watch", "rejected"]
  },
  "adoption_review_policy": {
    "linked_matrices": [
      "agent-dev-kit/docs/reference-adoption-matrix.md",
      "subrepos/adoption-matrix.jsonl"
    ],
    "source_expiry_action": "needs-review",
    "missing_review_status_action": "fail",
    "missing_target_evidence_action": "fail",
    "review_queue_output": "stdout",
    "required_target_evidence_prefixes": ["agent-dev-kit/"],
    "quality_gates": [
      "expired official sources must enter the review queue or fail",
      "OpenAI Developers adoption rows targeting agent-dev-kit must have existing agent-dev-kit evidence",
      "review queue items must identify source_id or adoption row and next action"
    ]
  },
  "sources": [
    {
      "id": "fixture-source",
      "title": "Fixture source",
      "url": "https://developers.openai.com/codex/example",
      "retrieved_at": "2026-07-01",
      "expires_at": "${expires_at}",
      ${review_status_line}
      "adoption_scope": "P0"
    }
  ]
}
EOF
}

write_matrices() {
  local evidence="$1"
  cat >"${TMP_DIR}/subrepos/adoption-matrix.jsonl" <<EOF
{"date":"2026-07-07","repo":"OpenAI Developers","category":"workflow-quality","capability":"fixture","value":"高","cost":"低","risk":"低","decision":"adopt","state":"done","target":"agent-dev-kit","evidence":"${evidence}"}
EOF
  cat >"${TMP_DIR}/agent-dev-kit/docs/reference-adoption-matrix.md" <<EOF
| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-07-07 | OpenAI Developers | workflow-quality | fixture | 高 | 低 | 低 | adopt | done | agent-dev-kit | ${evidence} |
EOF
}

write_manifest "2026-08-01" '"review_status": "adopted",'
write_matrices "agent-dev-kit/skills/example-skill/SKILL.md"
OPENAI_ADOPTION_REVIEW_TODAY=2026-07-07 "${CHECK}" "${TMP_DIR}" >/dev/null

write_manifest "2026-01-01" '"review_status": "adopted",'
if OPENAI_ADOPTION_REVIEW_TODAY=2026-07-07 "${CHECK}" "${TMP_DIR}" >/tmp/official-docs-adoption-review-expired.out 2>&1; then
  echo "[FAIL] expired official source unexpectedly passed" >&2
  exit 1
fi
rg -q "source-expired" /tmp/official-docs-adoption-review-expired.out
rg -q "needs-review" /tmp/official-docs-adoption-review-expired.out

write_manifest "2026-08-01" ''
if OPENAI_ADOPTION_REVIEW_TODAY=2026-07-07 "${CHECK}" "${TMP_DIR}" >/tmp/official-docs-adoption-review-status.out 2>&1; then
  echo "[FAIL] missing review_status unexpectedly passed" >&2
  exit 1
fi
rg -q "missing-source-field:review_status" /tmp/official-docs-adoption-review-status.out

write_manifest "2026-08-01" '"review_status": "adopted",'
write_matrices "agent-dev-kit/skills/missing-skill/SKILL.md"
if OPENAI_ADOPTION_REVIEW_TODAY=2026-07-07 "${CHECK}" "${TMP_DIR}" >/tmp/official-docs-adoption-review-evidence.out 2>&1; then
  echo "[FAIL] missing target evidence unexpectedly passed" >&2
  exit 1
fi
rg -q "missing-target-evidence" /tmp/official-docs-adoption-review-evidence.out

echo "[PASS] official docs adoption review fixtures behave as expected"
