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

assert profiles["pr-fast"] == ["contract", "doc-sync"], profiles["pr-fast"]
assert profiles["integration-extra"] == [
    "adk-integration",
    "adk-quick",
    "root-regression",
], profiles["integration-extra"]
assert profiles["integration"] == ["pr-fast", "integration-extra"], profiles["integration"]
assert profiles["release-extra"] == ["fresh-status", "harden-readiness"], profiles["release-extra"]
assert profiles["release"] == ["integration", "release-extra"], profiles["release"]

# GitHub CI executes each layer exactly once. `integration` is still available
# as a standalone full profile, but the integration job consumes only the
# incremental profile after contract/doc-sync have succeeded.
for job in ("contract", "doc-sync", "integration-capability", "integration"):
    assert re.search(rf"^  {re.escape(job)}:\s*$", github, re.MULTILINE), job
assert len(re.findall(r"--profile\s+contract(?:\s|$)", github)) == 1, github
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", github)) == 1, github
assert len(re.findall(r"--profile\s+integration-extra(?:\s|$)", github)) == 1, github
assert not re.search(r"--profile\s+integration(?:\s|$)", github), github
assert re.search(
    r"integration-capability:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync",
    github,
), github
assert re.search(
    r"integration:\n(?:.|\n)*?needs:\n\s+- contract\n\s+- doc-sync\n\s+- integration-capability",
    github,
), github

# GitLab uses the same gate SSOT without rerunning the contract profile inside
# the dependent doc job.
assert len(re.findall(r"--profile\s+contract(?:\s|$)", gitlab)) == 1, gitlab
assert len(re.findall(r"--profile\s+doc-sync(?:\s|$)", gitlab)) == 1, gitlab
assert not re.search(r"--profile\s+pr-fast(?:\s|$)", gitlab), gitlab
assert re.search(r"^doc-sync:\s*$", gitlab, re.MULTILINE), gitlab
assert re.search(r"weekly-report:\n(?:.|\n)*?needs:\n\s+- doc-sync", gitlab), gitlab
PY

echo '[PASS] GitHub/GitLab CI consume incremental gate DAG without duplicate contract/doc execution'
