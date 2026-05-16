#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

echo "[WARN] check-codex-pilot-coverage.sh is deprecated; forwarding to check-codex-pilot.sh coverage" >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-codex-pilot.sh" "${ROOT}" coverage
