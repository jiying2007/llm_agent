#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.effect_readiness --root . --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["schema"]=="llm-agent-effect-readiness/v1", value
assert value["status"]=="pass", value
assert value["software_ready"] is True, value
assert value["release_authorized"] is False, value
assert value["measurement_baseline"]["measurement_status"]=="not-measured", value
assert value["measurement_baseline"]["reason"]=="no-valid-receipts", value
assert value["measurement_baseline"]["asset_measurement_count"]==0, value
assert value["software"]["missing_contract_ids"]==[], value
assert value["software"]["schema_failures"]==[], value
assert value["software"]["missing_files"]==[], value
assert value["authority"]["registry_status"]=="active", value
assert value["effect_evidence_ready"] is False, value
assert value["terminal_status"]=="blocked-external-evidence", value
assert any("real-repeated-task-trials" in item for item in value["blockers"]), value
assert any("runtime-or-field-invocation-receipts" in item for item in value["blockers"]), value
boundary=value["authority_boundary"]
assert boundary["synthetic_trials_are_real_effect_evidence"] is False, boundary
assert boundary["test_receipts_are_runtime_or_field_evidence"] is False, boundary
assert boundary["software_ready_is_effectiveness_proof"] is False, boundary
assert boundary["retirement_signal_is_lifecycle_authority"] is False, boundary
PY

set +e
python3 -m tools.control_plane.effect_readiness --root . --require-evidence --summary-json >/dev/null
rc=$?
set -e
test "$rc" -eq 2

python3 -m tools.control_plane.cli effect-readiness --root . --summary-json   | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["status"]=="pass" and v["software_ready"] is True and v["effect_evidence_ready"] is False, v'

echo '[PASS] effect readiness separates landed software from missing real value evidence'
