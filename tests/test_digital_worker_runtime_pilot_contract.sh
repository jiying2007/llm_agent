#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT/manifests/digital_worker_runtime_pilot.json" "$ROOT/manifests/long_term_asset_qualification.json" "$ROOT/tools/control_plane/runtime_portability.py" "$ROOT/tools/control_plane/cli.py" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lta_path = Path(sys.argv[2])
certifier_path = Path(sys.argv[3])
cli_path = Path(sys.argv[4])
data = json.loads(path.read_text(encoding="utf-8"))
lta = json.loads(lta_path.read_text(encoding="utf-8"))

assert data["schema_version"] == 4, data
assert data["contract_version"] == "1.3", data
assert data["status"] == "report-only", data
assert "governance_identity" in data["roles"]["digital-worker"], data
assert data["roles"]["agent-dev-kit"] == [
    "asset_profile", "skill_assets", "immutable_release_identity", "source_set_handoff_contract"
], data
for field in (
    "digital_worker_governance_identity_ref",
    "runtime_source_set_identity_ref",
    "adk_release_identity_ref",
):
    assert field in data["frozen_inputs"], (field, data)
assert "runtime_distribution_identity_ref" in data["runtime_identity_required"], data
assert data["asset_identity_semantics"] == {
    "provider_release_is_immutable": True,
    "runtime_binding_selects_exact_source_set": True,
    "runtime_binding_assembles_runtime_distribution": True,
    "monolithic_runtime_bundle_is_not_required_identity": True,
    "source_of_truth_stays_at_source": True,
}, data
assert set(data["replaceability_evidence_levels"]) == {
    "R1-binding-conformance", "R2-real-provider-substitution"
}, data
assert data["terminal_replaceability_evidence_level"] == "R2-real-provider-substitution", data

bindings = {item["runtime"]: item for item in data["candidate_runtime_bindings"]}
assert set(bindings) == {"codex", "claude-code"}, bindings
assert len(data["candidate_runtime_bindings"]) == 2, data["candidate_runtime_bindings"]

codex = bindings["codex"]
assert codex["repository"] == "https://github.com/jiying2007/codex.git", codex
assert codex["target"] == "codex-cli", codex
assert codex["source_identity_mode"] == "exact-release-source-blobs", codex
assert codex["status"] == "source-set-bound", codex

claude = bindings["claude-code"]
assert claude["repository"] == "https://github.com/jiying2007/claude.git", claude
assert claude["target"] == "claude-code", claude
assert claude["status"] == "binding-candidate-blocked", claude
assert claude["candidate_pr"] == "jiying2007/claude#1", claude
assert claude["blocker_ref"] == "jiying2007/claude#2", claude
assert claude["blocker"] == "github-hosted-runner-admission-before-step-execution", claude

# The active contract is closed over exactly the declared two-runtime set.
# A retired runtime cannot re-enter without changing this mandatory assertion.
ready_statuses = {"source-set-bound", "ready", "active"}
assert [name for name, item in bindings.items() if item["status"] in ready_statuses] == ["codex"], bindings
assert [name for name, item in bindings.items() if item["status"] == "binding-candidate-blocked"] == ["claude-code"], bindings
certifier_text = certifier_path.read_text(encoding="utf-8")
assert 'READY_BINDING_STATUSES = {"source-set-bound", "ready", "active"}' in certifier_text, certifier_text
assert "binding-candidate-blocked" not in ready_statuses

rules = data["hard_rules"]
for key in (
    "runtime_output_is_not_verification_pass",
    "runtime_local_conformance_is_not_domain_verification",
    "execution_receipt_must_not_contain_verification_pass",
    "same_verifier_and_reviewer_standard",
    "missing_runtime_binding_identity_is_blocked_not_pass",
    "missing_digital_worker_governance_identity_is_blocked_not_pass",
    "missing_adk_release_identity_is_blocked_not_pass",
    "missing_runtime_source_set_identity_is_blocked_not_pass",
    "missing_runtime_distribution_identity_is_blocked_not_pass",
    "r1_binding_conformance_is_not_r2_real_provider_substitution",
    "terminal_replaceability_requires_r2_real_provider_substitution",
    "candidate_runtime_bindings_must_match_declared_set_exactly",
    "retired_runtime_bindings_must_be_absent",
):
    assert rules[key] is True, (key, data)

requirements = {item["id"]: item for item in lta["blocking_requirements"]}
lta02 = requirements["LTA-02"]
assert lta02["status"] == "blocked_external_evidence", lta02
assert lta02["implementation_status"] == "certifier-ready", lta02
assert lta02["required_healthy_runtime_bindings"] >= 2, lta02
assert lta02["required_evidence_level"] == "R2-real-provider-substitution", lta02
assert lta02["r1_binding_conformance_is_terminal_evidence"] is False, lta02
assert lta02["certifier"] == "tools.control_plane.runtime_portability", lta02
assert lta02["default_evidence_path"] == "reports/long-term-assets/runtime-portability-current.json", lta02
assert lta02["remaining_external_blocker"] == "second-real-runtime-provider-binding-and-R2-comparison-evidence", lta02
assert certifier_path.is_file()
assert '"runtime-portability": "tools.control_plane.runtime_portability"' in cli_path.read_text(encoding="utf-8")

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

echo '[PASS] digital-worker runtime pilot is exact Codex + Claude while preserving R2-only terminal portability'
