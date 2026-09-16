#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import copy
import json
from pathlib import Path

from tools.control_plane import native_repository_governance as governance
from tools.control_plane import native_repository_governance_admin as admin

repository = {
    "full_name": "jiying2007/llm_agent",
    "default_branch": "main",
    "delete_branch_on_merge": True,
}
branch = {
    "name": "main",
    "protected": True,
    "commit": {"sha": "a" * 40},
}
desired = governance.desired_ruleset_payload()
managed = copy.deepcopy(desired)
managed["id"] = 50

plan = admin.build_plan(
    repository,
    branch,
    [],
    branch="main",
    ruleset_name=governance.DEFAULT_RULESET_NAME,
)
assert plan["schema"] == admin.RECEIPT_SCHEMA
assert plan["mode"] == "plan"
assert plan["ruleset"]["action"] == "create", plan
assert plan["ruleset"]["desired"] == desired
assert plan["repository_prerequisites"] == {"delete_branch_on_merge": True}

same = admin.build_plan(
    repository,
    branch,
    [managed],
    branch="main",
    ruleset_name=governance.DEFAULT_RULESET_NAME,
)
assert same["ruleset"]["action"] == "none", same
assert same["ruleset"]["id"] == 50

stale = copy.deepcopy(managed)
stale["rules"][1]["parameters"]["strict_required_status_checks_policy"] = False
update = admin.build_plan(
    repository,
    branch,
    [stale],
    branch="main",
    ruleset_name=governance.DEFAULT_RULESET_NAME,
)
assert update["ruleset"]["action"] == "update", update
assert update["ruleset"]["id"] == 50

try:
    admin.build_plan(
        {**repository, "delete_branch_on_merge": False},
        branch,
        [],
        branch="main",
        ruleset_name=governance.DEFAULT_RULESET_NAME,
    )
except admin.AdminError as exc:
    assert "delete_branch_on_merge=true" in str(exc)
else:
    raise AssertionError("full-scope repository prerequisite drift must fail closed")

checkout = admin.validate_local_checkout(
    "jiying2007/llm_agent",
    "main",
    branch,
    {
        "branch": "main",
        "head_sha": "a" * 40,
        "status": "",
        "origin": "git@github.com:jiying2007/llm_agent.git",
    },
)
assert checkout["worktree_clean"] is True
assert checkout["repository"] == "jiying2007/llm_agent"

for bad in (
    {"branch": "dev", "head_sha": "a" * 40, "status": "", "origin": "git@github.com:jiying2007/llm_agent.git"},
    {"branch": "main", "head_sha": "b" * 40, "status": "", "origin": "git@github.com:jiying2007/llm_agent.git"},
    {"branch": "main", "head_sha": "a" * 40, "status": " M x", "origin": "git@github.com:jiying2007/llm_agent.git"},
    {"branch": "main", "head_sha": "a" * 40, "status": "", "origin": "git@github.com:jiying2007/other.git"},
):
    try:
        admin.validate_local_checkout("jiying2007/llm_agent", "main", branch, bad)
    except admin.AdminError:
        pass
    else:
        raise AssertionError(f"unsafe checkout fixture unexpectedly passed: {bad}")


class FakeClient:
    def __init__(self) -> None:
        self.calls = []
        self.next_id = 71

    def request(self, method, path, payload=None):
        self.calls.append((method, path, payload))
        if method == "POST":
            return {"id": self.next_id}
        return {"id": 50}


client = FakeClient()
ops = admin.apply_plan(client, "jiying2007/llm_agent", plan)
assert ops == [{"operation": "create_ruleset", "id": 71}]
assert client.calls[0][0:2] == ("POST", "/repos/jiying2007/llm_agent/rulesets")

client = FakeClient()
ops = admin.apply_plan(client, "jiying2007/llm_agent", update)
assert ops == [{"operation": "update_ruleset", "id": 50}]
assert client.calls[0][0:2] == ("PUT", "/repos/jiying2007/llm_agent/rulesets/50")

client = FakeClient()
ops = admin.apply_plan(client, "jiying2007/llm_agent", same)
assert ops == []
assert client.calls == []

post_apply = governance.evaluate_state(
    repository,
    branch,
    [managed],
    scope="full",
)
assert post_apply["status"] == "pass", post_apply
assert admin.TOKEN_ENV == "ADK_GITHUB_ADMIN_TOKEN"

source = Path("tools/control_plane/native_repository_governance_admin.py").read_text(encoding="utf-8")
assert "--apply refuses to run inside GitHub Actions" in source
assert "Administration read/write is required" in source
assert 'scope="full"' in source
assert "delete_branch_on_merge=true" in source
assert 'TOKEN_ENV = "ADK_GITHUB_ADMIN_TOKEN"' in source
assert "LLM_AGENT_GITHUB_ADMIN_TOKEN" not in source

lta = json.loads(Path("manifests/long_term_asset_qualification.json").read_text(encoding="utf-8"))
lta01 = {item["id"]: item for item in lta["blocking_requirements"]}["LTA-01"]
assert lta01["status"] == "pass"
assert lta01["implementation_status"] == "verified"
assert "remaining_admin_blocker" not in lta01
assert lta01["ruleset_id"] == 23516987
assert "native-governance-admin" in lta01["admin_apply_command"]
assert "--apply" in lta01["admin_apply_command"]
assert lta01["admin_token_env"] == admin.TOKEN_ENV == "ADK_GITHUB_ADMIN_TOKEN"
assert "LLM_AGENT_GITHUB_ADMIN_TOKEN" not in json.dumps(lta01, sort_keys=True)
assert lta01["admin_apply_environment"] == "trusted-local-clean-main-only"
assert "reports/long-term-assets/native-repository-governance-admin-apply.json" in lta01["evidence"]
assert "reports/long-term-assets/native-repository-governance-hosted-2026-09-16.json" in lta01["evidence"]

print("[PASS] local LTA-01 governance admin planner/apply is fail-closed, manifest-bound, shared-token-only, and evidence-ratcheted")
PY
