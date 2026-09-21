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

assert data["schema_version"] == 5, data
assert data["contract_version"] == "1.5", data
assert data["status"] == "report-only", data
assert "governance_identity" in data["roles"]["digital-worker"], data
assert "r2_freeze" in data["roles"]["digital-worker"], data
assert "execution_evidence_intake" in data["roles"]["digital-worker"], data
assert "provider_execution" in data["roles"]["runtime-binding"], data
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
assert set(data["replaceability_evidence_levels"]) == {
    "R1-binding-conformance", "R2-real-provider-substitution"
}, data
assert data["terminal_replaceability_evidence_level"] == "R2-real-provider-substitution", data

ownership = data["execution_ownership"]
assert ownership == {
    "model": "runtime-owned-local-provider-execution+digital-worker-local-verification",
    "provider_credentials_owner": "runtime-local-auth-state",
    "provider_execution_authority_owner": "runtime-binding-repository",
    "digital_worker_holds_provider_credentials": False,
    "runtime_execution_evidence_transport": "local-terminal-digest-bound-runtime-evidence",
    "digital_worker_verifies_execution_provenance": True,
    "digital_worker_projects_native_receipts": True,
    "digital_worker_domain_verification_is_separate": True,
    "independent_review_must_be_distinct_from_all_runtime_executors_and_verifier": True,
    "local_execution_receipt_is_not_r2_pass": True,
    "runtime_home_mode": "shared-user-home",
    "runtime_local_state_policy": "reuse-local-auth-and-provider-config-exclude-from-evidence",
}, ownership

bindings = {item["runtime"]: item for item in data["candidate_runtime_bindings"]}
assert set(bindings) == {"codex", "claude-code"}, bindings
assert len(data["candidate_runtime_bindings"]) == 2, data["candidate_runtime_bindings"]

codex = bindings["codex"]
assert codex["repository"] == "https://github.com/jiying2007/codex.git", codex
assert codex["target"] == "codex-cli", codex
assert codex["source_identity_mode"] == "exact-release-source-blobs", codex
assert codex["status"] == "source-set-bound", codex
assert codex["binding_commit"] == "1d77de27ef01d9be403ce0bd8ce50e2ece5d8967", codex

claude = bindings["claude-code"]
assert claude["repository"] == "https://github.com/jiying2007/claude.git", claude
assert claude["target"] == "claude-code", claude
assert claude["source_identity_mode"] == "exact-release-source-blobs", claude
assert claude["status"] == "source-set-bound", claude
assert claude["binding_commit"] == "cc3044eefd42d2f95f68d2ae85024845e9edcf63", claude
assert claude["r1_binding_conformance"] == "passed", claude
assert claude["verified_runtime_execution_receipt"] == "pending", claude
assert claude["r2_real_provider_substitution"] == "pending", claude

planes = data["execution_plane_evidence"]
for runtime, expected in {
    "codex": {
        "repository": "jiying2007/codex",
        "commit": codex["binding_commit"],
        "adapter": "scripts/runtime-r2-local.sh",
        "pr": "jiying2007/codex#21",
        "run": "jiying2007/codex/actions/runs/35518061439",
    },
    "claude-code": {
        "repository": "jiying2007/claude",
        "commit": claude["binding_commit"],
        "adapter": "control/scripts/runtime-r2-local.sh",
        "pr": "jiying2007/claude#12",
        "run": "jiying2007/claude/actions/runs/35563435255",
    },
}.items():
    plane = planes[runtime]
    assert plane["repository"] == expected["repository"], plane
    assert plane["execution_plane_commit"] == expected["commit"], plane
    assert plane["frozen_binding_commit"] == expected["commit"], plane
    assert plane["provider_execution_adapter"] == expected["adapter"], plane
    assert plane["execution_venue"] == "local-terminal", plane
    assert plane["runtime_home_mode"] == "shared-user-home", plane
    assert plane["credential_state_in_evidence"] is False, plane
    assert plane["credential_owner"] == "runtime-local-auth-state", plane
    assert plane["merged_pr"] == expected["pr"], plane
    assert plane["exact_head_contract_run"] == expected["run"], plane
    assert plane["real_provider_execution_receipt"] == "pending", plane
    assert "provider_execution_workflow" not in plane, plane

