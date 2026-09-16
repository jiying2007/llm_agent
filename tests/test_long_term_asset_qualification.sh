#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import re
from pathlib import Path

root = Path(".")
lta = json.loads((root / "manifests/long_term_asset_qualification.json").read_text())
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text())
tasks = json.loads((root / "manifests/product_maturity_task_pack.json").read_text())
policy = json.loads((root / "manifests/software_m5_policy.json").read_text())
lock = json.loads((root / "manifests/adk_interface.lock.json").read_text())
runbook = root / "docs/runbooks/solo-maintainer-continuity.md"
recovery_path = root / "reports/long-term-assets/solo-maintainer-recovery-2026-09-15.json"
recovery = json.loads(recovery_path.read_text())
historical_governance_path = root / "reports/long-term-assets/native-repository-governance-2026-09-15.json"
admin_apply_path = root / "reports/long-term-assets/native-repository-governance-admin-apply.json"
hosted_governance_path = root / "reports/long-term-assets/native-repository-governance-hosted-2026-09-16.json"
admin_apply = json.loads(admin_apply_path.read_text())
hosted_governance = json.loads(hosted_governance_path.read_text())
branch_gc_source = (root / "tools/control_plane/branch_gc.py").read_text()
branch_gc_workflow = (root / ".github/workflows/branch-gc.yml").read_text()

assert runbook.is_file()
runbook_text = runbook.read_text()
assert "clean-room recovery drill" in runbook_text.lower()
assert "issue #50" in runbook_text
assert "second-human approval" in runbook_text.lower()
assert "reports/long-term-assets/" in runbook_text

assert lta["schema"] == "llm-agent-long-term-asset-qualification/v1"
assert lta["updated_at"] == "2026-09-16"
assert lta["rules"]["fail_closed"] is True
assert lta["rules"]["no_simulated_external_evidence"] is True
assert lta["rules"]["product_maturity_does_not_imply_long_term_terminal"] is True

maintainer = lta["maintainer_model"]
assert maintainer["type"] == "solo"
assert maintainer["required_human_approvals"] == 0
assert maintainer["minimum_codeowners"] == 1
assert maintainer["human_redundancy_required"] is False
required_controls = {
    "pull-request-mediated-main-changes",
    "mandatory-automated-regression-and-security-gates",
    "fail-closed-machine-readable-evidence",
    "exact-source-and-release-identity",
    "immutable-signed-component-release",
    "clean-room-recovery-and-rollback-drill",
    "explicit-continuity-runbook",
}
assert required_controls <= set(maintainer["compensating_controls"])

assert lta["lifecycle"]["llm_agent"]["model"] == "non-release-workspace"
assert lta["lifecycle"]["llm_agent"]["component_release_required"] is False
assert lta["lifecycle"]["agent_dev_kit"]["model"] == "versioned-component"
assert lta["lifecycle"]["agent_dev_kit"]["component_release_required"] is True
assert lta["lifecycle"]["agent_dev_kit"]["current_release"] == "5.1.0"
assert lock["version"] == "5.1.0"

layers = {item["id"]: item for item in lta["qualification_layers"]}
assert layers["source-valid"]["status"] == "pass"
assert layers["release-qualified"]["status"] == "pass"
assert layers["product-qualified"]["status"] == "pass"
assert layers["runtime-conformant"]["status"] == "partial"
assert layers["long-term-asset-qualified"]["status"] == "blocked"

requirements = {item["id"]: item for item in lta["blocking_requirements"]}
assert set(requirements) == {"LTA-01", "LTA-02", "LTA-03", "LTA-04"}

lta01 = requirements["LTA-01"]
assert lta01["status"] == "pass"
assert lta01["implementation_status"] == "verified"
assert "remaining_admin_blocker" not in lta01
assert lta01["certifier"] == "tools.control_plane.native_repository_governance"
assert "native-governance" in lta01["certifier_command"]
assert lta01["admin_token_env"] == "ADK_GITHUB_ADMIN_TOKEN"
assert lta01["admin_apply_environment"] == "trusted-local-clean-main-only"
assert lta01["hosted_verifier_workflow"] == ".github/workflows/native-governance-control-plane.yml"
assert (root / lta01["hosted_verifier_workflow"]).is_file()
assert lta01["required_status_checks"] == [
    "contract",
    "doc-sync",
    "integration-impact",
    "integration-summary",
    "software-m5-certify",
    "branch-gc",
]
assert "strict/up-to-date" in lta01["acceptance"]
assert "zero-approval" in lta01["acceptance"]
assert "explicit exact-SHA" in lta01["acceptance"]
assert lta01["verified_main_commit"] == "73d4493a85839ff4e0c9351050148495f932d9ce"
assert lta01["ruleset_id"] == 23516987
assert lta01["workflow_run_id"] == 35043919633
assert lta01["workflow_job_id"] == 104629540397
assert lta01["artifact_id"] == 10425933771
assert lta01["artifact_sha256"] == "29b7d1c1f9b36aeeb6d7a2cd3790c092947f8aa30511a90340d3cb2673dd1271"
assert admin_apply_path.as_posix() in lta01["evidence"]
assert hosted_governance_path.as_posix() in lta01["evidence"]
assert historical_governance_path.as_posix() in lta01["evidence"]
assert "generic merged-PR custom GC responsibility retired" in lta01["completed_subrequirements"]

