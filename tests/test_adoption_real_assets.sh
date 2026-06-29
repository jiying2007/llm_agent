#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-adoption-real-assets.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/subrepos" "${TMP_DIR}/agent-dev-kit/docs" "${TMP_DIR}/agent-dev-kit/skills/example-skill"
touch "${TMP_DIR}/agent-dev-kit/skills/example-skill/SKILL.md"
touch "${TMP_DIR}/agent-dev-kit/docs/reference-adoption-matrix.md"

write_matrix() {
  local path="$1"
  local evidence="$2"
  cat >"${path}" <<EOF
| 日期 | 仓库 | 类别 | 能力 | 价值 | 成本 | 风险 | decision | state | target | evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-06-29 | fixture | workflow-core | 示例真实资产能力 | 高 | 低 | 低 | adopt | done | agent-dev-kit | ${evidence} |
EOF
}

write_matrix \
  "${TMP_DIR}/subrepos/adoption-matrix.md" \
  "reports/example.md; agent-dev-kit/skills/example-skill/SKILL.md"
write_matrix \
  "${TMP_DIR}/agent-dev-kit/docs/reference-adoption-matrix.md" \
  "agent-dev-kit/skills/example-skill/SKILL.md"

"${CHECK}" "${TMP_DIR}" >/dev/null

write_matrix \
  "${TMP_DIR}/subrepos/adoption-matrix.md" \
  "reports/example.md; subrepos/adoption-matrix.md"

if "${CHECK}" "${TMP_DIR}" >/dev/null 2>&1; then
  echo "[FAIL] report-only adoption row unexpectedly passed" >&2
  exit 1
fi

write_matrix \
  "${TMP_DIR}/subrepos/adoption-matrix.md" \
  "agent-dev-kit/docs/reference-adoption-matrix.md"

if "${CHECK}" "${TMP_DIR}" >/dev/null 2>&1; then
  echo "[FAIL] non-matrix capability using only reference matrix unexpectedly passed" >&2
  exit 1
fi

write_matrix \
  "${TMP_DIR}/subrepos/adoption-matrix.md" \
  "agent-dev-kit/docs/reference-adoption-matrix.md"
sed -i 's/示例真实资产能力/27 条候选能力完整评估矩阵/' "${TMP_DIR}/subrepos/adoption-matrix.md"

"${CHECK}" "${TMP_DIR}" >/dev/null

echo "[PASS] adoption real asset fixtures behave as expected"
