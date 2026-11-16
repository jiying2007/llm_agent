#!/usr/bin/env bash
set -euo pipefail
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$SCRIPT_ROOT"
if [[ $# -gt 0 && "$1" != -* ]]; then
  ROOT="$1"
  shift
fi
export PYTHONPATH="${SCRIPT_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
# Preserve caller-relative inputs without importing a caller-owned tools package.
exec python3 -P -m tools.control_plane.adk_interface --source-pin --root "$ROOT" "$@"
