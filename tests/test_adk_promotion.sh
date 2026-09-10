#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/agent-dev-kit/manifest.json" ]] || {
  echo "[FAIL] test_adk_promotion requires initialized agent-dev-kit checkout" >&2
  exit 1
}
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
SUMMARY="$TMP_DIR/summary.json"
RECEIPT="$TMP_DIR/promotion-receipt.json"

python3 -m tools.control_plane.adk_promotion \
  --root "$ROOT" \
  --candidate-dir agent-dev-kit \
  --updated-at 2026-09-10 \
  --receipt-out "$RECEIPT" \
  --summary-json >"$SUMMARY"

python3 - "$SUMMARY" "$RECEIPT" "$ROOT/adk.lock" <<'PY'
import json
import re
import sys
from pathlib import Path

from tools.control_plane.receipts import bind_receipt

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    receipt = json.load(handle)
lock = {}
for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

assert result == receipt, (result, receipt)
assert result["schema"] == "llm-agent-adk-promotion/v2", result
assert result["status"] == "planned", result
assert result["mode"] == "dry-run", result
assert result["candidate"]["commit"] == lock["agent-dev-kit.commit"], result
assert result["candidate"]["tree"] == lock["agent-dev-kit.tree"], result
assert result["candidate"]["manifest_blob"] == lock["agent-dev-kit.manifest_blob"], result
assert result["lock_schema"] == "llm-agent-adk-lock/v2", result
assert re.fullmatch(r"[0-9a-f]{40}", result["source"]["head"]), result
assert re.fullmatch(r"[0-9a-f]{40}", result["source"]["tree"]), result
assert re.fullmatch(r"[0-9a-f]{64}", result["receipt_sha256"]), result
assert result["release_authorized"] is False, result
assert result["requires_fresh_cross_repo_verification"] is True, result

rebound = bind_receipt(result)
assert rebound["receipt_sha256"] == result["receipt_sha256"], (rebound, result)

tampered = dict(result)
tampered["status"] = "applied-not-verified"
assert bind_receipt(tampered)["receipt_sha256"] != result["receipt_sha256"], result
PY

echo "[PASS] ADK promotion receipt binds immutable identity and rejects tampering"
