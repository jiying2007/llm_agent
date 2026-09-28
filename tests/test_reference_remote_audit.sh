#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}" python3 -m unittest tests.test_reference_remote_audit -v
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(
  cd "$TMP"
  PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}" python3 -m tools.codex_assets.reference_remote_audit --help >/dev/null
  PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}" python3 -m tools.codex_assets.reference_remote_audit \
    --root "$ROOT" --summary-json
)
