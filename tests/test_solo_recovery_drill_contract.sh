#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path

script = Path('scripts/solo-recovery-drill.sh')
workflow = Path('.github/workflows/solo-recovery-drill.yml')
assert script.is_file()
assert workflow.is_file()

s = script.read_text(encoding='utf-8')
w = workflow.read_text(encoding='utf-8')

for marker in (
    'git submodule update --init --depth=1 agent-dev-kit',
    'bash scripts/check-adk-lock.sh .',
    'python3 -m venv',
    'validate --quick --summary-json',
    'manifest composition-check --summary-json',
    'target check --all --level static --summary-json',
    'install plan',
    'install apply',
    'install rollback',
    'adk-install-receipt/v3',
    'llm-agent-solo-recovery-receipt/v1',
    'full_release_governance_reclassified',
    'runtime_invoked',
    'multi-runtime portability',
):
    assert marker in s, marker

assert 'validate --strict --summary-json' not in s
assert s.count('install rollback') >= 2
assert '--tool claude-code' in s
assert '--asset-kind skill' in s
assert 'ADK_REQUIRE_SUPPORTED_PYTHON=1' in s
assert 'rm -rf "$ADK_DIR"' in s

for marker in (
    'name: solo-maintainer-recovery-drill',
    'pull_request:',
    'push:',
    'schedule:',
    'workflow_dispatch:',
    'permissions:',
    'contents: read',
    'bash tests/test_solo_recovery_drill_contract.sh',
    'bash scripts/solo-recovery-drill.sh',
    'actions/upload-artifact@',
    'solo-maintainer-recovery-receipt',
):
    assert marker in w, marker

assert 'submodules: false' in w
assert 'persist-credentials: false' in w
print('solo recovery drill contract: PASS')
PY
