#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -m tools.control_plane.cli long-term-rehearsal \
  --root "$ROOT" \
  --scope all \
  --summary-json >"$TMP/rehearsal.json"

python3 - "$ROOT" "$TMP/rehearsal.json" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
receipt = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
policy = json.loads((root / "manifests/long_term_asset_rehearsal.json").read_text(encoding="utf-8"))
cli = (root / "tools/control_plane/cli.py").read_text(encoding="utf-8")

assert policy["schema"] == "llm-agent-long-term-asset-rehearsal-policy/v1", policy
assert policy["enabled"] is True, policy
assert policy["terminal_effect"] == "none", policy
assert policy["required_markers"] == {"simulated": True, "terminal_qualified": False}, policy
assert set(policy["scopes"]) == {"r2", "longitudinal"}, policy
assert all(policy["hard_rules"].values()), policy
assert "reports/long-term-assets/runtime-portability-current.json" in policy["forbidden_canonical_outputs"], policy
assert "reports/long-term-assets/longitudinal-operation-current.json" in policy["forbidden_canonical_outputs"], policy
assert "manifests/long_term_asset_qualification.json" in policy["forbidden_canonical_outputs"], policy
assert '"long-term-rehearsal": "tools.control_plane.long_term_asset_rehearsal"' in cli, cli

assert receipt["schema"] == "llm-agent-long-term-asset-rehearsal/v1", receipt
assert receipt["status"] == "pass", receipt
assert receipt["simulated"] is True, receipt
assert receipt["terminal_qualified"] is False, receipt
assert receipt["terminal_effect"] == "none", receipt
assert receipt["scope"] == "all", receipt
assert receipt["worktree_unchanged"] is True, receipt
assert receipt["canonical_evidence_written"] is False, receipt
assert receipt["failed_scopes"] == [], receipt

real = receipt["real_state"]
assert real["LTA-02"] == "blocked_external_evidence", real
assert real["LTA-04"] == "blocked_time_evidence", real
assert real["terminal_status"] == "blocked", real
assert real["terminal_qualified"] is False, real
assert set(real["terminal_blockers"]) == {"LTA-02", "LTA-04"}, real

r2 = receipt["rehearsals"]["r2"]
assert r2["status"] == "pass", r2
assert r2["simulated"] is True and r2["terminal_qualified"] is False, r2
assert r2["mode"] == "synthetic-r2-fixture", r2
assert r2["exit_code"] == 0, r2

longitudinal = receipt["rehearsals"]["longitudinal"]
assert longitudinal["status"] == "pass", longitudinal
assert longitudinal["simulated"] is True and longitudinal["terminal_qualified"] is False, longitudinal
assert longitudinal["mode"] == "time-travel-30-day-fixture", longitudinal
assert longitudinal["exit_code"] == 0, longitudinal
PY

echo '[PASS] long-term rehearsal reaches simulated R2/30-day PASS without terminal effect'
