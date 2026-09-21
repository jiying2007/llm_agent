#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
from pathlib import Path

root = Path('.')
lta = json.loads((root / 'manifests/long_term_asset_qualification.json').read_text())
scorecard = json.loads((root / 'manifests/product_maturity_scorecard.json').read_text())
runtime_pilot = json.loads((root / 'manifests/digital_worker_runtime_pilot.json').read_text())

assert lta['schema'] == 'llm-agent-long-term-asset-qualification/v2'
assert lta['rules']['fail_closed'] is True
assert lta['rules']['terminal_requires_all_qualification_requirements'] is True
assert lta['rules']['qualification_pending_does_not_block_iteration'] is True

iteration = lta['iteration_readiness']
assert iteration == {
    'development': 'ready',
    'integration': 'ready',
    'control_plane': 'ready',
    'iteration_gates': [],
    'qualification_pending': ['LTA-04'],
    'meaning': iteration['meaning'],
}

requirements = {item['id']: item for item in lta['qualification_requirements']}
assert set(requirements) == {'LTA-01', 'LTA-02', 'LTA-03', 'LTA-04'}
assert requirements['LTA-01']['status'] == 'pass'
assert requirements['LTA-03']['status'] == 'pass'

lta02 = requirements['LTA-02']
assert lta02['status'] == 'delegated_nonblocking_observation'
assert lta02['affects'] == ['runtime-portability-observation']
assert lta02['implementation_status'] == 'observer-ready'
assert lta02['pending_evidence'] == 'fresh-digital-worker-periodic-r2-qualification-receipt-for-observation'
assert lta02['required_evidence_level'] == 'R2-periodic-real-provider-substitution'
assert lta02['r1_binding_conformance_is_terminal_evidence'] is False
assert lta02['qualification_authority'] == 'jiying2007/digital-worker'
assert lta02['terminal_blocking'] is False

ownership = runtime_pilot['execution_ownership']
assert ownership['runtime_home_mode'] == 'shared-user-home'
assert ownership['runtime_local_state_policy'] == (
    'reuse-local-auth-and-provider-state-exclude-credential-state-and-user-behavioral-settings-'
    'from-evidence-execution-context'
)
rules = runtime_pilot['hard_rules']
assert rules['runtime_user_behavioral_settings_must_not_enter_controlled_execution_context'] is True
assert rules['shared_home_reuse_is_auth_provider_state_not_behavioral_instruction_reuse'] is True
assert rules['r2_qualification_authority_must_be_digital_worker'] is True
assert rules['llm_agent_must_not_recertify_r2'] is True
assert rules['independent_verifier_must_be_distinct_from_provider_execution_actors'] is True
assert ownership['r2_qualification_authority'] == 'jiying2007/digital-worker'
assert ownership['independent_verifier_actor_required'] is True
assert ownership['llm_agent_role'] == 'optional-evolution-observer'

lta04 = requirements['LTA-04']
assert lta04['status'] == 'observation_window_in_progress'
assert lta04['affects'] == [
    'longitudinal-terminal-qualification',
    'long-term-asset-terminal-qualification',
]
assert lta04['implementation_status'] == 'certifier-ready'
assert lta04['pilot_start_at'] == '2026-09-12T04:19:00Z'
assert lta04['earliest_qualification_at'] == '2026-10-12T04:19:00Z'
assert lta04['minimum_calendar_days'] == 30
assert lta04['pending_evidence'] == 'observation-window-and-real-summary-evidence'

terminal = lta['terminal']
assert terminal == {
    'qualified': False,
    'status': 'qualification_pending',
    'pending_requirements': ['LTA-04'],
}

readiness = lta['terminal_readiness']
assert readiness['engineering_control_plane'] == 'pass'
assert readiness['iteration_readiness'] == 'ready'
assert readiness['iteration_gates'] == []
assert readiness['qualification_status'] == 'pending'
assert readiness['pending_requirements'] == ['LTA-04']
assert readiness['rehearsal_scope'] == ['LTA-04']

layer = {item['id']: item for item in lta['qualification_layers']}['long-term-asset-qualified']
assert layer['status'] == 'qualification_pending'
assert layer['affects'] == ['long-term-asset-terminal-qualification']

assert scorecard['overall']['status'] == 'production-qualified'
assert scorecard['overall']['long_term_asset_status'] == 'qualification_pending'
assert scorecard['software_m5']['blocking_gates'] == []

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

print('LTA v2 qualification scope PASS: iteration ready; terminal qualification pending only')
PY
