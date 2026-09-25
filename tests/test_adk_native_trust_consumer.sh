#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT/agent-dev-kit" <<'PY'
import json
import os
import sys
from pathlib import Path

from agent_dev_kit.model import Manifest
from agent_dev_kit.native_trust import load_native_trust_registry
from agent_dev_kit.target_contracts import load_target_contract

adk = Path(sys.argv[1]).resolve()
manifest = Manifest.load(adk)
assert manifest.version == "7.3.0", manifest.version

registry = load_native_trust_registry(adk)
assert registry["schema"] == "adk-native-conformance-trust-registry/v1", registry
assert registry["status"] == "active", registry
assert registry["authority_model"] == "owner-reviewed-managed-registry", registry
assert registry["authorities"] == {}, registry

# Static target loading must not need a verifier binary or an enabled authority.
old_path = os.environ.get("PATH")
os.environ["PATH"] = ""
try:
    for target in sorted(manifest.direct_targets()):
        contract = load_target_contract(manifest, target)
        adapter = contract.adapter
        assert adapter["conformance"]["level"] == "static", (target, adapter)
        assert adapter["conformance"]["certification"] == "not-certified", (target, adapter)
        assert adapter["conformance"]["native_runtime_smoke"] == "not-run", (target, adapter)
        assert adapter["conformance_trust_policy"]["enabled"] is False, (target, adapter)
finally:
    if old_path is None:
        os.environ.pop("PATH", None)
    else:
        os.environ["PATH"] = old_path

print("[PASS] ADK 7.3.0 managed native trust is installed but enables no authority or target")
PY

bash "$ROOT/agent-dev-kit/scripts/devkit.sh" target check --all --level static --summary-json > /tmp/adk-native-trust-target-check.json
python3 - /tmp/adk-native-trust-target-check.json <<'PY'
import json, sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["status"] == "pass", value
assert value["schema"] == "adk-target-check/v1", value
assert value["targets"], value
for target, item in value["targets"].items():
    adapter=item["adapter"]
    assert adapter["conformance"]["level"] == "static", (target, adapter)
    assert adapter["conformance"]["certification"] == "not-certified", (target, adapter)
    assert adapter["conformance"]["native_runtime_smoke"] == "not-run", (target, adapter)
print("[PASS] Root static target consumer preserves native certification boundary")
PY
