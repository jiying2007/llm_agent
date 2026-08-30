#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}" \
  python3 "${ROOT_DIR}/tests/test_maintainability_evidence_candidate.py"

echo "[PASS] maintainability evidence candidate"
