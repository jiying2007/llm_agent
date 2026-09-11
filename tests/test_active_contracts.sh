#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.active_contracts \
  --root "$ROOT" \
  --as-of 2026-09-11 \
  --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert data["status"] == "pass", data
assert data["item_count"] >= 22, data
assert data["failures"] == [], data
PY

echo '[PASS] active governance references are fresh and executable'
