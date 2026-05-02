#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"
SCRIPTS_README="${ROOT}/scripts/README.md"
ADOPTION_MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
fi

if [[ ! -f "${SCRIPTS_README}" ]]; then
  echo "[FAIL] scripts README missing: ${SCRIPTS_README}" >&2
  exit 1
fi

if [[ ! -f "${ADOPTION_MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${ADOPTION_MATRIX}" >&2
  exit 1
fi

expected_header="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy"
actual_header="$(head -n 1 "${REGISTRY}")"
if [[ "${actual_header}" != "${expected_header}" ]]; then
  echo "[FAIL] registry header out of sync" >&2
  echo "[INFO] expected: ${expected_header}" >&2
  echo "[INFO] actual  : ${actual_header}" >&2
  exit 2
fi

required_tokens=(
  "check-skill-metadata.sh"
  "check-skill-routing-conflicts.sh"
  "check-doc-sync.sh"
  "check-adoption-matrix-status.sh"
  "check-observe-intake-depth.sh"
  "generate-adoption-matrix-summary.sh"
  "run-post-freeze-cycle.sh"
  "--check-skill-metadata"
  "--check-routing-conflicts"
  "--check-doc-sync"
  "--check-observe-intake-depth"
)

for token in "${required_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${SCRIPTS_README}"; then
    echo "[FAIL] scripts/README.md missing token: ${token}" >&2
    exit 2
  fi
done

matrix_tokens=(
  "类别标签"
  "验收状态"
  "codex-cookbook"
)

for token in "${matrix_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${ADOPTION_MATRIX}"; then
    echo "[FAIL] adoption-matrix missing token: ${token}" >&2
    exit 2
  fi
done

echo "[PASS] docs and governance files are in sync"
