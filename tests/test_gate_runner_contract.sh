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
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["schema"] == "llm-agent-gate-run/v2", data
assert data["status"] == "pass", data
assert re.fullmatch(r"[0-9a-f]{40}", data["source"]["head"]), data
assert re.fullmatch(r"[0-9a-f]{40}", data["source"]["tree"]), data
assert re.fullmatch(r"[0-9a-f]{64}", data["source"]["gate_manifest_sha256"]), data
assert data["blocked_capabilities"] == [], data
assert data["gates"], data
for gate in data["gates"]:
    assert gate["status"] == "pass", gate
    assert gate["evidence_class"] in {"source", "test", "runtime", "field", "release"}, gate
    assert gate["timeout_seconds"] > 0, gate
    assert isinstance(gate["argv"], list) and gate["argv"], gate
PY

if python3 -m tools.control_plane.gate_runner \
  --root "$ROOT" \
  --profile integration \
  --summary-json >"$TMP"; then
  echo "[FAIL] integration profile passed without adk-checkout capability" >&2
  exit 1
fi
python3 - "$TMP" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "blocked", data
assert "adk-checkout" in data["blocked_capabilities"], data
assert any(gate["status"] == "blocked" for gate in data["gates"]), data
PY

echo "[PASS] gate runner receipt and blocked-capability semantics"
