#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS="$(mktemp)"
CHECK="$(mktemp)"
CERT="$(mktemp)"
trap 'rm -f "$STATUS" "$CHECK" "$CERT"' EXIT

bash "$ROOT/scripts/software-m5.sh" status --summary-json >"$STATUS"
bash "$ROOT/scripts/software-m5.sh" check --summary-json >"$CHECK"
bash "$ROOT/scripts/software-m5.sh" certify --summary-json >"$CERT"

python3 - "$STATUS" "$CHECK" "$CERT" "$ROOT" <<'PY'
import copy
import json
import sys
from pathlib import Path

from tools.codex_assets.software_m5_v3 import M5Error, _validate_policy

status = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
check = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
cert = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
root = Path(sys.argv[4])
policy = json.loads((root / "manifests/software_m5_policy.json").read_text(encoding="utf-8"))
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))

for value in (status, check, cert):
    assert value["integrity_status"] == "pass", value
    assert value["readiness_status"] == "m5-ready", value
    assert value["eligibility_status"] == "release-qualified", value
    assert value["certification_status"] == "pass", value
    assert value["software_m5_certified"] is True, value
    assert value["blocking_gates"] == [], value

assert check["declaration_status"] == "pass", check
assert cert["declaration_status"] == "pass", cert
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

assert cert["promotion"]["status"] == "pass", cert
assert cert["runtime"]["status"] == "pass", cert
assert cert["field"]["status"] == "pass", cert
assert cert["qualification_record"]["status"] == "pass", cert
assert cert["field"]["qualifying_events"], cert
PY

echo "[PASS] production-qualified Software M5 certifier passes real solo-maintainer evidence and rejects floor weakening"
