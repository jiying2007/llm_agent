#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
gates = json.loads((root / "manifests/gates.json").read_text(encoding="utf-8"))
profiles = gates["profiles"]
github = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
branch_gc = (root / ".github/workflows/branch-gc.yml").read_text(encoding="utf-8")
branch_gc_code = (root / "tools/control_plane/branch_gc.py").read_text(encoding="utf-8")
retired_gc = json.loads((root / "manifests/branch_gc_retired.json").read_text(encoding="utf-8"))
gitlab = (root / ".gitlab-ci.yml").read_text(encoding="utf-8")

gate_specs = gates["gates"]
assert gates["schema"] == "llm-agent-gates/v2", gates["schema"]
assert "adk-interface" in profiles["contract"], profiles["contract"]
assert "active-contracts" in profiles["contract"], profiles["contract"]
assert profiles["pr-fast"] == ["contract", "doc-sync"], profiles["pr-fast"]
assert profiles["integration-extra"] == ["adk-promotion-evidence", "root-regression"], profiles["integration-extra"]
assert profiles["integration"] == ["pr-fast", "integration-extra"], profiles["integration"]
assert profiles["release-extra"] == ["fresh-status", "harden-readiness"], profiles["release-extra"]
assert profiles["release"] == ["integration", "release-extra"], profiles["release"]

assert gate_specs["adk-interface"]["depends_on"] == ["adk-pin"]
assert gate_specs["active-contracts"]["depends_on"] == ["adk-interface"]
assert gate_specs["adk-promotion-evidence"]["depends_on"] == ["adk-interface"]
assert gate_specs["root-regression"]["depends_on"] == ["adk-promotion-evidence"]
assert gate_specs["harden-readiness"].get("requires") == ["runtime-source"]
assert "adk-integration" not in gate_specs
assert "adk-quick" not in gate_specs
assert "adk-checkout" not in json.dumps(gates, sort_keys=True)
for name, spec in gate_specs.items():
    assert isinstance(spec.get("depends_on"), list), name
    assert isinstance(spec.get("inputs"), list), name
    assert isinstance(spec.get("outputs"), list), name
    assert spec.get("cache_policy") in {"disabled", "content-addressed"}, name

for job in ("contract", "doc-sync", "integration-impact", "integration", "integration-summary", "software-m5"):
    assert re.search(rf"^  {re.escape(job)}:\s*$", github, re.MULTILINE), job
assert not re.search(r"^  integration-capability:\s*$", github, re.MULTILINE), github
assert "ADK_REPO_TOKEN" not in github, github
assert "repository: jiying2007/agent-dev-kit" not in github, github
assert len(re.findall(r"--profile\s+contract(?:\s|$)", github)) == 1, github
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", github)) == 1, github
assert not re.search(r"--profile\s+integration-extra(?:\s|$)", github), github
assert not re.search(r"--profile\s+integration(?:\s|$)", github), github
assert "cross-repo-contract-change" in github, github
assert "promotion-attestation" in github and "promotion-evidence" in github, github
assert "sigstore/cosign-installer@6f9f17788090df1f26f669e9d70d6ae9567deba6" in github, github
assert "cosign-release: v3.1.3" in github, github
assert "cosign initialize" in github, github
assert "trusted_root.json" in github, github
assert "cosign verify-blob" in github, github
assert "--trusted-root" in github, github
assert "--use-signed-timestamps" in github, github
assert "--insecure-ignore-tlog" not in github, github
assert "--certificate-identity https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main" in github, github
assert "--certificate-oidc-issuer https://token.actions.githubusercontent.com" in github, github
assert "gh attestation" not in github, github
assert "promotion evidence verification was REQUIRED but did not pass" in github, github
assert "ADK promotion evidence: NOT_REQUIRED" in github, github
assert re.search(r"integration-impact:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync", github), github
assert re.search(r"integration:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-impact", github), github
assert re.search(r"software-m5:\n(?:.|\n)*?name: software-m5-certify\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-summary", github), github
assert "needs.integration-summary.result == 'success'" in github, github
assert "bash scripts/software-m5.sh certify --summary-json" in github, github
assert "Enforce Software M5 current-or-historical qualification state" in github, github
assert "HISTORICAL_NOT_AUTHORIZED" in github, github
assert "source-current-evidence-historical" in github, github
assert "fresh_for_current_source'] is False" in github, github
assert "source_inputs_match'] is False" in github, github
assert "release_evidence_relation:\\s*historical" in github, github
assert "release_authorized:\\s*false" in github, github
assert "set -euo pipefail" in github, github
assert "software-m5-certification.json" in github, github
assert "name: software-m5-certification" in github, github
assert "adk\\.lock" in github and "product_maturity_scorecard" in github and "software_m5_policy" in github

# Branch GC: PR=dry-run; main push/explicit dispatch=apply; only approved namespace prefixes are scanned.
assert "name: Branch GC" in branch_gc
assert re.search(r"^  pull_request:\s*$", branch_gc, re.MULTILINE), branch_gc
assert re.search(r"^  push:\n\s+branches:\n\s+- main", branch_gc, re.MULTILINE), branch_gc
assert "workflow_dispatch:" in branch_gc and "apply:" in branch_gc, branch_gc
assert "contents: write" in branch_gc and "pull-requests: read" in branch_gc, branch_gc
assert "cancel-in-progress: false" in branch_gc, branch_gc
assert "--prefix 'codex/'" in branch_gc and "--prefix 'arch/'" in branch_gc, branch_gc
assert "--protected main" in branch_gc and "--protected master" in branch_gc, branch_gc
assert "--retired-registry manifests/branch_gc_retired.json" in branch_gc, branch_gc
assert 'EVENT_NAME" == "push" && "$REF_NAME" == "main"' in branch_gc, branch_gc
assert 'EVENT_NAME" == "workflow_dispatch" && "$DISPATCH_APPLY" == "true"' in branch_gc, branch_gc
assert 'args+=(--apply)' in branch_gc, branch_gc
assert "name: branch-gc-report" in branch_gc, branch_gc

