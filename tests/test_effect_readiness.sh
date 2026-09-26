#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
mkdir -p "$ROOT/tests/fixtures"
FIXTURE_DIR="$(mktemp -d -p "$ROOT/tests/fixtures" effect-readiness-XXXXXX)"
cleanup() {
  rm -f "$TMP"
  rm -rf "$FIXTURE_DIR"
}
trap cleanup EXIT

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
assert value["safe_defaults"]["registry_status"]=="active", value
assert value["evidence_index"]["entry_count"]==0, value
assert value["evidence_index"]["covered_asset_count"]==0, value
assert value["effect_evidence_ready"] is False, value
assert value["terminal_status"]=="blocked-external-evidence", value
assert any("governed-effect-evidence-index-entry" in item for item in value["blockers"]), value
boundary=value["authority_boundary"]
assert boundary["synthetic_trials_are_real_effect_evidence"] is False, boundary
assert boundary["test_receipts_are_runtime_or_field_evidence"] is False, boundary
assert boundary["software_ready_is_effectiveness_proof"] is False, boundary
assert boundary["retirement_signal_is_lifecycle_authority"] is False, boundary
assert boundary["owner_review_executes_retirement"] is False, boundary
assert boundary["ready_authorizes_release"] is False, boundary
PY

set +e
python3 -m tools.control_plane.effect_readiness --root . --require-evidence --summary-json >/dev/null
rc=$?
set -e
test "$rc" -eq 2

export PYTHONPATH="$ROOT/agent-dev-kit/src${PYTHONPATH:+:$PYTHONPATH}"
python3 - "$ROOT" "$FIXTURE_DIR" <<'PY'
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from agent_dev_kit.effect_trials import compare_effect_trials
from agent_dev_kit.model import Manifest
from agent_dev_kit.privacy_ref import opaque_ref_for_sha256

root=Path(sys.argv[1]).resolve()
fixture_dir=Path(sys.argv[2]).resolve()
adk=root/"agent-dev-kit"
manifest=Manifest.load(adk)

