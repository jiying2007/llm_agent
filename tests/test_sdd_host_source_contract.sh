#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT"
python3 "$ROOT/tests/test_sdd_host_source_contract.py"
echo "[PASS] SDD and Goal Host source contract (not native evidence)"
