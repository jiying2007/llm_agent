#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS="$(mktemp)"
CHECK="$(mktemp)"
CERT="$(mktemp)"
trap 'rm -f "$STATUS" "$CHECK" "$CERT"' EXIT

set +e
bash "$ROOT/scripts/software-m5.sh" status --summary-json >"$STATUS"
STATUS_RC=$?
bash "$ROOT/scripts/software-m5.sh" check --summary-json >"$CHECK"
CHECK_RC=$?
bash "$ROOT/scripts/software-m5.sh" certify --summary-json >"$CERT"
CERT_RC=$?
set -e

python3 - "$STATUS" "$CHECK" "$CERT" "$ROOT" "$STATUS_RC" "$CHECK_RC" "$CERT_RC" <<'PY'
import copy
import json
import sys
from pathlib import Path

from tools.codex_assets.software_m5_v3 import M5Error
from tools.codex_assets.software_m5_v3_core import _validate_policy

status = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
check = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
cert = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
root = Path(sys.argv[4])
status_rc, check_rc, cert_rc = map(int, sys.argv[5:8])
policy = json.loads((root / "manifests/software_m5_policy.json").read_text(encoding="utf-8"))
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))

assert status_rc != 0 and check_rc != 0 and cert_rc != 0, (status_rc, check_rc, cert_rc)
for value in (status, check, cert):
    assert value["integrity_status"] == "fail", value
    assert value["readiness_status"] == "not-ready", value
    assert value["eligibility_status"] == "blocked", value
    assert value["certification_status"] == "blocked", value
    assert value["software_m5_certified"] is False, value
    assert value["blocking_gates"] == ["evidence_integrity"], value
    assert "promotion evidence source.version does not match current candidate" in value["error"], value

for value in (check, cert):
    assert value["declaration_status"] == "fail", value
    assert value["declaration_failures"], value
assert policy["schema"] == "llm-agent-software-m5-policy/v3", policy
assert policy["definition"] == "production-qualified", policy
assert policy["field_qualification"]["minimum_human_operators"] == 1, policy
assert policy["operational_advisories"]["second_human_operator"] is False, policy
assert scorecard["overall"]["level"] == "M5", scorecard
assert scorecard["overall"]["terminal_mature"] is True, scorecard
assert scorecard["software_m5"]["certified"] is True, scorecard

mutations = []
p = copy.deepcopy(policy); p["rules"]["signed_promotion_required"] = False; mutations.append(p)
p = copy.deepcopy(policy); p["field_qualification"]["minimum_independent_repositories"] = 0; mutations.append(p)
p = copy.deepcopy(policy); p["field_qualification"]["minimum_human_operators"] = 0; mutations.append(p)
p = copy.deepcopy(policy); p["runtime_qualification"]["minimum_measured_runtimes"] = 0; mutations.append(p)
p = copy.deepcopy(policy); p["operational_advisories"]["recommended_observation_days"] = 0; mutations.append(p)
p = copy.deepcopy(policy); p["operational_advisories"]["second_human_operator"] = True; mutations.append(p)
for candidate in mutations:
    try:
        _validate_policy(candidate)
    except M5Error:
        pass
    else:
        raise AssertionError("weakened or non-solo policy mutation unexpectedly passed")

assert scorecard["software_m5"]["certified"] is True, scorecard
assert scorecard["software_m5"]["certification_status"] == "pass", scorecard
PY

echo "[PASS] historical Software M5 baseline is preserved while current 7.x source certification fails closed"
