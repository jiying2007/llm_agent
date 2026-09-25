#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT/agent-dev-kit" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

from agent_dev_kit.agent_value_contracts import load_contract, validate_contract
from agent_dev_kit.agent_value_trust import (
    build_managed_agent_value_evidence_verifier,
    load_agent_value_trust_registry,
)
from agent_dev_kit.model import Manifest, ManifestError

adk = Path(sys.argv[1]).resolve()
root = adk.parent
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

expected_version = lock["agent-dev-kit.version"]
major, minor, patch = (int(item) for item in expected_version.split("."))
assert (major, minor, patch) >= (7, 5, 0), expected_version
assert lock["agent-dev-kit.commit"], lock

manifest = Manifest.load(adk)
assert manifest.version == expected_version, (manifest.version, lock)

registry = load_agent_value_trust_registry(adk)
assert registry["schema"] == "adk-agent-value-trust-registry/v1", registry
assert registry["status"] == "active", registry
assert registry["authority_model"] == "owner-reviewed-managed-registry", registry
assert registry["authorities"] == {}, registry

contract = load_contract(adk / "manifests" / "agent_value_contracts.json")
report = validate_contract(contract, manifest)
assert report["status"] == "pass", report
policy = contract["evidence_authority_policy"]
assert policy["managed"] is True, policy
assert policy["status"] == "disabled", policy
assert policy["backend"] == "not-configured", policy
assert policy["authorities"] == [], policy

try:
    build_managed_agent_value_evidence_verifier(manifest, contract)
except ManifestError as exc:
    assert "policy_disabled" in str(exc), exc
else:
    raise AssertionError("canonical disabled Agent Value contract unexpectedly built a managed verifier")

done = subprocess.run(
    [
        sys.executable,
        "-m",
        "agent_dev_kit.agent_value",
        "--manifest-root",
        str(adk),
        "--emit-measurements",
        "--summary-json",
    ],
    cwd=root,
    text=True,
    capture_output=True,
    timeout=60,
)
assert done.returncode == 0, (done.returncode, done.stdout, done.stderr)
value = json.loads(done.stdout)
assert value["contract"]["status"] == "pass", value
measurement = value["measurement"]
assert measurement["measurement_status"] == "not-measured", measurement
assert measurement["reason"] == "no-valid-receipts", measurement
assert measurement["asset_measurements"] == [], measurement
assert measurement["raw_content_stored"] is False, measurement

print(
    f"[PASS] pinned ADK {expected_version} Agent Value trust software is available "
    "while canonical authority remains disabled and measurements remain not-measured"
)
PY
