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
qualification = json.loads((root / "manifests/long_term_asset_qualification.json").read_text(encoding="utf-8"))
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

adk = qualification["dependency_closure"]["agent_dev_kit"]
assert adk["status"] == "pass", adk
assert adk["repository"] == "jiying2007/agent-dev-kit", adk
assert adk["authoritative_main"] == "6a05d0ef873553a5098679ad57a3b52b45e0d492", adk
assert adk["governance_issue"] == 79, adk
assert adk["governance_issue_state"] == "closed/completed", adk
assert adk["ruleset_id"] == 23394761, adk
assert adk["strict_required_status_checks_policy"] is True, adk
assert adk["stale_base_acceptance_status"] == "pass", adk
assert adk["acceptance_merge_main"] == "d8d75a229762b18eaf0db3af0467a6addccda569", adk
assert adk["finalization_pr"] == 83, adk
assert adk["fresh_main_ci_run"] == 35055426461, adk
assert adk["fresh_main_branch_gc_run"] == 35055426349, adk
assert adk["fresh_main_codeql_run"] == 35055426374, adk
assert adk["fresh_main_platform_vnext_run"] == 35055426733, adk
assert adk["promotion_job_id"] == 104665310429, adk
assert adk["promotion_artifact_id"] == 10430631584, adk
assert adk["promotion_artifact_sha256"] == "f56851a19d7d18d7787d088408bc7d812e44adf56f69c73479869aa139277136", adk
assert adk["terminal_effect"] == "internal-dependency-closure-only", adk

readiness = qualification["terminal_readiness"]
assert readiness["engineering_control_plane"] == "pass", readiness
assert readiness["rehearsal"] == "pass", readiness
assert set(readiness["rehearsal_scope"]) == {"LTA-02", "LTA-04"}, readiness
assert readiness["rehearsal_command"] == "python3 -m tools.control_plane.cli long-term-rehearsal --scope all --summary-json", readiness
assert readiness["rehearsal_simulated"] is True, readiness
assert readiness["rehearsal_terminal_qualified"] is False, readiness
assert readiness["simulated_evidence_counts_as_real"] is False, readiness
assert readiness["real_qualification"] == "blocked", readiness
assert set(readiness["real_blockers"]) == {"LTA-02", "LTA-04"}, readiness
assert set(readiness["real_blockers"]) == set(qualification["terminal"]["blockers"]), (readiness, qualification["terminal"])
assert qualification["terminal"]["qualified"] is False, qualification["terminal"]
assert qualification["terminal"]["status"] == "blocked", qualification["terminal"]
assert set(readiness["real_blockers"]) == set(real["terminal_blockers"]), (readiness, real)
PY

echo '[PASS] long-term rehearsal and terminal-readiness projection preserve simulated/real separation with ADK dependency closure'
