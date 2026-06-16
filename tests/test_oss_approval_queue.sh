#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --summary-json >/dev/null
"${ROOT}/scripts/generate-oss-intake-approval-queue.sh" "${ROOT}" --out-json "${TMP_DIR}/queue.json" --out-md "${TMP_DIR}/queue.md" >/dev/null
"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --queue "${TMP_DIR}/queue.json" --summary-json >/dev/null
"${ROOT}/scripts/oss-intake.sh" queue --out-json "${TMP_DIR}/queue-via-wrapper.json" --out-md "${TMP_DIR}/queue-via-wrapper.md" >/dev/null

echo "[PASS] oss approval queue tests passed"
