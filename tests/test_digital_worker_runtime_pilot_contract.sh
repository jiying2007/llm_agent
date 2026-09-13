#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT/manifests/digital_worker_runtime_pilot.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

assert data["schema_version"] == 3, data
assert data["contract_version"] == "1.2", data
assert data["status"] == "report-only", data
assert data["roles"]["agent-dev-kit"] == [
    "asset_profile", "skill_assets", "immutable_release_identity", "source_set_handoff_contract"
], data
assert "runtime_source_set_identity_ref" in data["frozen_inputs"], data
assert "adk_release_identity_ref" in data["frozen_inputs"], data
assert "runtime_distribution_identity_ref" in data["runtime_identity_required"], data
assert data["asset_identity_semantics"] == {
    "provider_release_is_immutable": True,
    "runtime_binding_selects_exact_source_set": True,
    "runtime_binding_assembles_runtime_distribution": True,
    "monolithic_runtime_bundle_is_not_required_identity": True,
    "source_of_truth_stays_at_source": True,
}, data
codex = data["candidate_runtime_bindings"][0]
assert codex["runtime"] == "codex", data
assert codex["repository"] == "jiying2007/codex", data
assert codex["source_identity_mode"] == "exact-release-source-blobs", data
assert codex["status"] == "source-set-bound", data
rules = data["hard_rules"]
for key in (
    "runtime_output_is_not_verification_pass",
    "runtime_local_conformance_is_not_domain_verification",
    "missing_runtime_binding_identity_is_blocked_not_pass",
    "missing_adk_release_identity_is_blocked_not_pass",
    "missing_runtime_source_set_identity_is_blocked_not_pass",
    "missing_runtime_distribution_identity_is_blocked_not_pass",
):
    assert rules[key] is True, (key, data)

text = path.read_text(encoding="utf-8")
for retired in (
    '"asset_bundle_identity"',
    '"adk_asset_bundle_hash"',
    '"missing_asset_bundle_identity_is_blocked_not_pass"',
    '"target_export_contract"',
    "BLOCKED_ASSET_BUNDLE_IDENTITY",
):
    assert retired not in text, retired
PY

echo '[PASS] digital-worker runtime pilot uses exact ADK release/source-set/runtime-distribution identity'