assert admin_apply["schema"] == "llm-agent-native-repository-governance-admin/v1"
assert admin_apply["mode"] == "apply"
assert admin_apply["repository"] == "jiying2007/llm_agent"
assert admin_apply["branch"] == "main"
assert admin_apply["checkout"]["branch"] == "main"
assert admin_apply["checkout"]["head_sha"] == lta01["verified_main_commit"]
assert admin_apply["checkout"]["remote_branch_sha"] == lta01["verified_main_commit"]
assert admin_apply["checkout"]["repository"] == "jiying2007/llm_agent"
assert admin_apply["checkout"]["worktree_clean"] is True
assert admin_apply["operations"] == [{"id": lta01["ruleset_id"], "operation": "create_ruleset"}]
full = admin_apply["verification"]
assert full["scope"] == "full"
assert full["status"] == "pass"
assert full["full_compliant"] is True
assert full["repository_admin_settings_authoritative"] is True
assert full["missing_status_checks"] == []
assert full["violations"] == []
assert full["observed_required_approval_counts"] == [0]
assert full["observed_pull_request_merge_methods"] == [["squash"]]
assert full["observed_strict_required_status_checks_policies"] == [True]
assert set(full["observed_status_checks"]) == set(lta01["required_status_checks"])
assert all(full["checks"].values())

assert hosted_governance["schema"] == "llm-agent-native-repository-governance-hosted-evidence/v1"
assert hosted_governance["status"] == "pass"
assert hosted_governance["qualification"] == "LTA-01"
assert hosted_governance["repository"] == "jiying2007/llm_agent"
assert hosted_governance["branch"] == "main"
assert hosted_governance["reference_sha"] == lta01["verified_main_commit"]
assert hosted_governance["ruleset"]["id"] == lta01["ruleset_id"]
assert hosted_governance["ruleset"]["bypass_actors"] == []
assert hosted_governance["ruleset"]["required_approving_review_count"] == 0
assert hosted_governance["ruleset"]["allowed_merge_methods"] == ["squash"]
assert hosted_governance["ruleset"]["strict_required_status_checks_policy"] is True
assert hosted_governance["ruleset"]["required_status_checks"] == lta01["required_status_checks"]
assert hosted_governance["ruleset"]["non_fast_forward_blocked"] is True
assert hosted_governance["ruleset"]["branch_deletion_blocked"] is True
assert all(hosted_governance["checks"].values())
assert hosted_governance["missing_status_checks"] == []
assert hosted_governance["violations"] == []
assert hosted_governance["workflow"] == {
    "run_id": lta01["workflow_run_id"],
    "job_id": lta01["workflow_job_id"],
    "event": "issue_comment",
    "conclusion": "success",
}
assert hosted_governance["artifact"]["id"] == lta01["artifact_id"]
assert hosted_governance["artifact"]["sha256"] == lta01["artifact_sha256"]
assert hosted_governance["artifact"]["size_bytes"] == 1088
assert hosted_governance["artifact"]["retention_days"] == 90

assert "exact-merged-pr" not in branch_gc_source
assert "def exact_merged_pr" not in branch_gc_source
assert '"candidate_policy": "explicit-retirement-only"' in branch_gc_source
assert "explicit-retired-" in branch_gc_source
assert "manifests/branch_gc_retired.json" in branch_gc_workflow
assert "merged_pr" not in branch_gc_workflow

lta02 = requirements["LTA-02"]
assert lta02["status"] == "blocked_external_evidence"
assert lta02["implementation_status"] == "certifier-ready"
assert lta02["required_healthy_runtime_bindings"] >= 2
assert lta02["required_evidence_level"] == "R2-real-provider-substitution"
assert lta02["r1_binding_conformance_is_terminal_evidence"] is False
assert lta02["certifier"] == "tools.control_plane.runtime_portability"
assert "runtime-portability" in lta02["certifier_command"]
assert lta02["default_evidence_path"] == "reports/long-term-assets/runtime-portability-current.json"
assert lta02["remaining_external_blocker"] == "second-real-runtime-provider-binding-and-R2-comparison-evidence"
assert "R2 only" in lta02["acceptance"]
assert "Fake or controlled alternate bindings" in lta02["acceptance"]

assert requirements["LTA-03"]["status"] == "pass"
assert requirements["LTA-03"]["evidence"] == [recovery_path.as_posix()]

