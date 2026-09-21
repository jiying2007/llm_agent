#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import re
from pathlib import Path

root = Path('.')
lta = json.loads((root / 'manifests/long_term_asset_qualification.json').read_text())
scorecard = json.loads((root / 'manifests/product_maturity_scorecard.json').read_text())
lock = json.loads((root / 'manifests/adk_interface.lock.json').read_text())
recovery_path = root / 'reports/long-term-assets/solo-maintainer-recovery-current.json'
recovery = json.loads(recovery_path.read_text())
runbook = root / 'docs/runbooks/solo-maintainer-continuity.md'

assert lta['schema'] == 'llm-agent-long-term-asset-qualification/v2'
assert lta['updated_at'] == '2026-09-21'
assert lta['rules'] == {
    'fail_closed': True,
    'no_simulated_external_evidence': True,
    'terminal_requires_all_qualification_requirements': True,
    'product_maturity_does_not_imply_long_term_terminal': True,
    'qualification_pending_does_not_block_iteration': True,
}

assert runbook.is_file()
runbook_text = runbook.read_text()
assert 'clean-room recovery drill' in runbook_text.lower()
assert 'issue #50' in runbook_text
assert 'second-human approval' in runbook_text.lower()

maintainer = lta['maintainer_model']
assert maintainer['type'] == 'solo'
assert maintainer['required_human_approvals'] == 0
assert maintainer['minimum_codeowners'] == 1
assert maintainer['human_redundancy_required'] is False
required_controls = {
    'pull-request-mediated-main-changes',
    'mandatory-automated-regression-and-security-gates',
    'fail-closed-machine-readable-evidence',
    'exact-source-and-release-identity',
    'immutable-signed-component-release',
    'clean-room-recovery-and-rollback-drill',
    'explicit-continuity-runbook',
}
assert required_controls <= set(maintainer['compensating_controls'])

assert lta['lifecycle']['llm_agent']['model'] == 'non-release-workspace'
assert lta['lifecycle']['llm_agent']['component_release_required'] is False
assert lta['lifecycle']['agent_dev_kit']['model'] == 'versioned-component'
assert lta['lifecycle']['agent_dev_kit']['component_release_required'] is True
assert 'current_release' not in lta['lifecycle']['agent_dev_kit']
assert lock['version']

iteration = lta['iteration_readiness']
assert iteration['development'] == 'ready'
assert iteration['integration'] == 'ready'
assert iteration['control_plane'] == 'ready'
assert iteration['iteration_gates'] == []
assert iteration['qualification_pending'] == ['LTA-04']

layers = {item['id']: item for item in lta['qualification_layers']}
assert layers['source-valid']['status'] == 'pass'
assert layers['release-qualified']['status'] == 'pass'
assert layers['product-qualified']['status'] == 'pass'
assert layers['runtime-conformant']['status'] == 'observer-aligned'
assert layers['long-term-asset-qualified']['status'] == 'qualification_pending'
assert layers['long-term-asset-qualified']['affects'] == ['long-term-asset-terminal-qualification']

requirements = {item['id']: item for item in lta['qualification_requirements']}
assert set(requirements) == {'LTA-01', 'LTA-02', 'LTA-03', 'LTA-04'}

lta01 = requirements['LTA-01']
assert lta01['status'] == 'pass'
assert lta01['affects'] == []
assert lta01['implementation_status'] == 'verified'
assert lta01['certifier'] == 'tools.control_plane.native_repository_governance'
assert lta01['ruleset_id'] == 23516987
dependency_closure = lta['dependency_closure']['agent_dev_kit']
assert dependency_closure['strict_required_status_checks_policy'] is True
assert set(lta01['required_status_checks']) == {
    'contract', 'doc-sync', 'integration-impact', 'integration-summary', 'software-m5-certify', 'branch-gc'
}

lta02 = requirements['LTA-02']
assert lta02['status'] == 'delegated_nonblocking_observation'
assert lta02['implementation_status'] == 'observer-ready'
assert lta02['required_healthy_runtime_bindings'] >= 2
assert lta02['required_evidence_level'] == 'R2-periodic-real-provider-substitution'
assert lta02['r1_binding_conformance_is_terminal_evidence'] is False
assert lta02['qualification_authority'] == 'jiying2007/digital-worker'
assert lta02['terminal_blocking'] is False
assert 'certifier' not in lta02
assert 'certifier_command' not in lta02
assert lta02['pending_evidence'] == 'fresh-digital-worker-periodic-r2-qualification-receipt-for-observation'
assert lta02['affects'] == ['runtime-portability-observation']

