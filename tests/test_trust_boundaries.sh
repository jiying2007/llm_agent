#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT/agent-dev-kit/src:$ROOT${PYTHONPATH:+:$PYTHONPATH}"
exec python3 "$ROOT/tests/test_trust_boundaries.py"
