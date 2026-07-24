#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ $# -gt 0 && "$1" != --* ]]; then
  shift
fi

exec bash "${ROOT}/tests/run_all.sh" "$@"
