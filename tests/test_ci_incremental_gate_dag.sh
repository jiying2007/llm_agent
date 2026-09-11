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

for job in (
    "contract",
    "doc-sync",
    "integration-impact",
    "integration",
    "integration-summary",
):
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
assert re.search(
    r"integration-impact:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync",
    github,
), github
assert re.search(
    r"integration:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-impact",
    github,
), github
assert "adk\\.lock" in github and "product_maturity_scorecard" in github and "software_m5_policy" in github

assert len(re.findall(r"--profile\s+contract(?:\s|$)", gitlab)) == 1, gitlab
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", gitlab)) == 1, gitlab
assert not re.search(r"--profile\s+pr-fast(?:\s|$)", gitlab), gitlab
assert re.search(r"^doc-sync:\s*$", gitlab, re.MULTILINE), gitlab
assert re.search(r"weekly-report:\n(?:.|\n)*?needs:\n\s+- doc-sync", gitlab), gitlab
PY

echo '[PASS] GitHub/GitLab CI consume Gate Graph v2 with Cosign 3.1.3 Rekor v2 evidence semantics'
