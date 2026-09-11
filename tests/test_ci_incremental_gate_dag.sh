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

assert gates["schema"] == "llm-agent-gates/v2", gates["schema"]
assert "adk-interface" in profiles["contract"], profiles["contract"]
assert "active-contracts" in profiles["contract"], profiles["contract"]
assert profiles["pr-fast"] == ["contract", "doc-sync"], profiles["pr-fast"]
assert profiles["integration-extra"] == [
    "adk-integration",
    "adk-quick",
    "root-regression",
], profiles["integration-extra"]
assert profiles["integration"] == ["pr-fast", "integration-extra"], profiles["integration"]
assert profiles["release-extra"] == ["fresh-status", "harden-readiness"], profiles["release-extra"]
assert profiles["release"] == ["integration", "release-extra"], profiles["release"]

# Gate Graph v2 must carry actual dependency and content identity metadata.
assert gates["gates"]["adk-interface"]["depends_on"] == ["adk-pin"]
assert gates["gates"]["active-contracts"]["depends_on"] == ["adk-interface"]
assert gates["gates"]["root-regression"]["depends_on"] == ["adk-quick"]
for name, spec in gates["gates"].items():
    assert isinstance(spec.get("depends_on"), list), name
    assert isinstance(spec.get("inputs"), list), name
    assert isinstance(spec.get("outputs"), list), name
    assert spec.get("cache_policy") in {"disabled", "content-addressed"}, name

# GitHub CI executes each layer exactly once and gives skipped private checkout
# an explicit NOT_REQUIRED state rather than treating skip as compatibility pass.
for job in (
    "contract",
    "doc-sync",
    "integration-impact",
    "integration-capability",
    "integration",
    "integration-summary",
):
    assert re.search(rf"^  {re.escape(job)}:\s*$", github, re.MULTILINE), job
assert len(re.findall(r"--profile\s+contract(?:\s|$)", github)) == 1, github
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", github)) == 1, github
assert len(re.findall(r"--profile\s+integration-extra(?:\s|$)", github)) == 1, github
assert not re.search(r"--profile\s+integration(?:\s|$)", github), github
assert "cross-repo-contract-change" in github, github
assert "ADK deep integration: NOT_REQUIRED" in github, github
assert "deep integration was REQUIRED but did not pass" in github, github
assert re.search(
    r"integration-impact:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync",
    github,
), github
assert re.search(
    r"integration-capability:\n(?:.|\n)*?needs:\n\s+- integration-impact",
    github,
), github
assert re.search(
    r"integration:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-impact\n\s+- integration-capability",
    github,
), github
assert "adk\\.lock" in github and "product_maturity_scorecard" in github and "software_m5_policy" in github

# GitLab uses the same gate SSOT without rerunning the contract profile inside
# the dependent doc job. Private cross-repo checkout remains a GitHub capability,
# but source/interface contracts are part of the shared contract profile.
assert len(re.findall(r"--profile\s+contract(?:\s|$)", gitlab)) == 1, gitlab
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", gitlab)) == 1, gitlab
assert not re.search(r"--profile\s+pr-fast(?:\s|$)", gitlab), gitlab
assert re.search(r"^doc-sync:\s*$", gitlab, re.MULTILINE), gitlab
assert re.search(r"weekly-report:\n(?:.|\n)*?needs:\n\s+- doc-sync", gitlab), gitlab
PY

echo '[PASS] GitHub/GitLab CI consume Gate Graph v2 with explicit deep-integration semantics'
