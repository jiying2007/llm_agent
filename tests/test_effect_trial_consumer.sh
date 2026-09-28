#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT/agent-dev-kit/src${PYTHONPATH:+:$PYTHONPATH}"
python3 - "$ROOT" <<'PY'
import importlib.util
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
root=Path(sys.argv[1]); adk=root/'agent-dev-kit'
from agent_dev_kit.campaign import campaign_plan
from agent_dev_kit.campaign_model import load_campaign_contract
from agent_dev_kit.effect_campaign_materializer import materialize_effect_campaign
for fn in (campaign_plan, load_campaign_contract, materialize_effect_campaign):
    assert callable(fn)
    assert 'campaign_root' in inspect.signature(fn).parameters, inspect.signature(fn)
for action in ('plan','run','check','materialize-effect'):
    help_run=subprocess.run([sys.executable,'-m','agent_dev_kit.cli','eval','campaign',action,'--help'],cwd=root,text=True,capture_output=True,timeout=30)
    assert help_run.returncode==0,(action,help_run.returncode,help_run.stdout,help_run.stderr)
    assert '--campaign-root' in help_run.stdout,(action,help_run.stdout)
materialize_help=subprocess.run([sys.executable,'-m','agent_dev_kit.cli','eval','campaign','materialize-effect','--help'],cwd=root,text=True,capture_output=True,timeout=30)
for flag in ('--contract','--state-dir','--effect-plan','--runtime','--output','--campaign-root'):
    assert flag in materialize_help.stdout,(flag,materialize_help.stdout)
certify_help=subprocess.run([sys.executable,'-m','agent_dev_kit.cli','eval','certify','--help'],cwd=root,text=True,capture_output=True,timeout=30)
assert certify_help.returncode==0,(certify_help.returncode,certify_help.stdout,certify_help.stderr)
assert '--campaign-root' in certify_help.stdout,certify_help.stdout
spec=importlib.util.spec_from_file_location('adk_effect_trial_fixture',adk/'tests/test_effect_trials.py')
assert spec and spec.loader
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
# This is a pinned synthetic software integration test, never a runtime campaign.
with tempfile.TemporaryDirectory(prefix='root-effect-trial-') as tmp:
    source=Path(tmp)/'input.json'
    def run(value, code, verdict):
        source.write_text(json.dumps(value),encoding='utf-8')
        done=subprocess.run([sys.executable,'-m','agent_dev_kit.cli',
            'eval','compare-trials','--input',str(source),'--summary-json'],
            cwd=root,text=True,capture_output=True,timeout=30)
        assert done.returncode == code, (done.returncode,done.stdout,done.stderr)
        result=json.loads(done.stdout)
        assert result['verdict']==verdict,result
        assert result['evidence_scope']=='test-only' and result['release_authorized'] is False,result
        assert result['lifecycle_authority']=='none-evidence-only',result
        return result
    value=fixture.document(); result=run(value,0,'improved')
    assert result['task_count']==6 and result['trials_per_task']==3 and result['run_count']==36,result
    value=fixture.document();value['plan']['controls']['model_identity']='alias-unverified';fixture.rebind(value)
    run(value,2,'inconclusive')
    value=fixture.document();value['trials'].pop();run(value,2,'invalid')
    value=fixture.document()
    for j,trial in enumerate(value['trials']):
        for i,binding in enumerate(trial['candidate']):
            binding['run']=fixture.fresh_run('candidate',i,j,elapsed_ms=150)
    fixture.rebind(value);run(value,1,'regressed')
print('[PASS] pinned ADK campaign-root + effect materializer surfaces are consumable; synthetic test only')
PY
