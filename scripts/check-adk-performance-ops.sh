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

rtk bash "${ADK_ROOT}/tests/test_product_maturity_v3.sh"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" benchmark run --iterations 5 --summary-json >"${TMP_DIR}/benchmark.json"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" security check --summary-json >"${TMP_DIR}/security.json"
rtk bash "${ADK_ROOT}/scripts/devkit.sh" release check --summary-json >"${TMP_DIR}/release.json"
rtk bash "${ADK_ROOT}/tests/run_all.sh" --quick --timing-json "${TMP_DIR}/run-all-quick.json" --max-failure-lines 20
rtk bash "${ADK_ROOT}/scripts/check-performance-budgets.sh" --strict --timing-json "${TMP_DIR}/run-all-quick.json"

python3 - "${TMP_DIR}/benchmark.json" "${TMP_DIR}/security.json" "${TMP_DIR}/release.json" <<'PY'
import json
import sys

benchmark, security, release = [json.load(open(path, encoding="utf-8")) for path in sys.argv[1:4]]
assert benchmark["status"] == "pass", benchmark
assert benchmark["budget_gate"] and all(benchmark["budget_gate"].values()), benchmark
assert security["status"] == "pass", security
assert release["status"] == "pass", release
PY
echo "[PASS] adk benchmark, security, release, and quick regression gates passed"
