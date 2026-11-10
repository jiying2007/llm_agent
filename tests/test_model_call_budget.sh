#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT"
python3 "$ROOT/tests/test_model_call_budget.py"
echo "[PASS] model_call_budget"
