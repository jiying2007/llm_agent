#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root = Path.cwd()

def run(args, expected=0):
    done = subprocess.run(
        [sys.executable, "-m", "agent_dev_kit.cli", *args, "--root", str(root / "agent-dev-kit"), "--summary-json"],
        cwd=root,
        text=True,
        capture_output=True,
        timeout=60,
    )
    assert done.returncode == expected, (args, done.returncode, done.stdout, done.stderr)
    value = json.loads(done.stdout)
    return value

core = run(["profile-footprint", "--profile", "core"])
assert core["schema"] == "adk-profile-context-footprint/v1", core
assert core["status"] == "pass" and core["source_version"] == "7.2.0", core
assert core["accounting"]["runtime_initial_context_measured"] is False, core
for surface in ("frontmatter_surface", "entry_body_surface", "entry_file_surface", "deferred_support_surface"):
    assert core[surface]["bytes"] > 0, (surface, core[surface])
    assert core[surface]["token_estimate_is_provider_measurement"] is False, core[surface]
assert core["entry_file_surface"]["bytes"] == (
    core["frontmatter_surface"]["bytes"] + core["entry_body_surface"]["bytes"]
), core
assert core["potential_full_source_surface"]["bytes"] == (
    core["entry_file_surface"]["bytes"] + core["deferred_support_surface"]["bytes"]
), core

comparison = run(["profile-footprint", "--profile", "core", "--compare", "embedded-fullstack"])
assert comparison["schema"] == "adk-profile-context-comparison/v1", comparison
assert comparison["status"] == "pass", comparison
assert comparison["delta"]["assets"] > 0, comparison
assert comparison["delta"]["entry_file_bytes"] > 0, comparison
assert comparison["lifecycle_authority"] == "none-evidence-only", comparison
assert comparison["release_authorized"] is False, comparison

ratchet = run(["profile-footprint", "--profile", "core", "--ratchet"])
assert ratchet["schema"] == "adk-profile-context-ratchet-result/v1", ratchet
assert ratchet["status"] == "pass", ratchet
assert ratchet["runtime_initial_context_claim"] is False, ratchet
assert ratchet["release_authorized"] is False, ratchet

for target in ("claude-code", "opencode"):
    probe = run(["target-source-probe", "--target", target, "--profile", "core"])
    assert probe["schema"] == "adk-target-source-probe/v1", probe
    assert probe["status"] == "pass", probe
    assert probe["source_discovery"] == "pass" and probe["source_load"] == "pass", probe
    assert probe["evidence_level"] == "source-layout", probe
    assert probe["native_runtime_evidence"] is False, probe
    assert probe["certification"] == "not-certified", probe
    assert probe["release_authorized"] is False, probe
    assert probe["files"] > 0 and probe["bytes"] > 0, probe

bad = run(["target-source-probe", "--target", "missing-target", "--profile", "core"], expected=1)
assert bad["status"] == "fail", bad

print("[PASS] Root consumes ADK 7.2.0 profile/source observability without upgrading evidence authority")
PY
