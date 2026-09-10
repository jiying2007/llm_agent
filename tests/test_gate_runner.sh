#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.gate_runner \
  --root "$ROOT" \
  --profile contract \
  --summary-json >"$TMP"

python3 - "$TMP" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
assert result["status"] == "pass", result
assert [item["name"] for item in result["gates"]] == [
    "adk-pin",
    "gitlink-registry",
    "source-hygiene",
]
assert all(item["status"] == "pass" for item in result["gates"])
PY

echo "[PASS] declarative gate runner contract"
