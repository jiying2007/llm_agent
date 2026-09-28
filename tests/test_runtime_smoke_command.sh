#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}" python3 "$ROOT/tests/test_runtime_smoke_command.py"
