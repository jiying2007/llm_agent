#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT/agent-dev-kit/src${PYTHONPATH:+:$PYTHONPATH}"

python3 - "$ROOT" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root=Path(sys.argv[1])

def run(*args):
    done=subprocess.run(
        [sys.executable,"-m","agent_dev_kit.cli",*args,"--summary-json"],
        cwd=root,text=True,capture_output=True,timeout=60,
    )
    assert done.returncode==0,(done.returncode,done.stdout,done.stderr)
    return json.loads(done.stdout)

core=run("profile-footprint","--profile","core")
assert core["status"]=="pass",core
assert core["accounting"]["runtime_initial_context_measured"] is False,core
assert core["frontmatter_surface"]["token_estimate_is_provider_measurement"] is False,core

delta=run("profile-footprint","--profile","core","--compare","embedded-fullstack")
assert delta["status"]=="pass" and delta["release_authorized"] is False,delta
assert delta["lifecycle_authority"]=="none-evidence-only",delta
assert delta["delta"]["entry_file_bytes"]>0,delta

ratchet=run("profile-footprint","--profile","core","--ratchet")
assert ratchet["status"]=="pass",ratchet
assert ratchet["runtime_initial_context_claim"] is False,ratchet
assert ratchet["release_authorized"] is False,ratchet

for target in ("claude-code","opencode"):
    probe=run("target-source-probe","--target",target,"--profile","core")
    assert probe["status"]=="pass",probe
    assert probe["source_discovery"]=="pass" and probe["source_load"]=="pass",probe
    assert probe["evidence_level"]=="source-layout",probe
    assert probe["native_runtime_evidence"] is False,probe
    assert probe["certification"]=="not-certified",probe
    assert probe["release_authorized"] is False,probe

print("[PASS] pinned ADK exposes source-only context and target observability without qualification escalation")
PY
