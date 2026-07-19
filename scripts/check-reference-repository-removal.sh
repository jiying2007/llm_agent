#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -gt 0 && "${1}" != -* ]]; then
  ROOT_DIR="$(cd "${1}" && pwd)"
  shift
fi
export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

exec python3 -m tools.codex_assets.reference_repository --root "${ROOT_DIR}" check-removal "$@"
