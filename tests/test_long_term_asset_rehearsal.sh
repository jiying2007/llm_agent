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
qualification = json.loads((root / "manifests/long_term_asset_qualification.json").read_text(encoding="utf-8"))
policy = qualification["rehearsal_policy"]
assert not (root / "manifests/long_term_asset_rehearsal.json").exists()
cli = (root / "tools/control_plane/cli.py").read_text(encoding="utf-8")

assert policy["schema"] == "llm-agent-long-term-asset-rehearsal-policy/v1", policy
assert policy["enabled"] is True, policy
assert policy["terminal_effect"] == "none", policy
assert policy["required_markers"] == {"simulated": True, "terminal_qualified": False}, policy
assert set(policy["scopes"]) == {"longitudinal"}, policy
assert all(policy["hard_rules"].values()), policy
assert "reports/long-term-assets/longitudinal-operation-current.json" in policy["forbidden_canonical_outputs"], policy
assert "manifests/long_term_asset_qualification.json" in policy["forbidden_canonical_outputs"], policy
assert '"long-term-rehearsal": "tools.control_plane.long_term_asset_rehearsal"' in cli, cli

assert qualification["schema"] == "llm-agent-long-term-asset-qualification/v2", qualification
assert receipt["schema"] == "llm-agent-long-term-asset-rehearsal/v2", receipt
assert receipt["status"] == "pass", receipt
assert receipt["simulated"] is True, receipt
assert receipt["terminal_qualified"] is False, receipt
assert receipt["terminal_effect"] == "none", receipt
assert receipt["scope"] == "all", receipt
assert receipt["worktree_unchanged"] is True, receipt
assert receipt["canonical_evidence_written"] is False, receipt
assert receipt["failed_scopes"] == [], receipt
assert receipt["source"]["policy"] == "manifests/long_term_asset_qualification.json#rehearsal_policy", receipt
assert len(receipt["source"]["policy_sha256"]) == 64, receipt

real = receipt["real_state"]
assert real["LTA-04"] == "observation_window_in_progress", real
assert real["terminal_status"] == "qualification_pending", real
assert real["terminal_qualified"] is False, real
assert real["terminal_pending_requirements"] == ["LTA-04"], real

longitudinal = receipt["rehearsals"]["longitudinal"]
assert longitudinal["status"] == "pass", longitudinal
assert longitudinal["simulated"] is True and longitudinal["terminal_qualified"] is False, longitudinal
assert longitudinal["mode"] == "time-travel-30-day-fixture", longitudinal
assert longitudinal["exit_code"] == 0, longitudinal

adk = qualification["dependency_closure"]["agent_dev_kit"]
assert adk["status"] == "pass", adk
assert adk["repository"] == "jiying2007/agent-dev-kit", adk
assert adk["terminal_effect"] == "internal-dependency-closure-only", adk

readiness = qualification["terminal_readiness"]
assert readiness["engineering_control_plane"] == "pass", readiness
assert readiness["iteration_readiness"] == "ready", readiness
assert readiness["iteration_gates"] == [], readiness
assert readiness["qualification_status"] == "pending", readiness
assert readiness["pending_requirements"] == ["LTA-04"], readiness
assert readiness["rehearsal"] == "pass", readiness
assert readiness["rehearsal_simulated"] is True, readiness
assert readiness["rehearsal_terminal_qualified"] is False, readiness
assert readiness["simulated_evidence_counts_as_real"] is False, readiness

terminal = qualification["terminal"]
assert terminal["qualified"] is False, terminal
assert terminal["status"] == "qualification_pending", terminal
assert terminal["pending_requirements"] == ["LTA-04"], terminal
assert set(terminal["pending_requirements"]) == set(real["terminal_pending_requirements"]), (terminal, real)
PY

echo '[PASS] LTA v2 rehearsal preserves simulated/real separation without blocker compatibility state'
