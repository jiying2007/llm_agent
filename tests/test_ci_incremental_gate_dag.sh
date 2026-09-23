#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root))

from tools.control_plane.impact import calculate_impact

manifest = json.loads((root / "manifests/gates.json").read_text(encoding="utf-8"))
profiles = manifest["profiles"]
gates = manifest["gates"]
github = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
branch_gc = (root / ".github/workflows/branch-gc.yml").read_text(encoding="utf-8")
branch_gc_code = (root / "tools/control_plane/branch_gc.py").read_text(encoding="utf-8")
retired_gc = json.loads((root / "registry/branch_gc_retired.json").read_text(encoding="utf-8"))
gitlab = (root / ".gitlab-ci.yml").read_text(encoding="utf-8")
pyproject = (root / "pyproject.toml").read_text(encoding="utf-8")

assert manifest["schema"] == "llm-agent-gates/v2"
assert profiles["contract"] == [
    "adk-pin",
    "adk-interface",
    "codex-pin",
    "runtime-chain-pin",
    "gitlink-registry",
    "reference-pins",
    "source-hygiene",
    "status-projection",
    "active-contracts",
    "native-governance-contract",
    "status-projection-regression",
    "adk-promotion-transaction",
    "current-status-source-split",
    "ci-incremental-dag",
]
assert profiles["pr-fast"] == ["contract", "doc-sync"]
assert profiles["integration-extra"] == ["adk-promotion-evidence", "root-regression"]
assert profiles["integration"] == ["pr-fast", "integration-extra"]
assert profiles["release-extra"] == ["fresh-status", "harden-readiness"]
assert profiles["release"] == ["integration", "release-extra"]

assert gates["adk-interface"]["depends_on"] == ["adk-pin"]
assert gates["codex-pin"]["depends_on"] == []
assert gates["runtime-chain-pin"]["depends_on"] == ["adk-interface", "codex-pin"]
assert gates["gitlink-registry"]["depends_on"] == ["adk-pin", "codex-pin"]
assert gates["adk-promotion-evidence"]["depends_on"] == ["adk-interface"]
assert gates["native-governance-contract"]["depends_on"] == ["active-contracts"]
assert gates["native-governance-contract"]["argv"] == [
    "bash",
    "tests/test_native_repository_governance_certifier.sh",
]
assert "tools/control_plane/native_repository_governance.py" in gates["native-governance-contract"]["inputs"]
assert ".github/workflows/native-governance-control-plane.yml" in gates["native-governance-contract"]["inputs"]
assert gates["root-regression"]["depends_on"] == ["adk-promotion-evidence"]
assert gates["harden-readiness"].get("requires") == ["runtime-source"]
assert gates["adk-pin"]["impact_inputs"] == ["agent-dev-kit"]
assert gates["codex-pin"]["impact_inputs"] == ["codex"]
assert "tools/control_plane/impact.py" in gates["ci-incremental-dag"]["inputs"]
assert "integration-deep" in gates["ci-incremental-dag"]["impact_groups"]
assert "integration-deep" in gates["adk-promotion-evidence"]["impact_groups"]
assert "integration-deep" in gates["runtime-chain-pin"]["impact_groups"]
assert "adk-integration" not in gates
assert "adk-quick" not in gates
assert "adk-checkout" not in json.dumps(manifest, sort_keys=True)

for name, spec in gates.items():
    assert isinstance(spec.get("depends_on"), list), name
    assert isinstance(spec.get("inputs"), list), name
    assert isinstance(spec.get("outputs"), list), name
    assert isinstance(spec.get("impact_inputs", []), list), name
    assert isinstance(spec.get("impact_groups", []), list), name
    assert spec.get("cache_policy") in {"disabled", "content-addressed"}, name


def impact(*paths: str, force: bool = False):
    return calculate_impact(root, paths, group="integration-deep", force=force)

# Impact comes from gate metadata rather than a workflow-local path regex.
readme = impact("README.md")
assert readme["required"] is False, readme
assert "active-contracts" in readme["direct_gates"], readme

adk = impact("adk.lock")
assert adk["required"] is True, adk
assert {"adk-pin", "adk-interface", "runtime-chain-pin"}.issubset(adk["group_gates"]), adk

adk_gitlink = impact("agent-dev-kit")
assert adk_gitlink["required"] is True and "adk-pin" in adk_gitlink["group_gates"], adk_gitlink

codex = impact("codex")
assert codex["required"] is True and "codex-pin" in codex["group_gates"], codex

workflow = impact(".github/workflows/ci.yml")
assert workflow["required"] is True and "ci-incremental-dag" in workflow["group_gates"], workflow

runtime = impact("manifests/runtime_targets.json")
assert runtime["required"] is True and "harden-readiness" in runtime["group_gates"], runtime

docs = impact("docs/architecture/something.md")
assert docs["required"] is False, docs

forced = impact("docs/architecture/something.md", force=True)
assert forced["required"] is True and forced["reason"] == "workflow-dispatch", forced

for job in ("contract", "doc-sync", "integration-impact", "integration", "integration-summary", "software-m5"):
    assert re.search(rf"^  {re.escape(job)}:\s*$", github, re.MULTILINE), job