lta03 = requirements['LTA-03']
assert lta03['status'] == 'pass'
assert lta03['affects'] == []
assert lta03['evidence'] == [recovery_path.as_posix()]
assert lta03['verified_main_commit'] == recovery['source']['llm_agent_commit']
assert lta03['workflow_run_id'] == int(recovery['environment']['github_run_id'])
assert lta03['workflow_job_id'] == 105904421691
assert lta03['artifact_id'] == 10584873865
assert re.fullmatch(r'[0-9a-f]{64}', lta03['receipt_sha256'])

lta04 = requirements['LTA-04']
assert lta04['status'] == 'observation_window_in_progress'
assert lta04['implementation_status'] == 'certifier-ready'
assert lta04['pilot_id'] == 'software-m5-v5-independent-pilot-20260912'
assert lta04['repository_id'] == 'digital-worker'
assert lta04['pilot_start_at'] == '2026-09-12T04:19:00Z'
assert lta04['minimum_calendar_days'] == 30
assert lta04['earliest_qualification_at'] == '2026-10-12T04:19:00Z'
assert lta04['certifier'] == 'tools.control_plane.longitudinal_operation'
assert lta04['default_evidence_path'] == 'reports/long-term-assets/longitudinal-operation-current.json'
assert lta04['pending_evidence'] == 'observation-window-and-real-summary-evidence'
assert set(lta04['affects']) == {
    'longitudinal-terminal-qualification',
    'long-term-asset-terminal-qualification',
}

for requirement in requirements.values():
    for evidence in requirement.get('evidence', []):
        if evidence.startswith('https://'):
            continue
        assert (root / evidence).exists(), (requirement['id'], evidence)

terminal = lta['terminal']
assert terminal['qualified'] is False
assert terminal['status'] == 'qualification_pending'
assert terminal['pending_requirements'] == ['LTA-04']

readiness = lta['terminal_readiness']
assert readiness['engineering_control_plane'] == 'pass'
assert readiness['iteration_readiness'] == 'ready'
assert readiness['iteration_gates'] == []
assert readiness['qualification_status'] == 'pending'
assert readiness['pending_requirements'] == ['LTA-04']
assert readiness['rehearsal'] == 'pass'
assert readiness['rehearsal_simulated'] is True
assert readiness['rehearsal_terminal_qualified'] is False
assert readiness['simulated_evidence_counts_as_real'] is False

assert scorecard['overall']['status'] == 'production-qualified'
assert scorecard['overall']['terminal_mature'] is True
assert scorecard['overall']['terminal_scope'] == 'product_maturity_v5'
assert scorecard['overall']['long_term_asset_status'] == 'qualification_pending'
assert scorecard['software_m5']['certified'] is True
assert scorecard['software_m5']['blocking_gates'] == []

assert recovery['schema'] == 'llm-agent-solo-recovery-receipt/v1'
assert recovery['status'] == 'pass'
assert recovery['drill']['fresh_dependency_materialization'] is True
assert recovery['drill']['replace_managed_apply'] == 'pass'
assert recovery['drill']['previous_receipt_restore'] == 'pass'
assert recovery['drill']['final_rollback'] == 'pass'
assert recovery['drill']['recovery_validation'] == {
    'static_target_contracts': 'pass',
    'typed_quick_validation': 'pass',
}
assert recovery['source']['agent_dev_kit_version'] == lock['version']
assert recovery['source']['agent_dev_kit_commit'] == lock['commit']
assert recovery['source']['agent_dev_kit_tree'] == lock['tree']
assert recovery['source']['lock_identity_match'] is True
assert recovery['source']['llm_agent_commit'] == lta03['verified_main_commit']
assert recovery['environment']['github_sha'] == lta03['verified_main_commit']

serialized = json.dumps(lta, sort_keys=True)
for retired_token in (
    'blocked_external_evidence',
    'blocked_time_evidence',
    'blocking_requirements',
    'real_blockers',
    'remaining_external_blocker',
    'operational_status',
):
    assert retired_token not in serialized, retired_token

print('LTA v2 qualification contract PASS')
PY

echo '[PASS] long-term asset qualification v2 cleanly separates iteration readiness from terminal qualification'
