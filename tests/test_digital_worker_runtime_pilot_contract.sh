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

ownership = data["execution_ownership"]
assert ownership == {
    "model": "runtime-owned-provider-execution+digital-worker-verifier-only",
    "provider_credentials_owner": "runtime-binding-repository",
    "provider_execution_authority_owner": "runtime-binding-repository",
    "digital_worker_holds_provider_credentials": False,
    "runtime_execution_evidence_transport": "github-oidc-attested-runtime-owned-evidence",
    "digital_worker_verifies_execution_provenance": True,
    "digital_worker_projects_native_receipts": True,
    "digital_worker_domain_verification_is_separate": True,
    "independent_review_must_be_distinct_from_all_runtime_executors_and_verifier": True,
    "attested_execution_receipt_is_not_r2_pass": True,
}, ownership

bindings = {item["runtime"]: item for item in data["candidate_runtime_bindings"]}
assert set(bindings) == {"codex", "claude-code"}, bindings
assert len(data["candidate_runtime_bindings"]) == 2, data["candidate_runtime_bindings"]

codex = bindings["codex"]
assert codex["repository"] == "https://github.com/jiying2007/codex.git", codex
assert codex["target"] == "codex-cli", codex
assert codex["source_identity_mode"] == "exact-release-source-blobs", codex
assert codex["status"] == "source-set-bound", codex
assert codex["binding_commit"] == "79acb193cef381b4c8b72f00e0af15f87e32765c", codex

claude = bindings["claude-code"]
assert claude["repository"] == "https://github.com/jiying2007/claude.git", claude
assert claude["target"] == "claude-code", claude
assert claude["source_identity_mode"] == "exact-release-source-blobs", claude
assert claude["status"] == "source-set-bound", claude
assert claude["merged_pr"] == "jiying2007/claude#5", claude
assert claude["binding_commit"] == "fba4551aa4a2abe5f74cff3c60e8318961b36add", claude
assert claude["exact_head_workflow_run"] == "jiying2007/claude/actions/runs/35477726658", claude
assert claude["fresh_main_workflow_run"] == "jiying2007/claude/actions/runs/35477771868", claude
assert claude["r1_binding_conformance"] == "passed", claude
assert claude["verified_runtime_execution_receipt"] == "pending", claude
assert claude["r2_real_provider_substitution"] == "pending", claude

planes = data["execution_plane_evidence"]
codex_plane = planes["codex"]
assert codex_plane["repository"] == "jiying2007/codex", codex_plane
assert codex_plane["execution_plane_commit"] == "fa4f050bf03050bac3e10190952ccb8c6dde0882", codex_plane
assert codex_plane["frozen_binding_commit"] == codex["binding_commit"], codex_plane
assert codex_plane["credential_owner"] == "jiying2007/codex", codex_plane
assert codex_plane["merged_pr"] == "jiying2007/codex#16", codex_plane
assert codex_plane["exact_head_contract_run"] == "jiying2007/codex/actions/runs/35479144672", codex_plane
assert codex_plane["fresh_main_contract_run"] == "jiying2007/codex/actions/runs/35479163874", codex_plane
assert codex_plane["real_provider_execution_receipt"] == "pending", codex_plane

claude_plane = planes["claude-code"]
assert claude_plane["repository"] == "jiying2007/claude", claude_plane
assert claude_plane["execution_plane_commit"] == "b8dc8b9b33084ed619c7b398f33e8c826e7b4185", claude_plane
assert claude_plane["frozen_binding_commit"] == claude["binding_commit"], claude_plane
assert claude_plane["credential_owner"] == "jiying2007/claude", claude_plane
assert claude_plane["merged_pr"] == "jiying2007/claude#6", claude_plane
assert claude_plane["exact_head_contract_run"] == "jiying2007/claude/actions/runs/35477834233", claude_plane
assert claude_plane["fresh_main_contract_run"] == "jiying2007/claude/actions/runs/35477851200", claude_plane
assert claude_plane["real_provider_execution_receipt"] == "pending", claude_plane

dw_plane = planes["digital-worker"]
assert dw_plane["repository"] == "jiying2007/digital-worker", dw_plane
assert dw_plane["verifier_only_commit"] == "b92c81d6733468709737e11ae5a6336cb06001fc", dw_plane
assert dw_plane["merged_pr"] == "jiying2007/digital-worker#118", dw_plane
assert dw_plane["provider_credentials_held"] is False, dw_plane
assert dw_plane["combined_provider_workflow_present"] is False, dw_plane
assert dw_plane["freeze_workflow"] == ".github/workflows/runtime-r2-freeze.yml", dw_plane
assert dw_plane["domain_verification_workflow"] == ".github/workflows/runtime-r2-domain-verification.yml", dw_plane
assert dw_plane["independent_review_workflow"] == ".github/workflows/runtime-r2-independent-review.yml", dw_plane
assert dw_plane["fresh_main_runs"] == {
    "runtime_r2_harness": "jiying2007/digital-worker/actions/runs/35201429559",
    "terminal_consistency": "jiying2007/digital-worker/actions/runs/35201429455",
    "embedded_expert_contracts": "jiying2007/digital-worker/actions/runs/35201429384",
}, dw_plane

# The active contract is closed over exactly the declared two-runtime set.
# Both frozen runtime source sets remain R1-bound while the execution planes may advance independently.
ready_statuses = {"source-set-bound", "ready", "active"}
assert [name for name, item in bindings.items() if item["status"] in ready_statuses] == ["codex", "claude-code"], bindings
assert [name for name, item in bindings.items() if item["status"] == "binding-candidate-blocked"] == [], bindings
certifier_text = certifier_path.read_text(encoding="utf-8")
assert 'READY_BINDING_STATUSES = {"source-set-bound", "ready", "active"}' in certifier_text, certifier_text
assert "runtime_binding_commit does not match the frozen canonical binding" in certifier_text, certifier_text
assert "runtime pilot execution ownership drift" in certifier_text, certifier_text

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
    "attested_execution_receipt_is_not_domain_verification",
    "tracked_evidence_intake_is_not_real_provider_execution",
    "frozen_binding_identity_must_not_follow_execution_plane_head",
):
    assert rules[key] is True, (key, data)

requirements = {item["id"]: item for item in lta["qualification_requirements"]}
lta02 = requirements["LTA-02"]
assert lta02["status"] == "evidence_collection_in_progress", lta02
assert lta02["implementation_status"] == "certifier-ready", lta02
assert lta02["required_healthy_runtime_bindings"] >= 2, lta02
assert lta02["required_evidence_level"] == "R2-real-provider-substitution", lta02
assert lta02["r1_binding_conformance_is_terminal_evidence"] is False, lta02
assert lta02["certifier"] == "tools.control_plane.runtime_portability", lta02
assert lta02["default_evidence_path"] == "reports/long-term-assets/runtime-portability-current.json", lta02
assert lta02["pending_evidence"] == "real-claude-runtime-execution-receipt-and-same-frozen-task-R2-comparison-evidence", lta02
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

echo '[PASS] digital-worker runtime pilot enforces runtime-owned R2 execution, verifier-only DW, exact frozen bindings, and R2-only terminal portability'
