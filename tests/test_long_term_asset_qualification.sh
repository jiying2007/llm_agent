#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
from pathlib import Path

root = Path(".")
lta = json.loads((root / "manifests/long_term_asset_qualification.json").read_text())
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text())
tasks = json.loads((root / "manifests/product_maturity_task_pack.json").read_text())
lock = json.loads((root / "manifests/adk_interface.lock.json").read_text())

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
assert requirements["LTA-02"]["status"] == "blocked_external_evidence"
assert requirements["LTA-02"]["required_healthy_runtime_bindings"] >= 2
assert requirements["LTA-03"]["status"] == "blocked_evidence"
assert requirements["LTA-04"]["status"] == "blocked_time_evidence"

terminal = lta["terminal"]
assert terminal["qualified"] is False
assert terminal["status"] == "blocked"
assert set(terminal["blockers"]) == set(requirements)

assert scorecard["overall"]["terminal_mature"] is True
assert scorecard["overall"]["terminal_scope"] == "product_maturity_v5"
assert scorecard["overall"]["long_term_asset_status"] == "blocked"
assert scorecard["overall"]["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert scorecard["software_m5"]["certified"] is True
assert "second_human_operator_review" not in scorecard["software_m5"]["advisory_followups"]

assert tasks["rules"]["product_m5_does_not_imply_long_term_asset_terminal"] is True
assert tasks["long_term_asset_contract"] == "manifests/long_term_asset_qualification.json"
assert not any("second human" in item.lower() for item in tasks["operational_followups"])
assert any("solo-maintainer" in item for item in tasks["operational_followups"])
assert any("issue #50" in item for item in tasks["operational_followups"])

pm = {item["id"]: item for item in tasks["tasks"]}
assert pm["PM-10"]["status"] == "implemented"
assert pm["PM-14"]["status"] == "not_required"
assert "long-term" in pm["PM-14"]["acceptance"]

print("long-term asset qualification contract: PASS")
PY
