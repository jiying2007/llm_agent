#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

echo "[WARN] check-codex-pilot-evidence.sh is deprecated; forwarding to check-codex-pilot.sh evidence" >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-codex-pilot.sh" "${ROOT}" evidence
