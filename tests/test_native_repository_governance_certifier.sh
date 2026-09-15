#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

from tools.control_plane import cli
from tools.control_plane import native_repository_governance as governance

assert governance.CHECK_SCHEMA == "llm-agent-native-repository-governance-check/v2"
assert governance.VALID_SCOPES == ("full", "hosted-ruleset")
required = governance.DEFAULT_REQUIRED_CHECKS
assert required == (
    "contract",
    "doc-sync",
    "integration-impact",
    "integration-summary",
    "software-m5-certify",
    "branch-gc",
)

desired = governance.desired_ruleset_payload()
assert desired["name"] == "llm_agent main governance"
assert desired["enforcement"] == "active"
assert desired["bypass_actors"] == []
assert desired["conditions"]["ref_name"]["include"] == ["refs/heads/main"]
assert [rule["type"] for rule in desired["rules"]] == [
    "pull_request",
    "required_status_checks",
    "non_fast_forward",
    "deletion",
]
pull_request = desired["rules"][0]["parameters"]
assert pull_request["required_approving_review_count"] == 0
assert pull_request["allowed_merge_methods"] == ["squash"]
status_checks = desired["rules"][1]["parameters"]
assert status_checks["strict_required_status_checks_policy"] is True
assert [item["context"] for item in status_checks["required_status_checks"]] == list(required)

repository = {
    "full_name": "jiying2007/llm_agent",
    "default_branch": "main",
    "delete_branch_on_merge": True,
}
branch = {"name": "main", "protected": True}
ruleset = copy.deepcopy(desired)
ruleset["id"] = 50

passing = governance.evaluate_state(repository, branch, [ruleset], scope="full")
assert passing["status"] == "pass", passing
assert passing["scope"] == "full", passing
assert passing["implementation_status"] == "certifier-ready", passing
assert passing["repository_admin_settings_authoritative"] is True, passing
assert passing["full_compliant"] is True, passing
assert all(passing["checks"].values()), passing
assert passing["checks"] == passing["full_checks"], passing
assert passing["missing_status_checks"] == [], passing
assert passing["observed_required_approval_counts"] == [0], passing
assert passing["observed_strict_required_status_checks_policies"] == [True], passing
assert passing["desired_ruleset"] == desired, passing

# Hosted Actions tokens can under-report repository-admin settings. Hosted scope
# must certify only branch/ruleset facts it can authoritatively observe while full
# scope remains fail-closed on delete_branch_on_merge.
low_authority_repository = {**repository, "delete_branch_on_merge": False}
full_low_authority = governance.evaluate_state(
    low_authority_repository,
    branch,
    [ruleset],
    scope="full",
)
assert full_low_authority["status"] == "blocked_external_admin", full_low_authority
assert full_low_authority["checks"]["delete_branch_on_merge"] is False, full_low_authority
assert full_low_authority["repository_admin_settings_authoritative"] is True, full_low_authority
assert "native delete_branch_on_merge is not enabled" in full_low_authority["violations"], full_low_authority

hosted_low_authority = governance.evaluate_state(
    low_authority_repository,
    branch,
    [ruleset],
    scope="hosted-ruleset",
)
assert hosted_low_authority["status"] == "pass", hosted_low_authority
assert hosted_low_authority["scope"] == "hosted-ruleset", hosted_low_authority
assert hosted_low_authority["repository_admin_settings_authoritative"] is False, hosted_low_authority
assert hosted_low_authority["full_compliant"] is None, hosted_low_authority
assert hosted_low_authority["checks"] == hosted_low_authority["hosted_checks"], hosted_low_authority
assert "delete_branch_on_merge" not in hosted_low_authority["checks"], hosted_low_authority
assert hosted_low_authority["full_checks"]["delete_branch_on_merge"] is False, hosted_low_authority
assert "native delete_branch_on_merge is not enabled" not in hosted_low_authority["violations"], hosted_low_authority

empty = governance.evaluate_state(
    low_authority_repository,
    {"name": "main", "protected": False},
    [],
    scope="hosted-ruleset",
)
assert empty["status"] == "blocked_external_admin", empty
assert "no active native repository ruleset covers main" in empty["violations"], empty
assert empty["active_rulesets"] == [], empty
assert "native delete_branch_on_merge is not enabled" not in empty["violations"], empty

