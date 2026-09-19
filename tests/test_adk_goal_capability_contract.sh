#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/scripts/check-adk-goal-capability.sh"

grep -Fq 'tests/test_execution_policy.sh' "$SCRIPT" || {
  echo "[FAIL] ADK goal capability gate does not run Execution Policy regression" >&2
  exit 1
}
grep -Fq 'Execution Policy' "$SCRIPT" || {
  echo "[FAIL] ADK goal capability summary does not disclose Execution Policy coverage" >&2
  exit 1
}

echo "[PASS] ADK goal capability gate covers the canonical Execution Policy engine"
