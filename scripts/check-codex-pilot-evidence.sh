#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────┐
# │ DEPRECATED: Use check-codex-pilot.sh <root> evidence instead.   │
# │ This script will be removed in a future release.                 │
# └──────────────────────────────────────────────────────────────────┘
echo "[WARN] DEPRECATED: use check-codex-pilot.sh <root> evidence" >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/check-codex-pilot.sh" "$@" evidence

# ── Original logic below (unreachable) ──────────────────────────────
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPORT="${ROOT}/reports/codex-pilot-report.md"

if [[ ! -f "${REPORT}" ]]; then
  echo "[FAIL] codex pilot report missing: ${REPORT}" >&2
  exit 1
fi

require_key_yes() {
  local key="$1"
  local value
  value="$(awk -F': ' -v k="$key" '$1=="- "k {print $2}' "${REPORT}" | tr -d '\r' | tail -n1 || true)"
  if [[ "${value}" != "yes" ]]; then
    echo "[FAIL] pilot evidence key not ready: ${key}=${value:-<missing>}" >&2
    exit 2
  fi
}

echo "[INFO] report=${REPORT}"

rg -q '^## 门禁证据状态$' "${REPORT}" || {
  echo "[FAIL] missing section: 门禁证据状态" >&2
  exit 2
}

require_key_yes "pilot_high_risk_case_done"
require_key_yes "artifact_labels_complete"
require_key_yes "review_test_consistent"
require_key_yes "command_evidence_recorded"

echo "[PASS] codex pilot evidence ready"

