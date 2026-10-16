#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from pathlib import Path

from tools.control_plane import branch_gc

source = Path("tools/control_plane/branch_gc.py").read_text(encoding="utf-8")
workflow = Path(".github/workflows/branch-gc.yml").read_text(encoding="utf-8")

assert "exact-merged-pr" not in source
assert "def exact_merged_pr" not in source
assert "not-explicitly-retired" in source
assert "explicit-retired-" in source
assert '"candidate_policy": "explicit-retirement-only"' in source
assert "registry/branch_gc_retired.json" in workflow
assert "manifests/branch_gc_retired.json" not in workflow
assert Path("registry/branch_gc_retired.json").is_file()
assert not Path("manifests/branch_gc_retired.json").exists()
assert "explicitly retired" in workflow.lower()
assert "merged_pr" not in workflow


# PR-controlled code must never receive a write-capable GitHub token.
def least_privilege_isolation(text: str) -> bool:
    if text.count('\n  branch-gc:\n') != 1 or text.count('\n  branch-gc-apply:\n') != 1:
        return False
    header, jobs = text.split('\njobs:\n', 1)
    readonly, write_job = jobs.split('\n  branch-gc-apply:\n', 1)
    expected_apply_condition = (
        "    if: (github.event_name == 'push' && github.ref == 'refs/heads/main') "
        "|| (github.event_name == 'workflow_dispatch' && inputs.apply && github.ref == 'refs/heads/main')"
    )
    return all((
        'permissions:\n  contents: read\n  pull-requests: read' in header,
        '    name: branch-gc\n    permissions:\n      contents: read\n      pull-requests: read' in readonly,
        'contents: write' not in readonly,
        'args+=(--apply)' not in readonly,
        expected_apply_condition in write_job,
        '    permissions:\n      contents: write\n      pull-requests: read' in write_job,
        'ref: ${{ github.sha }}' in write_job,
        'args+=(--apply)' in write_job,
    ))


assert least_privilege_isolation(workflow), 'Branch GC PR job must be read-only; apply must be trusted-main only'
assert not least_privilege_isolation(workflow.replace('permissions:\n  contents: read', 'permissions:\n  contents: write', 1))
assert not least_privilege_isolation(workflow.replace('    name: branch-gc\n    permissions:\n      contents: read', '    name: branch-gc\n    permissions:\n      contents: write', 1))
assert not least_privilege_isolation(workflow.replace("github.event_name == 'push'", "github.event_name == 'pull_request'", 1))
assert not least_privilege_isolation(workflow.replace('ref: ${{ github.sha }}', 'ref: main', 1))

SHA = "a" * 40
BRANCH = "codex/already-merged"


class FakeClient:
    repo = "jiying2007/llm_agent"

    def __init__(self):
        self.deleted = []
        self.closed_pull_queries = 0

    def list_branches(self):
        return [{"name": BRANCH, "protected": False, "commit": {"sha": SHA}}]

    def get_branch(self, branch):
        assert branch == BRANCH
        return {"name": BRANCH, "protected": False, "commit": {"sha": SHA}}

    def pulls(self, branch, base, state):
        assert branch == BRANCH
        assert base == "main"
        if state == "closed":
            self.closed_pull_queries += 1
            return [
                {
                    "number": 999,
                    "merged_at": "2026-09-16T00:00:00Z",
                    "head": {"ref": BRANCH, "sha": SHA},
                    "base": {"ref": "main"},
                }
            ]
        assert state == "open"
        return []

    def compare_sha_to_base(self, sha, base):
        assert sha == SHA
        assert base == "main"
        return {
            "merge_base_commit": {"sha": SHA},
            "behind_by": 0,
            "status": "ahead",
        }

    def delete_branch(self, branch):
        self.deleted.append(branch)


client = FakeClient()
report = branch_gc.run(
    client,
    False,
    "main",
    ("codex/",),
    {"main", "master"},
    {},
)
assert report["candidate_policy"] == "explicit-retirement-only"
assert report["candidates"] == []
assert report["deleted"] == []
assert report["skipped"] == [
    {"branch": BRANCH, "sha": SHA, "reason": "not-explicitly-retired"}
]
assert client.closed_pull_queries == 0, "generic merged PR discovery must stay retired"

retired = {
    BRANCH: {
        "branch": BRANCH,
        "sha": SHA,
        "disposition": "delete",
        "proof": "ancestor-of-main",
        "reason": "explicit exact-SHA retirement fixture",
    }
}
report = branch_gc.run(
    client,
    True,
    "main",
    ("codex/",),
    {"main", "master"},
    retired,
)
assert report["candidate_policy"] == "explicit-retirement-only"
assert report["candidates"] == [
    {
        "branch": BRANCH,
        "sha": SHA,
        "basis": "explicit-retired-ancestor-of-main",
        "registry_reason": "explicit exact-SHA retirement fixture",
    }
]
assert report["deleted"] == report["candidates"]
assert client.deleted == [BRANCH]
assert client.closed_pull_queries == 0

print("[PASS] generic merged-PR GC is retired; explicit exact-SHA retirement remains fail-closed")
PY
