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
governance_path = root / "reports/long-term-assets/native-repository-governance-2026-09-15.json"
governance = json.loads(governance_path.read_text())

assert runbook.is_file()
runbook_text = runbook.read_text()
assert "clean-room recovery drill" in runbook_text.lower()
assert "issue #50" in runbook_text
assert "second-human approval" in runbook_text.lower()
assert "reports/long-term-assets/" in runbook_text

assert lta["schema"] == "llm-agent-long-term-asset-qualification/v1"
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
assert requirements["LTA-01"]["status"] == "blocked_external_admin"
assert requirements["LTA-01"]["remaining_admin_blocker"] == "native-main-ruleset-only"
assert requirements["LTA-01"]["evidence"][0] == governance_path.as_posix()
assert set(requirements["LTA-01"]["completed_subrequirements"]) == {
    "delete_branch_on_merge=true",
    "merged PR branch deletion observed before custom GC deletion",
}
assert requirements["LTA-02"]["status"] == "blocked_external_evidence"
assert requirements["LTA-02"]["required_healthy_runtime_bindings"] >= 2
assert requirements["LTA-03"]["status"] == "pass"
assert requirements["LTA-03"]["evidence"] == [recovery_path.as_posix()]
assert requirements["LTA-04"]["status"] == "blocked_time_evidence"

assert governance["schema"] == "llm-agent-native-repository-governance-evidence/v1"
assert governance["status"] == "partial"
assert governance["qualification"] == "LTA-01"
assert governance["repository"] == "jiying2007/llm_agent"
assert governance["repository_metadata"]["default_branch"] == "main"
assert governance["repository_metadata"]["delete_branch_on_merge"] is True
assert governance["native_branch_deletion_proof"]["pull_request"] == 55
assert governance["native_branch_deletion_proof"]["merged_branch_absent_after_merge"] is True
assert governance["native_branch_deletion_proof"]["custom_branch_gc_run_id"] == 34954493446
assert governance["native_branch_deletion_proof"]["custom_branch_gc_conclusion"] == "success"
assert governance["native_branch_deletion_proof"]["custom_branch_gc_candidates"] == 0
assert governance["native_branch_deletion_proof"]["custom_branch_gc_deleted"] == 0
assert governance["native_ruleset"]["observed_ruleset_count"] == 0
assert governance["native_ruleset"]["main_ruleset_observed"] is False
assert governance["native_ruleset"]["collection"] == []
assert governance["remaining_blocker"] == "native-main-ruleset-only"

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
assert set(terminal["blockers"]) == expected_blockers == {"LTA-01", "LTA-02", "LTA-04"}

assert scorecard["overall"]["terminal_mature"] is True
assert scorecard["overall"]["terminal_scope"] == "product_maturity_v5"
assert scorecard["overall"]["long_term_asset_status"] == "blocked"
assert scorecard["overall"]["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert scorecard["software_m5"]["certified"] is True
assert "second_human_operator_review" not in scorecard["software_m5"]["advisory_followups"]
assert "solo_maintainer_recovery_drill" not in scorecard["software_m5"]["advisory_followups"]
assert policy["operational_advisories"]["second_human_operator"] is False

assert tasks["rules"]["product_m5_does_not_imply_long_term_asset_terminal"] is True
assert tasks["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert not any("second human" in item.lower() for item in tasks["operational_followups"])
assert not any("clean-room recovery" in item.lower() for item in tasks["operational_followups"])
assert any("issue #50" in item for item in tasks["operational_followups"])

pm = {item["id"]: item for item in tasks["tasks"]}
assert pm["PM-10"]["status"] == "implemented"
assert pm["PM-14"]["status"] == "not_required"
assert "long-term" in pm["PM-14"]["acceptance"]

print("long-term asset qualification contract: PASS")
PY
