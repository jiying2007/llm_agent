#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/scripts/check-adk-goal-capability.sh"

rtk rg -q 'tests/test_runtime_control.sh' "$SCRIPT" || {
  echo "[FAIL] ADK goal capability gate does not run Runtime Control regression" >&2
  exit 1
}
rtk rg -q 'Runtime Control' "$SCRIPT" || {
  echo "[FAIL] ADK goal capability summary does not disclose Runtime Control coverage" >&2
  exit 1
}

echo "[PASS] ADK goal capability gate covers the single Runtime Control engine"
