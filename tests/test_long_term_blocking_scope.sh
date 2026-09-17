#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
from pathlib import Path

root = Path('.')
lta = json.loads((root / 'manifests/long_term_asset_qualification.json').read_text())

assert lta['schema'] == 'llm-agent-long-term-asset-qualification/v1'
assert lta['updated_at'] == '2026-09-17'
assert lta['rules']['fail_closed'] is True
assert lta['rules']['terminal_requires_all_blocking_requirements'] is True
assert lta['rules']['blocking_scope_must_be_explicit'] is True
assert lta['rules']['qualification_pending_does_not_block_iteration'] is True

iteration = lta['iteration_readiness']
assert iteration['development'] == 'ready'
assert iteration['integration'] == 'ready'
assert iteration['control_plane'] == 'ready'
assert iteration['blocking_requirements'] == []
assert set(iteration['qualification_pending']) == {'LTA-02', 'LTA-04'}

requirements = {item['id']: item for item in lta['blocking_requirements']}
assert set(requirements) == {'LTA-01', 'LTA-02', 'LTA-03', 'LTA-04'}

for requirement_id in ('LTA-01', 'LTA-03'):
    item = requirements[requirement_id]
    assert item['status'] == 'pass'
    assert item['blocking_scope'] == 'none'
    assert item['development_blocking'] is False
    assert item['integration_blocking'] is False
    assert item['terminal_qualification_blocking'] is False

lta02 = requirements['LTA-02']
assert lta02['status'] == 'blocked_external_evidence'
assert lta02['operational_status'] == 'evidence_collection_in_progress'
assert lta02['blocking_scope'] == 'runtime-portability-terminal-qualification-only'
assert lta02['development_blocking'] is False
assert lta02['integration_blocking'] is False
assert lta02['product_maturity_blocking'] is False
assert lta02['terminal_qualification_blocking'] is True
assert lta02['remaining_external_blocker'] == 'real-claude-runtime-execution-receipt-and-same-frozen-task-R2-comparison-evidence'

lta04 = requirements['LTA-04']
assert lta04['status'] == 'blocked_time_evidence'
assert lta04['operational_status'] == 'observation_window_in_progress'
assert lta04['blocking_scope'] == 'longitudinal-terminal-qualification-only'
assert lta04['development_blocking'] is False
assert lta04['integration_blocking'] is False
assert lta04['product_maturity_blocking'] is False
assert lta04['terminal_qualification_blocking'] is True
assert lta04['pilot_start_at'] == '2026-09-12T04:19:00Z'
assert lta04['earliest_qualification_at'] == '2026-10-12T04:19:00Z'

assert [item['id'] for item in requirements.values() if item.get('development_blocking')] == []
assert [item['id'] for item in requirements.values() if item.get('integration_blocking')] == []
assert {item['id'] for item in requirements.values() if item.get('terminal_qualification_blocking')} == {'LTA-02', 'LTA-04'}

readiness = lta['terminal_readiness']
assert readiness['engineering_control_plane'] == 'pass'
assert readiness['iteration_readiness'] == 'ready'
assert readiness['development_blockers'] == []
assert readiness['integration_blockers'] == []
assert set(readiness['qualification_pending']) == {'LTA-02', 'LTA-04'}
assert readiness['real_qualification'] == 'blocked'
assert readiness['real_blocker_scope'] == 'long-term-asset-terminal-qualification-only'
assert set(readiness['real_blockers']) == {'LTA-02', 'LTA-04'}

terminal = lta['terminal']
assert terminal['qualified'] is False
assert terminal['status'] == 'blocked'
assert terminal['blocking_scope'] == 'long-term-asset-terminal-qualification-only'
assert set(terminal['blockers']) == {'LTA-02', 'LTA-04'}

layer = {item['id']: item for item in lta['qualification_layers']}['long-term-asset-qualified']
assert layer['status'] == 'blocked'
assert layer['blocking_scope'] == 'long-term-asset-terminal-qualification-only'
assert layer['development_blocking'] is False
assert layer['integration_blocking'] is False

print('long-term blocking scope contract PASS: integration/development ready; LTA-02/LTA-04 terminal-only')
PY
