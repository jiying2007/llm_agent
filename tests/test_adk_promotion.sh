#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/agent-dev-kit/manifest.json" ]] || {
  echo "[FAIL] test_adk_promotion requires initialized agent-dev-kit checkout" >&2
  exit 1
}
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.adk_promotion \
  --root "$ROOT" \
  --candidate-dir agent-dev-kit \
  --updated-at 2026-09-10 \
  --summary-json >"$TMP"

python3 - "$TMP" "$ROOT/adk.lock" <<'PY'
import json
import sys
from pathlib import Path

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
lock = {}
for line in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
assert result["status"] == "planned", result
assert result["mode"] == "dry-run", result
assert result["candidate"]["commit"] == lock["agent-dev-kit.commit"], result
assert result["candidate"]["tree"] == lock["agent-dev-kit.tree"], result
assert result["candidate"]["manifest_blob"] == lock["agent-dev-kit.manifest_blob"], result
assert result["release_authorized"] is False, result
PY

echo "[PASS] ADK promotion dry-run binds immutable candidate identity without release authorization"
