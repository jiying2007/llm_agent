#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/check-oss-continuous-operation.sh" "${ROOT}" --summary-json >/dev/null
"${ROOT}/scripts/run-oss-intake-cycle.sh" "${ROOT}" \
  --out-json "${TMP_DIR}/cycle.json" \
  --out-md "${TMP_DIR}/cycle.md" \
  --queue-json "${TMP_DIR}/queue.json" \
  --queue-md "${TMP_DIR}/queue.md" \
  --evidence-md "${TMP_DIR}/evidence.md" >/dev/null
"${ROOT}/scripts/check-oss-continuous-operation.sh" "${ROOT}" --report "${TMP_DIR}/cycle.json" --summary-json >/dev/null

echo "[PASS] oss continuous operation tests passed"
