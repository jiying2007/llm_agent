#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-11 \
  --summary-json >"$TMP"

python3 - "$TMP" "$ROOT/reports/current-status.md" "$ROOT/adk.lock" <<'PY'
import json
import re
import sys
from pathlib import Path

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
status = Path(sys.argv[2]).read_text(encoding="utf-8")
lock = {}
for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

match = re.search(r"^- projection_inputs_sha256:\s*([0-9a-f]{64})$", status, re.MULTILINE)
assert match, status
current_adk = lock["agent-dev-kit.commit"]

assert data["schema"] == "llm-agent-status-projection/v3", data
assert data["status"] == "pass", data
assert data["source"]["pin_consistent"] is True, data
assert data["source"]["adk_lock_commit"] == current_adk, data
assert data["current_projection"]["consistent"] is True, data
assert data["current_projection"]["mismatches"] == {}, data
assert data["current_projection"]["inputs_sha256"] == match.group(1), data
assert data["current_evidence_state"] == "source-current-evidence-historical", data
assert data["last_verified_baseline"]["source_inputs_match"] is False, data
assert data["last_verified_baseline"]["fresh_for_current_source"] is False, data
assert data["release_authorized"] is False, data
assert "- release_evidence_relation: historical" in status, status
assert f"- current_adk_commit: {current_adk}" in status, status
PY

if python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-11 \
  --require-fresh >/dev/null 2>&1; then
  echo "[FAIL] release freshness accepted historical evidence for current source projection" >&2
  exit 1
fi

echo "[PASS] current source projection is synchronized while historical release evidence stays fail-closed"
