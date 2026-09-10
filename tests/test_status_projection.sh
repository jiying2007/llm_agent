#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-10 \
  --summary-json >"$TMP"

python3 - "$TMP" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "pass", data
assert data["source"]["pin_consistent"] is True, data
assert data["current_evidence_state"] == "stale-or-historical", data
assert data["last_verified_baseline"]["fresh_for_current_head"] is False, data
assert data["release_authorized"] is False, data
PY

if python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-10 \
  --require-fresh >/dev/null 2>&1; then
  echo "[FAIL] release freshness accepted historical baseline for current HEAD" >&2
  exit 1
fi

echo "[PASS] current status projection preserves historical baseline without current release claim"
