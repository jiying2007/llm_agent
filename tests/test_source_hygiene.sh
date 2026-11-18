#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.source_hygiene --root "$ROOT" --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "pass", data
assert data["violations"] == [], data
PY

# Retired Root scripts must not reintroduce a second version authority or direct live restore.
for retired in scripts/version-manager.sh scripts/backup-rollback.sh; do
  if [[ -e "$ROOT/$retired" || -L "$ROOT/$retired" ]]; then
    echo "[FAIL] retired Root control path reintroduced: $retired" >&2
    exit 1
  fi
done

echo "[PASS] source hygiene contract and retired Root surface"
