#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Source-only CI keeps submodules disabled. The projection must remain complete
# from root-side locks/evidence in both current-certified and source-transition states.
python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --summary-json >"$TMP"

python3 - "$TMP" "$ROOT/adk.lock" "$ROOT/reports/current-status.md" "$ROOT/manifests/software_m5_policy.json" <<'PY'
import json
import re
import sys
from pathlib import Path

projection = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lock = {}
for line in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
status = Path(sys.argv[3]).read_text(encoding="utf-8")
policy = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))

begin = "<!-- BEGIN GENERATED CURRENT SOURCE PROJECTION -->"
end = "<!-- END GENERATED CURRENT SOURCE PROJECTION -->"
assert status.count(begin) == 1 and status.count(end) == 1, status
block = status.split(begin, 1)[1].split(end, 1)[0]

assert projection["status"] == "pass", projection
assert projection["source"]["adk_lock_commit"] == lock["agent-dev-kit.commit"], projection
assert projection["source"]["pin_consistent"] is True, projection
assert projection["current_projection"]["consistent"] is True, projection
assert projection["current_projection"]["mismatches"] == {}, projection
assert "- current_product_maturity: M5" in block, block
assert status.count("- release_authorized: ") == 1, status
assert "- baseline_release_authorized: true" in status, status

if projection["release_authorized"] is True:
    assert projection["current_evidence_state"] == "verified-for-current-source", projection
    assert projection["last_verified_baseline"]["source_inputs_match"] is True, projection
    assert projection["last_verified_baseline"]["fresh_for_current_source"] is True, projection
    assert re.search(r"^- release_evidence_relation:\s*current$", block, re.MULTILINE), block
    assert re.search(r"^- release_authorized:\s*true$", block, re.MULTILINE), block
else:
    assert projection["current_evidence_state"] == "source-current-evidence-historical", projection
    assert projection["last_verified_baseline"]["source_inputs_match"] is False, projection
    assert projection["last_verified_baseline"]["fresh_for_current_source"] is False, projection
    assert re.search(r"^- release_evidence_relation:\s*historical$", block, re.MULTILINE), block
    assert re.search(r"^- release_authorized:\s*false$", block, re.MULTILINE), block

assert policy["definition"] == "production-qualified", policy
assert policy["operational_advisories"]["recommended_observation_days"] >= 30, policy
assert policy["operational_advisories"]["second_human_operator"] is False, policy
assert policy["operational_advisories"]["multi_runtime_campaign"] is True, policy
PY

echo "[PASS] source-only status projection preserves explicit current-vs-historical qualification semantics"
