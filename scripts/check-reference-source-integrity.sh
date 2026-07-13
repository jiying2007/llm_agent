#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

rtk bash "${ROOT}/tests/test_reference_source_integrity.sh"

echo "[PASS] reference source integrity gate ready"
