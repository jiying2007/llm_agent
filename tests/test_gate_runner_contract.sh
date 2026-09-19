#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
FIXTURE="$(mktemp -d)"
trap 'rm -f "$TMP"; rm -rf "$FIXTURE"' EXIT

python3 -m tools.control_plane.gate_runner \
  --root "$ROOT" \
  --profile contract \
  --summary-json >"$TMP"

python3 - "$TMP" <<'PY'
import json
import re
import sys

from tools.control_plane.receipts import bind_receipt

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["schema"] == "llm-agent-gate-run/v2", data
assert data["status"] == "pass", data
assert re.fullmatch(r"[0-9a-f]{40}", data["source"]["head"]), data
assert re.fullmatch(r"[0-9a-f]{40}", data["source"]["tree"]), data
assert re.fullmatch(r"[0-9a-f]{64}", data["source"]["gate_manifest_sha256"]), data
assert re.fullmatch(r"[0-9a-f]{64}", data["receipt_sha256"]), data
assert bind_receipt(data)["receipt_sha256"] == data["receipt_sha256"], data
assert data["blocked_capabilities"] == [], data
assert data["gates"], data
for gate in data["gates"]:
    assert gate["status"] == "pass", gate
    assert gate["evidence_class"] in {"source", "test", "runtime", "field", "release"}, gate
    assert gate["timeout_seconds"] > 0, gate
    assert isinstance(gate["argv"], list) and gate["argv"], gate

tampered = dict(data)
tampered["profile"] = "tampered"
assert bind_receipt(tampered)["receipt_sha256"] != data["receipt_sha256"], data
PY

mkdir -p "$FIXTURE/manifests"
cat >"$FIXTURE/manifests/gates.json" <<'JSON'
{
  "schema": "llm-agent-gates/v2",
  "gates": {
    "needs-capability": {
      "owner": "fixture",
      "side_effect": "none",
      "depends_on": [],
      "requires": ["fixture-capability"],
      "inputs": [],
      "outputs": [],
      "cache_policy": "disabled",
      "argv": ["bash", "-lc", "true"],
      "timeout_seconds": 5,
      "evidence_class": "test"
    }
  },
  "profiles": {
    "fixture": ["needs-capability"]
  }
}
JSON
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email test@example.invalid
git -C "$FIXTURE" config user.name test
git -C "$FIXTURE" add manifests/gates.json
git -C "$FIXTURE" commit -q -m fixture

if python3 -m tools.control_plane.gate_runner \
  --root "$FIXTURE" \
  --profile fixture \
  --summary-json >"$TMP"; then
  echo "[FAIL] fixture gate passed without required capability" >&2
  exit 1
fi
python3 - "$TMP" <<'PY'
import json
import re
import sys
from tools.control_plane.receipts import bind_receipt
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "blocked", data
assert "fixture-capability" in data["blocked_capabilities"], data
assert any(gate["status"] == "blocked" for gate in data["gates"]), data
assert re.fullmatch(r"[0-9a-f]{64}", data["receipt_sha256"]), data
assert bind_receipt(data)["receipt_sha256"] == data["receipt_sha256"], data
PY

echo "[PASS] gate runner content-addressed receipt and blocked-capability semantics"