lta04 = requirements["LTA-04"]
assert lta04["status"] == "blocked_time_evidence"
assert lta04["implementation_status"] == "certifier-ready"
assert lta04["pilot_id"] == "software-m5-v5-independent-pilot-20260912"
assert lta04["repository_id"] == "digital-worker"
assert lta04["minimum_calendar_days"] == 30
assert lta04["certifier"] == "tools.control_plane.longitudinal_operation"
assert "longitudinal-operation" in lta04["certifier_command"]
assert lta04["default_evidence_path"] == "reports/long-term-assets/longitudinal-operation-current.json"
assert lta04["remaining_external_blocker"] == "observation-window-and-real-summary-evidence"
assert lta04["evidence"] == [
    "manifests/software_m5_pilot_ledger.json",
    "reports/field-evidence/software-m5-v5-events.jsonl",
]

assert recovery["schema"] == "llm-agent-solo-recovery-evidence/v1"
assert recovery["status"] == "pass"
assert recovery["qualification"] == "LTA-03"
assert recovery["source"]["agent_dev_kit_version"] == lock["version"]
assert recovery["source"]["agent_dev_kit_commit"] == lock["commit"]
assert recovery["source"]["agent_dev_kit_tree"] == lock["tree"]
assert recovery["source"]["lock_identity_match"] is True
assert recovery["source"]["llm_agent_commit"] == requirements["LTA-03"]["verified_main_commit"]
assert recovery["workflow"]["run_id"] == requirements["LTA-03"]["workflow_run_id"]
assert recovery["workflow"]["event"] == "push"
assert recovery["workflow"]["branch"] == "main"
assert recovery["workflow"]["head_sha"] == recovery["source"]["llm_agent_commit"]
assert recovery["workflow"]["conclusion"] == "success"
assert re.fullmatch(r"[0-9a-f]{64}", recovery["artifact"]["sha256"])
assert recovery["artifact"]["sha256"] == requirements["LTA-03"]["artifact_sha256"]
receipt = recovery["receipt"]
assert receipt["schema"] == "llm-agent-solo-recovery-receipt/v1"
assert receipt["status"] == "pass"
assert receipt["environment"]["github_sha"] == recovery["source"]["llm_agent_commit"]
assert receipt["drill"]["fresh_dependency_materialization"] is True
assert receipt["drill"]["isolated_virtual_environment"] is True
assert receipt["drill"]["isolated_target"] is True
assert receipt["drill"]["release_surface_compatible"] is True
assert receipt["drill"]["full_release_governance_reclassified"] is False
assert receipt["drill"]["runtime_invoked"] is False
assert receipt["drill"]["replace_managed_apply"] == "pass"
assert receipt["drill"]["previous_receipt_restore"] == "pass"
assert receipt["drill"]["restored_asset_digest_check"] == "pass"
assert receipt["drill"]["final_rollback"] == "pass"
assert receipt["drill"]["final_target_managed_assets_absent"] is True

for requirement in requirements.values():
    for evidence in requirement.get("evidence", []):
        if evidence.startswith("https://"):
            continue
        assert (root / evidence).exists(), (requirement["id"], evidence)

terminal = lta["terminal"]
assert terminal["qualified"] is False
assert terminal["status"] == "blocked"
expected_blockers = {item["id"] for item in requirements.values() if item["status"] != "pass"}
assert set(terminal["blockers"]) == expected_blockers == {"LTA-02", "LTA-04"}

assert scorecard["overall"]["terminal_mature"] is True
assert scorecard["overall"]["terminal_scope"] == "product_maturity_v5"
assert scorecard["overall"]["long_term_asset_status"] == "blocked"
assert scorecard["overall"]["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert scorecard["software_m5"]["certified"] is True
assert "second_human_operator_review" not in scorecard["software_m5"]["advisory_followups"]
assert "solo_maintainer_recovery_drill" not in scorecard["software_m5"]["advisory_followups"]
assert "native_repository_governance" not in scorecard["software_m5"]["advisory_followups"]
assert policy["operational_advisories"]["second_human_operator"] is False
assert policy["operational_advisories"]["recommended_observation_days"] >= 30

assert tasks["rules"]["product_m5_does_not_imply_long_term_asset_terminal"] is True
assert tasks["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert not any("second human" in item.lower() for item in tasks["operational_followups"])
assert not any("clean-room recovery" in item.lower() for item in tasks["operational_followups"])
assert not any("issue #50" in item for item in tasks["operational_followups"])
assert not any("native repository governance" in item.lower() for item in tasks["operational_followups"])

pm = {item["id"]: item for item in tasks["tasks"]}
assert pm["PM-10"]["status"] == "implemented"
assert pm["PM-14"]["status"] == "not_required"
assert "long-term" in pm["PM-14"]["acceptance"]

print("long-term asset qualification contract: PASS")
PY
