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
assert value["software"]["portable_managed_verifier_available"] is True, value
assert value["software"]["sigstore_blob_verifier_available"] is True, value
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
import stat
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from agent_dev_kit.agent_value import emit_measurements
from agent_dev_kit.agent_value_contracts import load_contract
from agent_dev_kit.agent_value_trust import build_portable_managed_agent_value_evidence_verifier
from agent_dev_kit.effect_trials import compare_effect_trials
from agent_dev_kit.model import Manifest, canonical_json_bytes, sha256_bytes
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

manifest_json=json.loads((adk/"manifest.json").read_text(encoding="utf-8"))
assets=set()
asset_refs={}
for asset in manifest.all_assets("agent"):
    assets.add(("agent",asset.name))
    asset_refs[("agent",asset.name)]="ref:"+asset.digest
for asset in manifest.all_assets("skill"):
    assets.add(("skill",asset.name))
    asset_refs[("skill",asset.name)]="ref:"+asset.digest
for name,value in manifest_json["profiles"].items():
    assets.add(("profile",name))
    asset_refs[("profile",name)]="ref:"+sha256_bytes(canonical_json_bytes(value))
assert assets

control_artifacts={
    "environment":{"schema":"fixture-control/v1","name":"environment","value":"ubuntu-24.04"},
    "tool_policy":{"schema":"fixture-control/v1","name":"tool-policy","value":"read-write-bounded"},
    "grader":{"schema":"fixture-control/v1","name":"grader","value":"deterministic-routing-v1"},
    "dataset":{"schema":"fixture-control/v1","name":"dataset","value":"effect-readiness-fixture"},
    "parameters":{"schema":"fixture-control/v1","name":"parameters","value":{"temperature":0}},
    "provider":{"schema":"fixture-control/v1","name":"provider","value":"fixture-provider"},
}
control_fields={
    "environment":"environment_ref",
    "tool_policy":"tool_policy_ref",
    "grader":"grader_ref",
    "dataset":"dataset_ref",
    "parameters":"parameters_ref",
    "provider":"provider_ref",
}
for name,field in control_fields.items():
    campaign["plan"]["controls"][field]="ref:"+sha256_bytes(canonical_json_bytes(control_artifacts[name]))

candidate_assets=[
    {"asset_kind":kind,"asset_id":asset_id,"content_ref":asset_refs[(kind,asset_id)]}
    for kind,asset_id in sorted(assets)
]
bundle_manifests={
    "baseline":{
        "schema":"llm-agent-effect-bundle-manifest/v1",
        "condition":"baseline",
        "runtime_target":campaign["plan"]["controls"]["runtime_target"],
        "assets":[],
        "metadata":{"mode":"no-adk-assets"},
        "raw_content_stored":False,
        "release_authorized":False,
    },
    "candidate":{
        "schema":"llm-agent-effect-bundle-manifest/v1",
        "condition":"candidate",
        "runtime_target":campaign["plan"]["controls"]["runtime_target"],
        "assets":candidate_assets,
        "metadata":{"mode":"pinned-current-adk-assets","adk_version":manifest.version},
        "raw_content_stored":False,
        "release_authorized":False,
    },
}
for side in ("baseline","candidate"):
    digest=sha256_bytes(canonical_json_bytes(bundle_manifests[side]))
    campaign["plan"]["bundles"][side]=digest
    for trial in campaign["trials"]:
        for binding in trial[side]:
            binding["run"]["trace_summary"]["asset_bundle_sha256"]=digest
fixture.rebind(campaign)

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

preregistration_package={
    "schema":"llm-agent-effect-preregistration-package/v2",
    "status":"frozen",
    "plan":campaign["plan"],
    "controls":control_artifacts,
    "bundles":bundle_manifests,
    "raw_content_stored":False,
    "provider_execution_performed":False,
    "release_authorized":False,
}
preregistration_package_path=fixture_dir/"preregistration-package.json"
preregistration_package_path.write_bytes(canonical_json_bytes(preregistration_package))
preregistration_registered_at=datetime(2026,9,24,9,0,tzinfo=timezone.utc)
preregistration_bundle_path=fixture_dir/"preregistration.sigstore.json"
preregistration_bundle_path.write_text(
    json.dumps({
        "verificationMaterial":{
            "tlogEntries":[{
                "integratedTime":str(int(preregistration_registered_at.timestamp()))
            }]
        }
    },sort_keys=True)+"\n",
    encoding="utf-8",
)

now=datetime.now(timezone.utc).replace(microsecond=0)
window_from=now-timedelta(hours=2)
window_through=now-timedelta(minutes=1)
receipt_signed_at=now-timedelta(seconds=10)

