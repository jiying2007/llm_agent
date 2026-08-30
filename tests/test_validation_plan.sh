#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="$ROOT" python3 "$ROOT/tests/test_validation_plan.py"
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.validation_plan --root "$ROOT" --summary-json \
  | python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["schema"] == "llm-agent-validation-plan/v1"; assert value["tier"] in {"L1","L2","L3","L4"}'
echo "[PASS] validation plan"
