#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT/agent-dev-kit/src:$ROOT"
exec python3 -m unittest discover -s "$ROOT/tests" -p 'test_goal_efficiency.py' -v
