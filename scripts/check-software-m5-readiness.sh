#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ $# -gt 0 && "$1" != --* ]]; then
  shift
fi

export PYTHONPATH="${ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m tools.codex_assets.software_m5 --root "${ROOT}" check "$@"
