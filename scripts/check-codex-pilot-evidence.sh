#!/usr/bin/env bash
# DEPRECATED: Use check-codex-pilot.sh <root> evidence
echo "[WARN] DEPRECATED: use check-codex-pilot.sh <root> evidence" >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/check-codex-pilot.sh" "$@" evidence