dw_plane = planes["digital-worker"]
assert dw_plane == {
    "repository": "jiying2007/digital-worker",
    "provider_credentials_held": False,
    "combined_provider_workflow_present": False,
    "freeze_workflow": ".github/workflows/runtime-r2-freeze.yml",
    "local_intake": "scripts/runtime_r2_intake.py",
    "local_verifier": "scripts/runtime_r2_local_verify.py",
    "verifier_identity_mode": "receipt-bound-tool-commit",
    "independent_review_workflow": ".github/workflows/runtime-r2-independent-review.yml",
}, dw_plane

ready_statuses = {"source-set-bound", "ready", "active"}
assert [name for name, item in bindings.items() if item["status"] in ready_statuses] == ["codex", "claude-code"], bindings
assert [name for name, item in bindings.items() if item["status"] == "binding-candidate-blocked"] == [], bindings

certifier_text = certifier_path.read_text(encoding="utf-8")
assert 'READY_BINDING_STATUSES = {"source-set-bound", "ready", "active"}' in certifier_text, certifier_text
assert "runtime_binding_commit does not match the frozen canonical binding" in certifier_text, certifier_text
assert "runtime local adapter must be part of the exact frozen binding identity" in certifier_text, certifier_text
assert "digital-worker verifier identity must be receipt-bound" in certifier_text, certifier_text
assert "verification_tool_commit" in certifier_text, certifier_text
assert "shared-user-home" in certifier_text, certifier_text
assert "credential state entered evidence" in certifier_text, certifier_text

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
    "provider_credentials_must_remain_runtime_owned",
    "digital_worker_must_not_hold_provider_credentials",
    "runtime_execution_must_be_separate_from_digital_worker_verification",
    "tracked_evidence_intake_is_not_real_provider_execution",
    "frozen_binding_identity_must_not_follow_execution_plane_head",
    "local_execution_receipt_is_not_domain_verification",
    "local_execution_evidence_intake_is_not_provider_execution",
    "verification_tool_identity_must_be_receipt_bound",
    "runtime_home_must_reuse_user_state",
    "credential_state_must_not_enter_evidence",
    "local_runtime_config_may_drift_outside_managed_identity",
):
    assert rules[key] is True, (key, data)
assert "attested_execution_receipt_is_not_domain_verification" not in rules

requirements = {item["id"]: item for item in lta["qualification_requirements"]}
lta02 = requirements["LTA-02"]
assert lta02["status"] == "evidence_collection_in_progress", lta02
assert lta02["implementation_status"] == "certifier-ready", lta02
assert lta02["required_healthy_runtime_bindings"] >= 2, lta02
assert lta02["required_evidence_level"] == "R2-real-provider-substitution", lta02
assert lta02["r1_binding_conformance_is_terminal_evidence"] is False, lta02
assert lta02["certifier"] == "tools.control_plane.runtime_portability", lta02
assert lta02["default_evidence_path"] == "reports/long-term-assets/runtime-portability-current.json", lta02
assert certifier_path.is_file()
assert '"runtime-portability": "tools.control_plane.runtime_portability"' in cli_path.read_text(encoding="utf-8")

text = path.read_text(encoding="utf-8")
for retired in (
    '"asset_bundle_identity"',
    '"adk_asset_bundle_hash"',
    '"missing_asset_bundle_identity_is_blocked_not_pass"',
    '"target_export_contract"',
    "BLOCKED_ASSET_BUNDLE_IDENTITY",
    "github-oidc-attested-runtime-owned-evidence",
    "runtime-r2-provider-execution.yml",
    "runtime-r2-domain-verification.yml",
):
    assert retired not in text, retired
PY

echo '[PASS] digital-worker runtime pilot enforces exact shared-user-home R2 adapters, local auth/config exclusion from evidence, receipt-bound DW verification, and R2-only terminal portability'
