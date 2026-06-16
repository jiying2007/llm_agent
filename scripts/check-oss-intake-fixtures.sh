#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

"${ROOT}/tests/test_oss_intake_ledger.sh" >/dev/null
"${ROOT}/tests/test_oss_registration_plan.sh" >/dev/null

echo "[PASS] oss intake fixtures and generated plans behave as expected"
