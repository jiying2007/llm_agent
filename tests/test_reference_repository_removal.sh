#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CHECK="${ROOT}/scripts/check-reference-repository-removal.sh"
PLAN="${ROOT}/scripts/plan-reference-repository-removal.sh"
EVIDENCE="reports/subrepo-removal-plan-codex-2026-06-16.md"

"${CHECK}" "${ROOT}" --summary-json >/dev/null
"${PLAN}" "${ROOT}" \
  --repo codex \
  --as-of 2026-07-19 \
  --evidence-dependency-scan "${EVIDENCE}" \
  --rollback-plan "${EVIDENCE}" \
  --out-json "${TMP_DIR}/removal.json" \
  --out-md "${TMP_DIR}/removal.md" >/dev/null
"${CHECK}" "${ROOT}" --plan "${TMP_DIR}/removal.json" --summary-json >/dev/null

if "${PLAN}" "${ROOT}" \
  --repo agent-dev-kit \
  --evidence-dependency-scan "${EVIDENCE}" \
  --rollback-plan "${EVIDENCE}" \
  --out-json "${TMP_DIR}/bad.json" \
  --out-md "${TMP_DIR}/bad.md" >/dev/null 2>&1; then
  echo "[FAIL] protected agent-dev-kit unexpectedly produced a removal plan" >&2
  exit 1
fi

if "${PLAN}" "${ROOT}" \
  --repo codex \
  --evidence-dependency-scan "${EVIDENCE}" \
  --rollback-plan "${EVIDENCE}" \
  --apply >/dev/null 2>&1; then
  echo "[FAIL] destructive removal apply unexpectedly passed" >&2
  exit 1
fi

echo "[PASS] reference repository removal plans are hashed, dry-run, and non-destructive"
