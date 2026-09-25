#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.native_target_readiness --root . --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

value=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert value["schema"]=="llm-agent-native-target-readiness/v1", value
assert value["status"]=="pass", value
assert value["software_ready"] is True, value
assert all(value["software_surfaces"].values()), value
assert value["release_authorized"] is False, value
assert value["native_verified"] == bool(value["native_verified_targets"]), value
assert set(value["targets"]) == {"claude-code", "opencode"}, value

for target,item in value["targets"].items():
    assert item["conformance_level"] in {"static","runtime"}, (target,item)
    assert isinstance(item["evidence_count"], int) and item["evidence_count"] >= 0, (target,item)
    if item["native_verified"]:
        assert item["conformance_level"]=="runtime", (target,item)
        assert item["certification"]=="conformance-certified", (target,item)
        assert item["native_runtime_smoke"]=="pass", (target,item)
        assert item["runtime_identity_pinned"] is True, (target,item)
        assert item["evidence_count"] > 0, (target,item)
        assert item["evidence_paths_valid"] is True, (target,item)
        assert item["trust_enabled"] is True, (target,item)
        assert item["bound_registry_authorities"], (target,item)

if value["native_verified"]:
    assert value["terminal_status"]=="ready", value
    assert value["blockers"] == [], value
else:
    assert value["terminal_status"]=="blocked-external-evidence", value
    assert any("version-pinned-authenticated-native-campaign" in item for item in value["blockers"]), value
    assert any("signed-receipt-managed-registry-production-loader" in item for item in value["blockers"]), value

boundary=value["authority_boundary"]
assert boundary["source_layout_is_native_evidence"] is False, boundary
assert boundary["synthetic_campaign_is_native_evidence"] is False, boundary
assert boundary["managed_trust_without_receipt_is_native_evidence"] is False, boundary
assert boundary["requires_real_version_pinned_native_pass"] is True, boundary
PY

if python3 -m tools.control_plane.native_target_readiness --root . --require-native --summary-json >/dev/null; then
  python3 - "$TMP" <<'PY'
import json,sys
v=json.load(open(sys.argv[1],encoding="utf-8"))
assert v["native_verified"] is True and v["terminal_status"]=="ready", v
PY
else
  rc=$?
  test "$rc" -eq 2
  python3 - "$TMP" <<'PY'
import json,sys
v=json.load(open(sys.argv[1],encoding="utf-8"))
assert v["native_verified"] is False and v["terminal_status"]=="blocked-external-evidence", v
PY
fi

python3 -m tools.control_plane.cli native-readiness --root . --summary-json   | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["status"]=="pass", v'

echo '[PASS] native target readiness separates software readiness from real native evidence'
