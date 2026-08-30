#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -gt 0 && "${1}" != -* ]]; then
  [[ -d "${1}" ]] || {
    echo "[FAIL] workspace root is not a directory: ${1}" >&2
    exit 2
  }
  ROOT_DIR="$(cd "${1}" && pwd)"
  shift
fi

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m tools.codex_assets.maintainability_budget \
  --root "${ROOT_DIR}" --repository-id llm-agent "$@"
