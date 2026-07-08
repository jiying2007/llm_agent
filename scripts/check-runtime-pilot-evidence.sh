#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-runtime-pilot.sh" "${ROOT}" evidence
