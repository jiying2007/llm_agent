#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/check-oss-removal-plan.sh" "${ROOT}" --summary-json >/dev/null
"${ROOT}/scripts/plan-oss-subrepo-removal.sh" "${ROOT}" --repo codex --out-json "${TMP_DIR}/removal.json" --out-md "${TMP_DIR}/removal.md" >/dev/null
"${ROOT}/scripts/check-oss-removal-plan.sh" "${ROOT}" --plan "${TMP_DIR}/removal.json" --summary-json >/dev/null

if "${ROOT}/scripts/plan-oss-subrepo-removal.sh" "${ROOT}" --repo agent-dev-kit --out-json "${TMP_DIR}/bad.json" --out-md "${TMP_DIR}/bad.md" >/dev/null 2>&1; then
  echo "[FAIL] protected agent-dev-kit unexpectedly produced a removal plan" >&2
  exit 1
fi

echo "[PASS] oss removal plan tests passed"
