#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 -m tools.control_plane.adk_source_pin --root "$ROOT" "$@"
