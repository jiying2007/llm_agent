#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.campaign_readiness --root "$ROOT" --summary-json >"$TMP"
python3 - "$ROOT" "$TMP" <<'PY'
import json, sys
from pathlib import Path
root=Path(sys.argv[1])
value=json.load(open(sys.argv[2],encoding="utf-8"))
assert value["schema"] == "llm-agent-campaign-readiness/v1", value
assert value["status"] == "pass", value
assert value["projection_semantics"] == "read-only-composition-not-a-new-authority", value
assert value["boundaries"]["writes"] is False
assert value["boundaries"]["network"] is False
assert value["boundaries"]["credentials_read"] is False
assert value["boundaries"]["software_ready_is_not_effectiveness_proof"] is True
assert value["boundaries"]["campaign_evidence_does_not_auto_authorize_release"] is True
assert value["product_authority"]["relation"] == "independent-from-campaign-software-readiness"
assert isinstance(value["product_authority"]["release_authorized"], bool)

effect=value["campaigns"]["effect"]
native=value["campaigns"]["native"]
assert effect["backlog_item"] == "G22"
assert effect["evidence_status"] == "external-input-required"
assert effect["lifecycle_authority"] == "none-evidence-only"
assert native["backlog_item"] == "G21"
assert native["lifecycle_authority"] == "none-evidence-only"

if (root/"agent-dev-kit/manifest.json").is_file():
    assert value["source"]["adk_worktree"]["worktree_status"] == "available", value
    assert value["source"]["adk_worktree"]["identity_status"] == "ready", value
    assert value["software_status"] == "ready", value
    assert effect["software_status"] == "ready" and effect["campaign_status"] == "ready-for-real-execution", effect
    assert native["software_status"] == "ready", native
    registry=value["source"]["adk_worktree"]["native_registry"]
    enabled=registry["enabled_authority_count"]
    targets=value["source"]["adk_worktree"]["targets"]
    runtime=[
        name for name,item in targets.items()
        if item["conformance_level"]=="runtime"
        and item["certification"]=="conformance-certified"
        and item["native_runtime_smoke"]=="pass"
    ]
    if enabled == 0:
        assert "no-enabled-native-authority" in native["blockers"], native
    if not runtime:
        assert "no-native-certified-target" in native["blockers"], native
else:
    assert value["source"]["adk_worktree"]["worktree_status"] == "unavailable", value
    assert value["software_status"] == "blocked", value
print("[PASS] campaign readiness projection preserves software/evidence authority split")
PY

if [[ -f "$ROOT/agent-dev-kit/manifest.json" ]]; then
  python3 -m tools.control_plane.campaign_readiness     --root "$ROOT" --require-adk-worktree --gate software --summary-json >/dev/null
else
  set +e
  python3 -m tools.control_plane.campaign_readiness     --root "$ROOT" --gate software --summary-json >/dev/null
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || { echo "[FAIL] missing ADK software gate rc=$rc" >&2; exit 1; }
fi

echo "[PASS] campaign readiness software gate"