strict_false = copy.deepcopy(ruleset)
strict_false["rules"][1]["parameters"]["strict_required_status_checks_policy"] = False
result = governance.evaluate_state(repository, branch, [strict_false], scope="hosted-ruleset")
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["strict_required_status_checks"] is False, result
assert "required status checks do not require an up-to-date branch" in result["violations"], result

approval_drift = copy.deepcopy(ruleset)
approval_drift["rules"][0]["parameters"]["required_approving_review_count"] = 1
result = governance.evaluate_state(repository, branch, [approval_drift], scope="hosted-ruleset")
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["solo_zero_required_approvals"] is False, result
assert "native ruleset does not preserve zero required human approvals" in result["violations"], result

bypass_drift = copy.deepcopy(ruleset)
bypass_drift["bypass_actors"] = [{"actor_id": 1, "actor_type": "RepositoryRole", "bypass_mode": "always"}]
result = governance.evaluate_state(repository, branch, [bypass_drift], scope="hosted-ruleset")
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["no_ruleset_bypass"] is False, result
assert "native ruleset has a bypass actor" in result["violations"], result

missing_check = copy.deepcopy(ruleset)
missing_check["rules"][1]["parameters"]["required_status_checks"] = [
    item
    for item in missing_check["rules"][1]["parameters"]["required_status_checks"]
    if item["context"] != "branch-gc"
]
result = governance.evaluate_state(repository, branch, [missing_check], scope="hosted-ruleset")
assert result["status"] == "blocked_external_admin", result
assert result["missing_status_checks"] == ["branch-gc"], result
assert "required status checks missing: branch-gc" in result["violations"], result

irrelevant = copy.deepcopy(ruleset)
irrelevant["conditions"]["ref_name"]["include"] = ["refs/heads/release"]
result = governance.evaluate_state(repository, branch, [irrelevant], scope="hosted-ruleset")
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["active_main_ruleset"] is False, result

with tempfile.TemporaryDirectory() as temp_dir:
    temp = Path(temp_dir)
    passing_fixture = temp / "pass.json"
    passing_fixture.write_text(
        json.dumps({"repository": repository, "branch": branch, "rulesets": [ruleset]}),
        encoding="utf-8",
    )
    hosted_fixture = temp / "hosted.json"
    hosted_fixture.write_text(
        json.dumps({"repository": low_authority_repository, "branch": branch, "rulesets": [ruleset]}),
        encoding="utf-8",
    )
    blocked_fixture = temp / "blocked.json"
    blocked_fixture.write_text(
        json.dumps(
            {
                "repository": low_authority_repository,
                "branch": {"name": "main", "protected": False},
                "rulesets": [],
            }
        ),
        encoding="utf-8",
    )
    assert governance.main(["--fixture", str(passing_fixture), "--scope", "full", "--summary-json"]) == 0
    assert governance.main(["--fixture", str(hosted_fixture), "--scope", "full", "--summary-json"]) == 2
    assert governance.main(["--fixture", str(hosted_fixture), "--scope", "hosted-ruleset", "--summary-json"]) == 0
    assert governance.main(["--fixture", str(blocked_fixture), "--scope", "hosted-ruleset", "--summary-json"]) == 2

assert cli._COMMAND_MODULES["native-governance"] == "tools.control_plane.native_repository_governance"

workflow = Path(".github/workflows/native-governance-control-plane.yml").read_text(encoding="utf-8")
trigger_block = workflow.split("permissions:", 1)[0]
assert "workflow_dispatch:" in trigger_block
assert "issue_comment:" in trigger_block
assert "pull_request:" not in trigger_block
assert "push:" not in trigger_block
assert "github.event.issue.number == 50" in workflow
assert "github.event.comment.body == '/llm-agent-governance-verify'" in workflow
assert "github.event.comment.author_association == 'OWNER'" in workflow
assert "permissions:\n  contents: read\n" in workflow
assert "persist-credentials: false" in workflow
assert "native-governance" in workflow
assert "--scope hosted-ruleset" in workflow
assert "if: ${{ always() }}" in workflow
assert "if-no-files-found: error" in workflow

print("[PASS] LTA-01 native repository governance certifier authority scopes")
PY
