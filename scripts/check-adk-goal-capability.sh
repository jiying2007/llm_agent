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

rtk bash "${ADK_ROOT}/scripts/devkit.sh" goal check --summary-json >"${TMP_DIR}/goal-contracts.json"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" capability health --summary-json >"${TMP_DIR}/capability-health.json"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" perf budget --summary-json >"${TMP_DIR}/performance-budgets.json"

if ! rtk rg -q '"status":"pass"' "${TMP_DIR}/goal-contracts.json"; then
  echo "[FAIL] ADK goal contracts did not pass" >&2
  exit 1
fi
if ! rtk rg -q '"status":"pass"' "${TMP_DIR}/capability-health.json"; then
  echo "[FAIL] ADK capability health did not pass" >&2
  exit 1
fi
if ! rtk rg -q '"status":"pass"' "${TMP_DIR}/performance-budgets.json"; then
  echo "[FAIL] ADK performance budgets did not pass" >&2
  exit 1
fi

echo "[PASS] adk goal, capability, and performance budget gates passed"