contract=load_contract(adk/"manifests/agent_value_contracts.json")
contract=json.loads(json.dumps(contract))
contract["evidence_authority_policy"]={
    "managed":True,
    "status":"enabled",
    "backend":"ci-provenance-verifier",
    "authorities":[{
        "authority_id":"agent-value-ci",
        "backend":"ci-provenance-verifier",
        "allowed_layers":["runtime"],
        "runtime_targets":[campaign_runtime_target],
        "production":False,
    }],
}
contract_path=fixture_dir/"authority-contract.json"
contract_path.write_text(
    json.dumps(contract,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

cosign=fixture_dir/"cosign"
cosign.write_text(
    "#!/usr/bin/env python3\n"
    "import pathlib,sys\n"
    "a=sys.argv[1:]\n"
    "blob=sys.stdin.buffer.read()\n"
    "ok=(len(a)==8 and a[0]=='verify-blob' and a[1]=='--bundle' "
    "and a[3]=='--certificate-identity' and a[5]=='--certificate-oidc-issuer' "
    "and pathlib.Path(a[2]).is_file() and a[7]=='/dev/stdin' and len(blob)>0)\n"
    "sys.exit(0 if ok else 97)\n",
    encoding="utf-8",
)
cosign.chmod(cosign.stat().st_mode | stat.S_IXUSR)
bundle=fixture_dir/"receipt.sigstore.json"
bundle.write_text(
    json.dumps({
        "verificationMaterial":{
            "tlogEntries":[{"integratedTime":str(int(receipt_signed_at.timestamp()))}]
        }
    },sort_keys=True)+"\n",
    encoding="utf-8",
)
manifest_ref=opaque_ref_for_sha256(manifest.digest)

receipts=[]
receipt_index=0
for kind,asset_id in sorted(assets):
    for case in ("success","failure","abstain"):
        token=f"{kind}:{asset_id}:{case}:{receipt_index}"
        trace_ref=campaign_trace_refs[receipt_index % len(campaign_trace_refs)]
        bundle_sha=campaign_bundles[receipt_index % len(campaign_bundles)]
        observed=window_from+timedelta(seconds=receipt_index+1)
        payload={
            "schema_version":"adk-asset-invocation-receipt/v1",
            "invocation_ref":ref(token+":invocation"),
            "source_trace_ref":trace_ref,
            "manifest_ref":manifest_ref,
            "asset_bundle_sha256":bundle_sha,
            "runtime_target":campaign_runtime_target,
            "evidence_layer":"runtime",
            "observed_at":observed.isoformat().replace("+00:00","Z"),
            "measurement_status":"measured",
            "asset_id":asset_id,
            "asset_kind":kind,
            "human_interventions":0 if case!="failure" else 1,
            "retirement_signal":"retain",
            "evidence_refs":[ref(token+":evidence")],
            "privacy_status":"sanitized",
            "raw_content_stored":False,
        }
        if case=="success":
            payload["routing"]={"routed":True,"abstained":False,"wrong_route":False}
            payload["outcome"]="succeeded"
            payload["first_pass"]=True
            payload["time_to_trustworthy_change_ms"]=100
        elif case=="failure":
            payload["routing"]={"routed":True,"abstained":False,"wrong_route":True}
            payload["outcome"]="failed"
            payload["first_pass"]=False
            payload["time_to_trustworthy_change_ms"]=200
        else:
            payload["routing"]={"routed":False,"abstained":True,"wrong_route":False}
            payload["outcome"]="abstained"
            payload["abstain_correct"]=True
        body_sha=sha256_bytes(canonical_json_bytes(payload))
        receipt=dict(payload)
        receipt["authority_attestation"]={
            "authority_id":"agent-value-ci",
            "body_sha256":body_sha,
            "manifest_ref":manifest_ref,
            "asset_bundle_sha256":bundle_sha,
            "evidence_layer":"runtime",
            "runtime_target":campaign_runtime_target,
            "source_trace_ref":trace_ref,
        }
        receipt["receipt_id"]=opaque_ref_for_sha256(
            sha256_bytes(canonical_json_bytes(receipt))
        )
        receipts.append(receipt)
        receipt_index+=1

bundle_sha=hashlib.sha256(bundle.read_bytes()).hexdigest()
binary_sha=hashlib.sha256(cosign.read_bytes()).hexdigest()
registry={
    "schema":"adk-agent-value-trust-registry/v1",
    "status":"active",
    "authority_model":"owner-reviewed-managed-registry",
    "authorities":{
        "agent-value-ci":{
            "enabled":True,
            "policy_backend":"ci-provenance-verifier",
            "verifier":"sigstore-cosign-blob",
            "allowed_layers":["runtime"],
            "runtime_targets":[campaign_runtime_target],
            "certificate_identity":"https://github.com/example/repo/.github/workflows/value.yml@refs/heads/main",
            "certificate_oidc_issuer":"https://token.actions.githubusercontent.com",
            "cosign_binary":str(cosign.resolve()),
            "cosign_binary_sha256":binary_sha,
            "receipts":{
                receipt["receipt_id"]:{
                    "receipt_canonical_sha256":hashlib.sha256(
                        canonical_json_bytes(receipt)
                    ).hexdigest(),
                    "bundle_path":bundle.relative_to(fixture_dir).as_posix(),
                    "bundle_sha256":bundle_sha,
                }
                for receipt in receipts
            },
        }
    },
}
registry_path=fixture_dir/"authority-registry.json"
registry_path.write_text(
    json.dumps(registry,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
receipt_set={
    "schema":"llm-agent-effect-receipt-set/v1",
    "aggregation_window":{
        "from":window_from.isoformat().replace("+00:00","Z"),
        "through":window_through.isoformat().replace("+00:00","Z"),
    },
    "as_of":now.isoformat().replace("+00:00","Z"),
    "receipts":receipts,
}
receipts_path=fixture_dir/"receipts.json"
receipts_path.write_text(
    json.dumps(receipt_set,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

verifier=build_portable_managed_agent_value_evidence_verifier(
    manifest,contract,registry,bundle_root=fixture_dir
)
measurement=emit_measurements(
    receipts,
    manifest,
    contract,
    evidence_verifier=verifier,
    aggregation_window={"from":window_from,"through":window_through},
    as_of=now,
)
assert measurement["measurement_status"]=="measured", measurement
assert measurement["evidence_scope"]=="runtime-verified", measurement
assert len(measurement["asset_measurements"])==len(assets), measurement
measurement_path=fixture_dir/"measurement.json"
measurement_path.write_text(
    json.dumps(measurement,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

review={
    "schema":"llm-agent-effect-owner-review/v5",
    "status":"approved",
    "campaign_id":comparison["campaign_id"],
    "campaign_sha256":sha(campaign_path),
    "comparison_sha256":sha(comparison_path),
    "authority_contract_sha256":sha(contract_path),
    "authority_registry_sha256":sha(registry_path),
    "receipts_sha256":sha(receipts_path),
    "measurement_sha256":sha(measurement_path),
    "preregistration_package_sha256":sha(preregistration_package_path),
    "preregistration_bundle_sha256":sha(preregistration_bundle_path),
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
    "schema":"llm-agent-effect-value-evidence-index/v5",
    "status":"active",
    "entries":[{
        "id":comparison["campaign_id"],
        "campaign_path":relative(campaign_path),
        "campaign_sha256":sha(campaign_path),
        "preregistration_package_path":relative(preregistration_package_path),
        "preregistration_package_sha256":sha(preregistration_package_path),
        "preregistration_bundle_path":relative(preregistration_bundle_path),
        "preregistration_bundle_sha256":sha(preregistration_bundle_path),
        "comparison_path":relative(comparison_path),
        "comparison_sha256":sha(comparison_path),
        "authority_contract_path":relative(contract_path),
        "authority_contract_sha256":sha(contract_path),
        "authority_registry_path":relative(registry_path),
        "authority_registry_sha256":sha(registry_path),
        "receipts_path":relative(receipts_path),
        "receipts_sha256":sha(receipts_path),
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

# Negative 1: an aggregate measurement cannot be hand-edited after signed receipt replay.
tampered_measurement=json.loads(json.dumps(measurement))
tampered_measurement["asset_measurements"][0]["metrics"]["task-success-rate"]["value"]=0.123
tampered_measurement_path=fixture_dir/"tampered-measurement.json"
tampered_measurement_path.write_text(
    json.dumps(tampered_measurement,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
tampered_review=json.loads(json.dumps(review))
tampered_review["measurement_sha256"]=sha(tampered_measurement_path)
tampered_review_path=fixture_dir/"tampered-owner-review.json"
tampered_review_path.write_text(
    json.dumps(tampered_review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
tampered_index=json.loads(json.dumps(index))
tampered_entry=tampered_index["entries"][0]
tampered_entry["measurement_path"]=relative(tampered_measurement_path)
tampered_entry["measurement_sha256"]=sha(tampered_measurement_path)
tampered_entry["owner_review_path"]=relative(tampered_review_path)
tampered_entry["owner_review_sha256"]=sha(tampered_review_path)
tampered_index_path=fixture_dir/"tampered-index.json"
tampered_index_path.write_text(
    json.dumps(tampered_index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

# Negative 2: changing one signed receipt body without changing the reviewed
# registry's canonical digest must fail in the ADK managed verifier.
forged_receipt_set=json.loads(json.dumps(receipt_set))
forged_receipt_set["receipts"][0]["outcome"]="failed"
forged_receipts_path=fixture_dir/"forged-receipts.json"
forged_receipts_path.write_text(
    json.dumps(forged_receipt_set,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
forged_review=json.loads(json.dumps(review))
forged_review["receipts_sha256"]=sha(forged_receipts_path)
forged_review_path=fixture_dir/"forged-owner-review.json"
forged_review_path.write_text(
    json.dumps(forged_review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
forged_index=json.loads(json.dumps(index))
forged_entry=forged_index["entries"][0]
forged_entry["receipts_path"]=relative(forged_receipts_path)
forged_entry["receipts_sha256"]=sha(forged_receipts_path)
forged_entry["owner_review_path"]=relative(forged_review_path)
forged_entry["owner_review_sha256"]=sha(forged_review_path)
forged_index_path=fixture_dir/"forged-index.json"
forged_index_path.write_text(
    json.dumps(forged_index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)

# Negative 3: an automated placeholder cannot stand in for the human owner.
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

# Negative 4: a plan signed after the first managed observation cannot be
# backfilled into a campaign by editing registered_at text.
late_bundle_path=fixture_dir/"late-preregistration.sigstore.json"
late_registered=window_from+timedelta(minutes=1)
late_bundle_path.write_text(
    json.dumps({
        "verificationMaterial":{
            "tlogEntries":[{"integratedTime":str(int(late_registered.timestamp()))}]
        }
    },sort_keys=True)+"\n",
    encoding="utf-8",
)
late_review=json.loads(json.dumps(review))
late_review["preregistration_bundle_sha256"]=sha(late_bundle_path)
late_review_path=fixture_dir/"late-preregistration-owner-review.json"
late_review_path.write_text(
    json.dumps(late_review,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
    encoding="utf-8",
)
late_index=json.loads(json.dumps(index))
late_entry=late_index["entries"][0]
late_entry["preregistration_bundle_path"]=relative(late_bundle_path)
late_entry["preregistration_bundle_sha256"]=sha(late_bundle_path)
late_entry["owner_review_path"]=relative(late_review_path)
late_entry["owner_review_sha256"]=sha(late_review_path)
late_index_path=fixture_dir/"late-preregistration-index.json"
late_index_path.write_text(
    json.dumps(late_index,ensure_ascii=False,sort_keys=True,indent=2)+"\n",
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
assert value["software"]["portable_managed_verifier_available"] is True, value
assert value["effect_evidence_ready"] is True, value
assert value["blockers"]==[], value
index=value["evidence_index"]
assert index["entry_count"]==1, index
assert index["full_asset_coverage"] is True, index
assert index["covered_asset_count"]==index["expected_asset_count"], index
assert index["owner_decision_count"]==index["expected_asset_count"], index
assert index["entries"][0]["comparison_verdict"]=="improved", index
assert index["entries"][0]["managed_campaign_trace_coverage"] is True, index
assert index["entries"][0]["signed_receipt_replay"] is True, index
assert index["entries"][0]["preregistration_verified"] is True, index
assert index["entries"][0]["preregistered_at"], index
assert index["entries"][0]["verified_receipt_count"]>index["expected_asset_count"], index
assert index["entries"][0]["campaign_trace_count"]>0, index
assert index["entries"][0]["reviewed_by"]=="fixture-human-owner", index
assert value["release_authorized"] is False, value
PY

for BAD in tampered-index.json forged-index.json automated-index.json late-preregistration-index.json; do
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

WORKFLOW="$ROOT/.github/workflows/effect-preregister.yml"
grep -Fq 'REGISTER_REAL_EFFECT_PLAN' "$WORKFLOW"
grep -Fq 'id-token: write' "$WORKFLOW"
grep -Fq 'cosign sign-blob' "$WORKFLOW"
grep -Fq 'provider_execution_performed":False' "$WORKFLOW"
if grep -Eq 'ANTHROPIC_API_KEY|OPENAI_API_KEY|claude -p|codex exec' "$WORKFLOW"; then
  echo '[FAIL] effect preregistration workflow must not execute a provider/model' >&2
  exit 1
fi

echo '[PASS] effect readiness requires cryptographic preregistration, signed receipt replay, recomputed measurement, campaign provenance, and real owner review'
