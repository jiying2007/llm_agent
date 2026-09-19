#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

ARGS=(python3 -m tools.control_plane.adk_interface --root "$ROOT" --summary-json)
if [[ -f "$ROOT/agent-dev-kit/manifest.json" ]]; then
  ARGS+=(--require-worktree)
fi
"${ARGS[@]}" >"$TMP"
python3 - "$TMP" <<'PY'
import json
import re
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert data["status"] == "pass", data
identity = data["identity"]
for key in ("commit", "tree", "manifest_blob"):
    assert re.fullmatch(r"[0-9a-f]{40}", identity[key]), (key, identity)
assert data["gitlink"] == identity["commit"], data
assert data["surfaces"]["manifest"] == "manifest.json", data
assert data["surfaces"]["maturity_test"] == "tests/test_product_maturity.sh", data
assert "tests/test_product_maturity_v5.sh" not in data["surfaces"].values(), data
assert "manifest.yaml" in data["deprecated_surfaces"], data
assert "tests/test_product_maturity_v4.sh" in data["deprecated_surfaces"], data
assert "tests/test_product_maturity_v5.sh" in data["deprecated_surfaces"], data
PY

echo '[PASS] pinned ADK interface identity is coherent'
