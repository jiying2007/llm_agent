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

passing = governance.evaluate_state(repository, branch, [ruleset])
assert passing["status"] == "pass", passing
assert passing["implementation_status"] == "certifier-ready", passing
assert all(passing["checks"].values()), passing
assert passing["missing_status_checks"] == [], passing
assert passing["observed_required_approval_counts"] == [0], passing
assert passing["observed_strict_required_status_checks_policies"] == [True], passing
assert passing["desired_ruleset"] == desired, passing

empty = governance.evaluate_state(repository, {"name": "main", "protected": False}, [])
assert empty["status"] == "blocked_external_admin", empty
assert "no active native repository ruleset covers main" in empty["violations"], empty
assert empty["active_rulesets"] == [], empty

strict_false = copy.deepcopy(ruleset)
strict_false["rules"][1]["parameters"]["strict_required_status_checks_policy"] = False
result = governance.evaluate_state(repository, branch, [strict_false])
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["strict_required_status_checks"] is False, result
assert "required status checks do not require an up-to-date branch" in result["violations"], result

approval_drift = copy.deepcopy(ruleset)
approval_drift["rules"][0]["parameters"]["required_approving_review_count"] = 1
result = governance.evaluate_state(repository, branch, [approval_drift])
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["solo_zero_required_approvals"] is False, result
assert "native ruleset does not preserve zero required human approvals" in result["violations"], result

bypass_drift = copy.deepcopy(ruleset)
bypass_drift["bypass_actors"] = [{"actor_id": 1, "actor_type": "RepositoryRole", "bypass_mode": "always"}]
result = governance.evaluate_state(repository, branch, [bypass_drift])
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["no_ruleset_bypass"] is False, result
assert "native ruleset has a bypass actor" in result["violations"], result

missing_check = copy.deepcopy(ruleset)
missing_check["rules"][1]["parameters"]["required_status_checks"] = [
    item
    for item in missing_check["rules"][1]["parameters"]["required_status_checks"]
    if item["context"] != "branch-gc"
]
result = governance.evaluate_state(repository, branch, [missing_check])
assert result["status"] == "blocked_external_admin", result
assert result["missing_status_checks"] == ["branch-gc"], result
assert "required status checks missing: branch-gc" in result["violations"], result

no_native_cleanup = governance.evaluate_state(
    {**repository, "delete_branch_on_merge": False},
    branch,
    [ruleset],
)
assert no_native_cleanup["status"] == "blocked_external_admin", no_native_cleanup
assert no_native_cleanup["checks"]["delete_branch_on_merge"] is False, no_native_cleanup

irrelevant = copy.deepcopy(ruleset)
irrelevant["conditions"]["ref_name"]["include"] = ["refs/heads/release"]
result = governance.evaluate_state(repository, branch, [irrelevant])
assert result["status"] == "blocked_external_admin", result
assert result["checks"]["active_main_ruleset"] is False, result

with tempfile.TemporaryDirectory() as temp_dir:
    temp = Path(temp_dir)
    passing_fixture = temp / "pass.json"
    passing_fixture.write_text(
        json.dumps({"repository": repository, "branch": branch, "rulesets": [ruleset]}),
        encoding="utf-8",
    )
    blocked_fixture = temp / "blocked.json"
    blocked_fixture.write_text(
        json.dumps(
            {
                "repository": repository,
                "branch": {"name": "main", "protected": False},
                "rulesets": [],
            }
        ),
        encoding="utf-8",
    )
    assert governance.main(["--fixture", str(passing_fixture), "--summary-json"]) == 0
    assert governance.main(["--fixture", str(blocked_fixture), "--summary-json"]) == 2

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
assert "if: ${{ always() }}" in workflow
assert "if-no-files-found: error" in workflow

print("[PASS] LTA-01 native repository governance certifier")
PY