spec=importlib.util.spec_from_file_location(
    "adk_effect_trial_fixture", adk/"tests/test_effect_trials.py"
)
assert spec and spec.loader
fixture=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
campaign=fixture.document()
comparison=compare_effect_trials(campaign, manifest)
assert comparison["verdict"]=="improved", comparison
campaign_path=fixture_dir/"campaign.json"
campaign_path.write_text(
    json.dumps(campaign,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
campaign_trace_refs=sorted({
    binding["run"]["trace_ref"]
    for trial in campaign["trials"]
    for side in ("baseline","candidate")
    for binding in trial[side]
})
assert len(campaign_trace_refs)==comparison["run_count"], (len(campaign_trace_refs),comparison)
campaign_bundles=sorted(campaign["plan"]["bundles"].values())
assert len(set(campaign_bundles))==2, campaign_bundles
campaign_runtime_target=campaign["plan"]["controls"]["runtime_target"]

comparison_path=fixture_dir/"comparison.json"
comparison_path.write_text(
    json.dumps(comparison,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

manifest_json=json.loads((adk/"manifest.json").read_text(encoding="utf-8"))
assets=set()
for key,kind in (("agents","agent"),("skills","skill"),("optional_skills","skill")):
    for item in manifest_json.get(key,[]):
        assets.add((kind,item["name"]))
for name in manifest_json["profiles"]:
    assets.add(("profile",name))
assert assets

def ref(seed: str) -> str:
    return opaque_ref_for_sha256(hashlib.sha256(seed.encode("utf-8")).hexdigest())

def metric(value: float, unit: str) -> dict:
    return {
        "status":"measured",
        "value":value,
        "sample_size":10,
        "applicable_sample_size":10,
        "observed_sample_size":10,
        "coverage":1.0,
        "unit":unit,
    }

now=datetime.now(timezone.utc).replace(microsecond=0)
start=now-timedelta(days=1)
asset_measurements=[]
for index,(kind,asset_id) in enumerate(sorted(assets)):
    token=f"{kind}:{asset_id}:{index}"
    asset_measurements.append({
        "asset_id":asset_id,
        "asset_kind":kind,
        "evidence_layer":"runtime",
        "source_verification":"managed-authority-verified",
        "measurement_status":"measured",
        "receipt_refs":[ref(token+":receipt")],
        "invocation_refs":[ref(token+":invocation")],
        "source_trace_refs":[campaign_trace_refs[index % len(campaign_trace_refs)]],
        "asset_bundle_sha256s":[campaign_bundles[index % len(campaign_bundles)]],
        "runtime_targets":[campaign_runtime_target],
        "authority_ids":["agent-value-ci"],
        "production_authority":False,
        "evidence_refs":[ref(token+":evidence")],
        "metrics":{
            "task-success-rate":metric(0.8,"ratio"),
            "first-pass-success-rate":metric(0.7,"ratio"),
            "wrong-route-rate":metric(0.1,"ratio"),
            "abstain-precision":metric(0.9,"ratio"),
            "human-interventions-per-task":metric(0.2,"count-per-task"),
            "time-to-trustworthy-change":metric(1200.0,"milliseconds"),
            "escaped-defect-rate":metric(0.05,"ratio"),
            "rollback-rate":metric(0.05,"ratio"),
        },
        "retirement_signals":["retain"],
        "retirement_authority":"signal-only-owner-decision-required",
        "observation_window":{
            "from":start.isoformat().replace("+00:00","Z"),
            "through":now.isoformat().replace("+00:00","Z"),
        },
    })

measurement={
    "schema_version":"adk-asset-value-measurement/v1",
    "measurement_status":"measured",
    "manifest_ref":opaque_ref_for_sha256(manifest.digest),
    "privacy_status":"opaque-refs-only",
    "raw_content_stored":False,
    "source_receipt_count":len(assets),
    "aggregation_window":{
        "from":start.isoformat().replace("+00:00","Z"),
        "through":now.isoformat().replace("+00:00","Z"),
    },
    "as_of":now.isoformat().replace("+00:00","Z"),
    "evidence_scope":"runtime-verified",
    "quality_evidence_eligible":False,
    "quality_ineligibility_reason":"non-production-authority",
    "owner_review_required":True,
    "lifecycle_authority":"none-evidence-only",
    "asset_measurements":asset_measurements,
}
measurement_path=fixture_dir/"measurement.json"
measurement_path.write_text(
    json.dumps(measurement,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

review={
    "schema":"llm-agent-effect-owner-review/v2",
    "status":"approved",
    "campaign_id":comparison["campaign_id"],
    "campaign_sha256":sha(campaign_path),
    "comparison_sha256":sha(comparison_path),
    "measurement_sha256":sha(measurement_path),
    "reviewed_at":now.isoformat().replace("+00:00","Z"),
    "reviewed_by":"fixture-human-owner",
    "reviewer_role":"owner",
    "automation_generated":False,
    "observed_cases":{
        "success":True,
        "failure":True,
        "wrong_route":True,
        "abstain":True,
    },
    "asset_decisions":[
        {"asset_id":asset_id,"asset_kind":kind,"decision":"retain"}
        for kind,asset_id in sorted(assets)
    ],
    "raw_content_stored":False,
    "release_authorized":False,
    "lifecycle_authority":"owner-review-recorded-execution-separate",
}
review_path=fixture_dir/"owner-review.json"
review_path.write_text(
    json.dumps(review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

relative=lambda path: path.relative_to(root).as_posix()
index={
    "schema":"llm-agent-effect-value-evidence-index/v2",
    "status":"active",
    "entries":[{
        "id":comparison["campaign_id"],
        "campaign_path":relative(campaign_path),
        "campaign_sha256":sha(campaign_path),
        "comparison_path":relative(comparison_path),
        "comparison_sha256":sha(comparison_path),
        "measurement_path":relative(measurement_path),
        "measurement_sha256":sha(measurement_path),
        "owner_review_path":relative(review_path),
        "owner_review_sha256":sha(review_path),
    }],
}
index_path=fixture_dir/"evidence-index.json"
index_path.write_text(
    json.dumps(index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

# Negative 1: a recomputable comparison cannot become terminal unless every
# campaign trace is backed by the managed runtime/field measurement.
unbound_measurement=json.loads(json.dumps(measurement))
for row_index,item in enumerate(unbound_measurement["asset_measurements"]):
    item["source_trace_refs"]=[ref(f"unbound:{row_index}")]
unbound_measurement_path=fixture_dir/"unbound-measurement.json"
unbound_measurement_path.write_text(
    json.dumps(unbound_measurement,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
unbound_review=json.loads(json.dumps(review))
unbound_review["measurement_sha256"]=sha(unbound_measurement_path)
unbound_review_path=fixture_dir/"unbound-owner-review.json"
unbound_review_path.write_text(
    json.dumps(unbound_review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
unbound_index=json.loads(json.dumps(index))
unbound_entry=unbound_index["entries"][0]
unbound_entry["measurement_path"]=relative(unbound_measurement_path)
unbound_entry["measurement_sha256"]=sha(unbound_measurement_path)
unbound_entry["owner_review_path"]=relative(unbound_review_path)
unbound_entry["owner_review_sha256"]=sha(unbound_review_path)
unbound_index_path=fixture_dir/"unbound-index.json"
unbound_index_path.write_text(
    json.dumps(unbound_index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

# Negative 2: an automated placeholder cannot stand in for the human owner.
automated_review=json.loads(json.dumps(review))
automated_review["automation_generated"]=True
automated_review_path=fixture_dir/"automated-owner-review.json"
automated_review_path.write_text(
    json.dumps(automated_review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
automated_index=json.loads(json.dumps(index))
automated_entry=automated_index["entries"][0]
automated_entry["owner_review_path"]=relative(automated_review_path)
automated_entry["owner_review_sha256"]=sha(automated_review_path)
automated_index_path=fixture_dir/"automated-index.json"
automated_index_path.write_text(
    json.dumps(automated_index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

print(relative(index_path))
PY

INDEX_REL="$(python3 - "$ROOT" "$FIXTURE_DIR" <<'PY'
import sys
from pathlib import Path
print((Path(sys.argv[2])/"evidence-index.json").resolve().relative_to(Path(sys.argv[1]).resolve()).as_posix())
PY
)"

python3 -m tools.control_plane.effect_readiness   --root . --evidence-index "$INDEX_REL" --require-evidence --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["status"]=="pass", value
assert value["terminal_status"]=="ready", value
assert value["software_ready"] is True, value
assert value["effect_evidence_ready"] is True, value
assert value["blockers"]==[], value
index=value["evidence_index"]
assert index["entry_count"]==1, index
assert index["full_asset_coverage"] is True, index
assert index["covered_asset_count"]==index["expected_asset_count"], index
assert index["owner_decision_count"]==index["expected_asset_count"], index
assert index["entries"][0]["comparison_verdict"]=="improved", index
assert index["entries"][0]["managed_campaign_trace_coverage"] is True, index
assert index["entries"][0]["campaign_trace_count"]>0, index
assert index["entries"][0]["reviewed_by"]=="fixture-human-owner", index
assert value["release_authorized"] is False, value
PY

for BAD in unbound-index.json automated-index.json; do
  BAD_REL="$(python3 - "$ROOT" "$FIXTURE_DIR" "$BAD" <<'PY'
import sys
from pathlib import Path
print((Path(sys.argv[2])/sys.argv[3]).resolve().relative_to(Path(sys.argv[1]).resolve()).as_posix())
PY
)"
  set +e
  python3 -m tools.control_plane.effect_readiness --root . --evidence-index "$BAD_REL" --require-evidence --summary-json >"$TMP"
  bad_rc=$?
  set -e
  test "$bad_rc" -eq 1
done

python3 -m tools.control_plane.cli effect-readiness --root . --summary-json   | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["status"]=="pass" and v["software_ready"] is True and v["effect_evidence_ready"] is False, v'

echo '[PASS] effect readiness requires recomputed campaign provenance, managed trace coverage, and real owner-review metadata'
