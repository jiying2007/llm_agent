#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT:$ROOT/agent-dev-kit/src${PYTHONPATH:+:$PYTHONPATH}"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

python3 - "$ROOT" "$TMP/source.json" <<'PY'
import json,sys
from pathlib import Path
from agent_dev_kit.model import Manifest, canonical_json_bytes, sha256_bytes
root=Path(sys.argv[1]).resolve()
out=Path(sys.argv[2])
manifest=Manifest.load(root/"agent-dev-kit")
agent=next(iter(manifest.all_assets("agent")))
profiles=manifest.data.get("profiles",{})
profile_name=sorted(profiles)[0]
profile_ref="ref:"+sha256_bytes(canonical_json_bytes(profiles[profile_name]))
controls={
    "environment":{"schema":"g22-control/v1","name":"environment","value":"ubuntu-24.04"},
    "tool_policy":{"schema":"g22-control/v1","name":"tool-policy","value":"read-only-no-tools"},
    "grader":{"schema":"g22-control/v1","name":"grader","value":"routing-safety-v1"},
    "dataset":{"schema":"g22-control/v1","name":"dataset","value":"fixture-two-task"},
    "parameters":{"schema":"g22-control/v1","name":"parameters","value":{"temperature":0}},
    "provider":{"schema":"g22-control/v1","name":"provider","value":"anthropic-api"},
}
runtime_target="claude"
baseline_assets=[{"asset_kind":"profile","asset_id":profile_name,"content_ref":profile_ref}]
candidate_assets=[*baseline_assets,{"asset_kind":"agent","asset_id":agent.name,"content_ref":"ref:"+agent.digest}]
source={
    "schema":"llm-agent-effect-preregistration-source/v1",
    "status":"draft",
    "plan":{
        "campaign_id":"g22-builder-fixture",
        "registered_at":"2020-01-01T00:00:00Z",
        "window":{"from":"2020-01-01T01:00:00Z","through":"2020-01-01T02:00:00Z","as_of":"2020-01-01T03:00:00Z"},
        "task_ids":["task-a","task-b"],
        "trial_ids":["trial-1","trial-2"],
        "controls":{
            "runtime_target":runtime_target,
            "runtime_version":"2.1.278",
            "model_version":"claude-haiku-4-5-20251001",
            "prompt_version":"adk-runtime-routing-v1",
            "orchestration_mode":"single-agent",
            "model_identity":"revision-bound",
        },
        "policy":{
            "primary_metric":"latency-per-task-ms",
            "minimum_effect":0,
            "noninferiority_margin":0,
            "guardrails":{"task-success-rate":0,"wrong-skill-rate":0},
            "minimum_tasks":2,
            "minimum_trials":2,
            "bootstrap_samples":100,
            "bootstrap_seed":42,
            "confidence":0.95,
        },
    },
    "controls":controls,
    "bundles":{
        "baseline":{"schema":"llm-agent-effect-bundle-manifest/v1","condition":"baseline","runtime_target":runtime_target,"assets":baseline_assets,"metadata":{"mode":"baseline-fixture"},"raw_content_stored":False,"release_authorized":False},
        "candidate":{"schema":"llm-agent-effect-bundle-manifest/v1","condition":"candidate","runtime_target":runtime_target,"assets":candidate_assets,"metadata":{"mode":"candidate-fixture"},"raw_content_stored":False,"release_authorized":False},
    },
    "raw_content_stored":False,
    "provider_execution_performed":False,
    "release_authorized":False,
}
out.write_text(json.dumps(source,sort_keys=True,indent=2)+"\n",encoding="utf-8")
PY

python3 -m tools.control_plane.effect_preregistration_package --adk "$ROOT/agent-dev-kit" --source "$TMP/source.json" --output "$TMP/package.json" --summary-json >"$TMP/build.json"

python3 - "$TMP/source.json" "$TMP/package.json" "$TMP/build.json" <<'PY'
import hashlib,json,sys
from agent_dev_kit.model import canonical_json_bytes
source=json.load(open(sys.argv[1],encoding="utf-8"))
package=json.load(open(sys.argv[2],encoding="utf-8"))
summary=json.load(open(sys.argv[3],encoding="utf-8"))
assert package["schema"]=="llm-agent-effect-preregistration-package/v2", package
assert package["status"]=="frozen", package
assert summary["status"]=="pass", summary
assert summary["source_schema"]=="llm-agent-effect-preregistration-source/v1", summary
bindings={"environment":"environment_ref","tool_policy":"tool_policy_ref","grader":"grader_ref","dataset":"dataset_ref","parameters":"parameters_ref","provider":"provider_ref"}
for name,field in bindings.items():
    expected="ref:"+hashlib.sha256(canonical_json_bytes(source["controls"][name])).hexdigest()
    assert package["plan"]["controls"][field]==expected,(field,package["plan"]["controls"][field],expected)
for side in ("baseline","candidate"):
    expected=hashlib.sha256(canonical_json_bytes(source["bundles"][side])).hexdigest()
    assert package["plan"]["bundles"][side]==expected,(side,package["plan"]["bundles"][side],expected)
    assert summary["bundle_sha256"][side]==expected,summary
assert hashlib.sha256(canonical_json_bytes(package)).hexdigest()==summary["package_sha256"],summary
PY

python3 -m tools.control_plane.effect_preregistration_package --adk "$ROOT/agent-dev-kit" --package "$TMP/package.json" --summary-json >/dev/null

set +e
python3 -m tools.control_plane.effect_preregistration_package --adk "$ROOT/agent-dev-kit" --source "$TMP/source.json" --output "$TMP/package.json" --summary-json >/dev/null
rc=$?
set -e
test "$rc" -eq 1

python3 - "$TMP/source.json" "$TMP/derived-ref.json" "$TMP/bad-content.json" "$TMP/same-assets.json" <<'PY'
import json,sys
src=json.load(open(sys.argv[1],encoding="utf-8"))
derived=json.loads(json.dumps(src)); derived["plan"]["controls"]["environment_ref"]="ref:"+"0"*64
json.dump(derived,open(sys.argv[2],"w",encoding="utf-8"),sort_keys=True)
bad=json.loads(json.dumps(src)); bad["bundles"]["candidate"]["assets"][-1]["content_ref"]="ref:"+"f"*64
json.dump(bad,open(sys.argv[3],"w",encoding="utf-8"),sort_keys=True)
same=json.loads(json.dumps(src)); same["bundles"]["candidate"]["assets"]=json.loads(json.dumps(same["bundles"]["baseline"]["assets"]))
json.dump(same,open(sys.argv[4],"w",encoding="utf-8"),sort_keys=True)
reordered=json.loads(json.dumps(src))
reordered["bundles"]["baseline"]["assets"]=list(reversed(json.loads(json.dumps(reordered["bundles"]["candidate"]["assets"]))))
json.dump(reordered,open(sys.argv[5],"w",encoding="utf-8"),sort_keys=True)
PY

for BAD in derived-ref bad-content same-assets reordered-same-assets; do
  set +e
  python3 -m tools.control_plane.effect_preregistration_package --adk "$ROOT/agent-dev-kit" --source "$TMP/${BAD}.json" --output "$TMP/${BAD}.out.json" --summary-json >/dev/null
  rc=$?
  set -e
  test "$rc" -eq 1
done

echo "[PASS] G22 preregistration builder derives refs/digests from source content and fails closed on drift"
