#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

if [[ "${1:-}" != "--help" && "${1:-}" != "-h" ]]; then
  python3 -m tools.control_plane.adk_interface --source-pin --materialize-lock --root "${ROOT_DIR}" --summary-json >/dev/null
fi

exec python3 -m tools.codex_assets.software_m5_v3 --root "${ROOT_DIR}" "$@"
