#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT"
python3 "$ROOT/tests/test_goal_loop_event_context.py"
echo "[PASS] goal_loop_event_context"
