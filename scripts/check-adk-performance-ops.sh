#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${WORKSPACE_ROOT}/agent-dev-kit"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [[ ! -d "${ADK_ROOT}" ]]; then
  echo "[FAIL] agent-dev-kit not found: ${ADK_ROOT}" >&2
  exit 1
fi

rtk bash "${ADK_ROOT}/tests/test_performance_ops.sh"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" perf analyze --summary-json >"${TMP_DIR}/perf-analyze.json"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" ops weekly --summary-json >"${TMP_DIR}/ops-weekly.json"
rtk bash "${ADK_ROOT}/tests/run_all.sh" --quick --timing-json "${TMP_DIR}/run-all-quick.json" --max-failure-lines 20

if ! rtk rg -q '"status":"pass"|"status":"warn"' "${TMP_DIR}/perf-analyze.json"; then
  echo "[FAIL] perf analyze summary missing pass/warn status" >&2
  exit 1
fi
if ! rtk rg -q '"apply":0' "${TMP_DIR}/ops-weekly.json"; then
  echo "[FAIL] ops weekly summary must default to apply=0" >&2
  exit 1
fi
if ! rtk rg -q '"mode": "quick"' "${TMP_DIR}/run-all-quick.json"; then
  echo "[FAIL] quick run timing json missing quick mode" >&2
  exit 1
fi

echo "[PASS] adk performance and ops gates passed"
