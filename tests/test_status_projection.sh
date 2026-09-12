#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
CERT="$(mktemp)"
trap 'rm -f "$TMP" "$CERT"' EXIT

python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --summary-json >"$TMP"

bash "$ROOT/scripts/software-m5.sh" certify --summary-json >"$CERT"

python3 - "$TMP" "$CERT" "$ROOT/reports/current-status.md" "$ROOT/adk.lock" <<'PY'
import json
import re
import sys
from pathlib import Path

projection = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
cert = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
status = Path(sys.argv[3]).read_text(encoding="utf-8")
lock = {}
for line in Path(sys.argv[4]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

match = re.search(r"^- projection_inputs_sha256:\s*([0-9a-f]{64})$", status, re.MULTILINE)
assert match, status
assert projection["schema"] == "llm-agent-status-projection/v3", projection
assert projection["status"] == "pass", projection
assert projection["source"]["pin_consistent"] is True, projection
assert projection["source"]["adk_lock_commit"] == lock["agent-dev-kit.commit"], projection
assert projection["current_projection"]["consistent"] is True, projection
assert projection["current_projection"]["mismatches"] == {}, projection
assert projection["current_projection"]["inputs_sha256"] == match.group(1), projection
assert projection["current_evidence_state"] == "verified-for-current-source", projection
assert projection["last_verified_baseline"]["source_inputs_match"] is True, projection
assert projection["last_verified_baseline"]["fresh_for_current_source"] is True, projection
assert projection["release_authorized"] is True, projection
assert "- release_evidence_relation: current" in status, status
assert "- current_product_maturity: M5" in status, status
assert "- current_software_m5_certified: true" in status, status
assert "- release_authorized: true" in status, status

assert cert["software_m5_certified"] is True, cert
assert cert["certification_status"] == "pass", cert
assert cert["blocking_gates"] == [], cert
assert cert["declaration_status"] == "pass", cert
PY

python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --require-fresh \
  --summary-json >/dev/null

echo "[PASS] M5 current-source projection is fresh, current, and release-authorized"