# Automatic cleanup requires exact merged-PR identity. Explicit retirement remains exact-SHA and supports only verified proof modes.
assert 'head.get("sha") != sha' in branch_gc_code, branch_gc_code
assert 'base_obj.get("ref") != base' in branch_gc_code, branch_gc_code
assert 'client.pulls(branch, base, "open")' in branch_gc_code, branch_gc_code
assert 'if branch_sha(current) != c.sha' in branch_gc_code, branch_gc_code
assert 'exact_merged_pr(client, c.branch, c.sha, base)' in branch_gc_code, branch_gc_code
assert 'proof not in {"ancestor-of-main", "absorbed-path-blobs", "terminal-probe"}' in branch_gc_code, branch_gc_code
assert 'compare_sha_to_base' in branch_gc_code and 'compare_base_to_sha' in branch_gc_code, branch_gc_code
assert 'merge_sha == sha' in branch_gc_code and 'comparison.get("behind_by") == 0' in branch_gc_code, branch_gc_code
assert 'actual_paths != expected_paths' in branch_gc_code, branch_gc_code
assert 'client.content_sha(path, sha) != expected_blob' in branch_gc_code, branch_gc_code
assert 'client.content_sha(path, base) != expected_blob' in branch_gc_code, branch_gc_code
assert 'workflow_run(self, run_id: int)' in branch_gc_code, branch_gc_code
assert 'terminal_probe_match' in branch_gc_code, branch_gc_code
assert 'comparison.get("ahead_by") != 1' in branch_gc_code, branch_gc_code
assert 'actual_paths != {expected_path}' in branch_gc_code, branch_gc_code
assert 'client.content_sha(expected_path, sha) != retirement["blob_sha"]' in branch_gc_code, branch_gc_code
assert 'workflow_run_matches(client, retirement["probe_run"])' in branch_gc_code, branch_gc_code
assert 'workflow_run_matches(client, retirement["superseding_run"])' in branch_gc_code, branch_gc_code
assert 'superseding_time <= probe_time' in branch_gc_code, branch_gc_code
assert 'contained_in_base(client, superseding_sha, base)' in branch_gc_code, branch_gc_code
assert 'retirement["sha"] != sha' in branch_gc_code, branch_gc_code
assert 'retired-proof-no-longer-valid' in branch_gc_code, branch_gc_code
assert 'client.delete_branch(c.branch)' in branch_gc_code, branch_gc_code
assert 'urllib.parse.quote(branch, safe="/")' in branch_gc_code, branch_gc_code

assert retired_gc["schema"] == "llm-agent-branch-gc-retired/v1"
entries = {item["branch"]: item for item in retired_gc["entries"]}
assert entries["codex/reconstruct-attestation-20260912"]["proof"] == "ancestor-of-main"
arch = entries["arch/runtime-binding-receipt-v1"]
assert arch["sha"] == "4fb361247dfe6f6bf196f1a532dc1abc4b1c72ed"
assert arch["proof"] == "absorbed-path-blobs"
assert arch["unique_commit_count"] == 1
assert arch["paths"] == {"manifests/digital_worker_runtime_pilot.json": "fc975dcc332d04297eccad5504396edaf2c2fde1"}
probe = entries["codex/runner-allocation-probe-20260912"]
assert probe["sha"] == "eac43874b8ce8f630f196d7b936a497f7927e894"
assert probe["proof"] == "terminal-probe"
assert probe["unique_commit_count"] == 1
assert probe["path"] == ".github/workflows/runner-probe.yml"
assert probe["blob_sha"] == "8d228a8dda5ad80111853cae32395fce03cdcb57"
assert probe["probe_run"] == {
    "id": 34658015398,
    "name": "runner-allocation-probe",
    "path": ".github/workflows/runner-probe.yml",
    "head_branch": "codex/runner-allocation-probe-20260912",
    "head_sha": "eac43874b8ce8f630f196d7b936a497f7927e894",
    "status": "completed",
    "conclusion": "failure",
    "event": "pull_request",
}
assert probe["superseding_run"] == {
    "id": 34678812343,
    "name": "llm-agent-ci",
    "path": ".github/workflows/ci.yml",
    "head_branch": "main",
    "head_sha": "7e3f7790f5eacf67a7d93c20ed7c8288126a7063",
    "status": "completed",
    "conclusion": "success",
    "event": "push",
}

assert len(re.findall(r"--profile\s+contract(?:\s|$)", gitlab)) == 1, gitlab
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", gitlab)) == 1, gitlab
assert not re.search(r"--profile\s+pr-fast(?:\s|$)", gitlab), gitlab
assert re.search(r"^doc-sync:\s*$", gitlab, re.MULTILINE), gitlab
assert re.search(r"weekly-report:\n(?:.|\n)*?needs:\n\s+- doc-sync", gitlab), gitlab
PY

echo '[PASS] CI semantics include Cosign/Rekor v2, Software M5 certification, and fail-closed merged/retired branch GC with absorbed-content and terminal-probe proof'