assert not re.search(r"^  integration-capability:\s*$", github, re.MULTILINE)
assert "ADK_REPO_TOKEN" not in github
assert "repository: jiying2007/agent-dev-kit" not in github
assert "tools.control_plane.cli gate" in github
assert "tools.control_plane.cli impact" in github
assert "tools.control_plane.cli status" in github
assert "tools.control_plane.cli runtime-chain" in github
assert "tools.control_plane.cli promotion-evidence" in github
assert len(re.findall(r"--profile\s+integration-extra(?:\s|$)", github)) == 1
assert "/tmp/llm-agent-integration-gate-receipt.json" in github
assert "--group integration-deep" in github
assert '--github-output "$GITHUB_OUTPUT"' in github
assert '--step-summary "$GITHUB_STEP_SUMMARY"' in github
assert "cross-repo-contract-change" not in github
assert "grep -Eq '^(" not in github
assert "git submodule update --init --depth=1 codex" in github
assert "/tmp/runtime-chain-receipt.json" in github

# Existing evidence/trust semantics must not weaken while routing through llm-ctl.
assert "promotion-attestation" in github and "promotion-evidence" in github
assert "sigstore/cosign-installer@6f9f17788090df1f26f669e9d70d6ae9567deba6" in github
assert "cosign-release: v3.1.3" in github
assert "sudo apt-get install -y ripgrep" in github
assert "cosign initialize" in github
assert "for attempt in 1 2 3" in github
assert "failed after 3 strict attempts" in github
assert "trusted_root.json" not in github
assert "cosign verify-blob" in github
assert "--use-signed-timestamps" not in github
assert "--rfc3161-timestamp-path" not in github
assert "--trusted-root" not in github
assert "--new-bundle-format" not in github
assert "--insecure-ignore-tlog" not in github
assert "--certificate-identity https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main" in github
assert "--certificate-oidc-issuer https://token.actions.githubusercontent.com" in github
assert "promotion evidence verification was REQUIRED but did not pass" in github
assert "ADK promotion evidence: NOT_REQUIRED" in github
assert re.search(r"integration-impact:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync", github)
assert re.search(r"integration:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-impact", github)
assert "needs.integration-summary.result == 'success'" in github
assert "bash scripts/software-m5.sh certify --summary-json" in github
assert "HISTORICAL_NOT_AUTHORIZED" in github
assert "source-current-evidence-historical" in github
assert "fresh_for_current_source'] is False" in github
assert "source_inputs_match'] is False" in github
assert "release_evidence_relation:\\s*historical" in github
assert "release_authorized:\\s*false" in github
assert "software-m5-certification.json" in github

# Root now has one package/CLI identity; workflow and shell callers can converge on it.
assert 'name = "llm-agent-control-plane"' in pyproject
assert 'llm-ctl = "tools.control_plane.cli:main"' in pyproject
assert 'files = [' in pyproject and '"tools/control_plane/impact.py"' in pyproject

# Native delete-on-merge now owns ordinary merged PR branches. Custom Branch GC
# remains only for exceptional, explicitly registered exact-SHA retirement proofs.
assert "name: Branch GC" in branch_gc
assert re.search(r"^  pull_request:\s*$", branch_gc, re.MULTILINE)
assert re.search(r"^  push:\n\s+branches:\n\s+- main", branch_gc, re.MULTILINE)
assert "workflow_dispatch:" in branch_gc and "apply:" in branch_gc
assert "contents: write" in branch_gc and "pull-requests: read" in branch_gc
assert "cancel-in-progress: false" in branch_gc
assert "--retired-registry registry/branch_gc_retired.json" in branch_gc
assert "manifests/branch_gc_retired.json" not in branch_gc
assert 'EVENT_NAME" == "push" && "$REF_NAME" == "main"' in branch_gc
assert 'EVENT_NAME" == "workflow_dispatch" && "$DISPATCH_APPLY" == "true"' in branch_gc
assert 'args+=(--apply)' in branch_gc
assert "name: branch-gc-report" in branch_gc
assert "explicitly retired" in branch_gc.lower()
assert "merged_pr" not in branch_gc

assert 'client.pulls(branch, base, "open")' in branch_gc_code
assert 'if branch_sha(current) != candidate.sha' in branch_gc_code
assert 'proof not in {"ancestor-of-main", "absorbed-path-blobs", "terminal-probe"}' in branch_gc_code
assert 'retired-proof-no-longer-valid' in branch_gc_code
assert 'client.delete_branch(candidate.branch)' in branch_gc_code
assert '"candidate_policy": "explicit-retirement-only"' in branch_gc_code
assert 'not-explicitly-retired' in branch_gc_code
assert 'explicit-retired-' in branch_gc_code
assert 'exact-merged-pr' not in branch_gc_code
assert 'def exact_merged_pr' not in branch_gc_code

assert retired_gc["schema"] == "llm-agent-branch-gc-retired/v1"
entries = {item["branch"]: item for item in retired_gc["entries"]}
assert entries["codex/reconstruct-attestation-20260912"]["proof"] == "ancestor-of-main"
assert entries["arch/runtime-binding-receipt-v1"]["proof"] == "absorbed-path-blobs"
assert entries["codex/runner-allocation-probe-20260912"]["proof"] == "terminal-probe"

assert len(re.findall(r"--profile\s+contract(?:\s|$)", gitlab)) == 1
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", gitlab)) == 1
assert re.search(r"^doc-sync:\s*$", gitlab, re.MULTILINE)
assert re.search(r"weekly-report:\n(?:.|\n)*?needs:\n\s+- doc-sync", gitlab)
PY

echo '[PASS] CI uses gate-derived integration impact, typed control-plane entrypoints, and native-deletion-aware fail-closed GC semantics'
