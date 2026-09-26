#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT:$ROOT/agent-dev-kit/src${PYTHONPATH:+:$PYTHONPATH}"
python3 -m unittest discover -s "$ROOT/tests" -p test_effect_evidence_index.py
