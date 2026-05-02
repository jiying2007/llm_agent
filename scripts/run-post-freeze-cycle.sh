#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DAYS="${2:-7}"
OUT="${3:-${ROOT}/reports/weekly-change-report.md}"

echo "[INFO] post-freeze cycle start"
echo "[INFO] root=${ROOT}"
echo "[INFO] days=${DAYS}"
echo "[INFO] out=${OUT}"

bash "${ROOT}/scripts/check-doc-sync.sh" "${ROOT}"
bash "${ROOT}/scripts/diff-scan.sh" "${ROOT}" "${DAYS}" "${OUT}"
bash "${ROOT}/scripts/check-adoption-matrix-status.sh" "${ROOT}"
bash "${ROOT}/scripts/generate-adoption-matrix-summary.sh" "${ROOT}" "${ROOT}/reports/adoption-matrix-summary.md"

echo "[PASS] post-freeze cycle done"
