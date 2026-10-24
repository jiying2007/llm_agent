"""Independent read-only source review runner; writes only review evidence."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

BASE = Path('/workspace/scratch/712af632e2a5')
ROOT = BASE / 'llm_agent-pr270'
OUT = BASE / 'apply20261024/review-root'
RECOVERY = BASE / 'audit20261024/unpublished-recovery.json'
SOURCE_PATHS = [
    '.gitlab-ci.yml', 'manifests/gates.json',
    'tools/control_plane/active_contracts.py', 'tools/control_plane/impact.py',
    'tools/control_plane/gate_runner.py', 'tests/test_gate_boundaries.py',
    'tests/test_ci_incremental_gate_dag.sh', 'tests/test_gate_runner.sh',
    'manifests/comprehensive_optimization_backlog.json', 'pyproject.toml',
    'reports/current-status.md',
]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fingerprint() -> dict:
    result = {}
    recovery = json.loads(RECOVERY.read_text())
    for relative in sorted(set(SOURCE_PATHS + [item['path'] for item in recovery['path_changes']])):
        path = ROOT / relative
        result[relative] = {'sha256': sha(path.read_bytes()), 'bytes': path.stat().st_size} if path.is_file() else None
    return result


def main() -> None:
    label, *argv = sys.argv[1:]
    assert label and all(char.isalnum() or char in '-_' for char in label)
    assert argv
    OUT.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    env['PYTHONPATH'] = str(ROOT)
    env['PATH'] = str(BASE / 'audit-venv/bin') + os.pathsep + str(BASE / 'audit-tools') + os.pathsep + env['PATH']
    env['ADK_PYTHON_BIN'] = str(BASE / 'audit-venv/bin/python3')
    record = {
        'schema': 'independent-root-review-run/v1', 'label': label,
        'reviewer': '/root/release_governance_audit', 'cwd': str(ROOT),
        'argv': argv, 'started_at': utc(), 'source_before': fingerprint(),
    }
    started = time.monotonic()
    with (OUT / (label + '.stdout')).open('wb') as stdout, (OUT / (label + '.stderr')).open('wb') as stderr:
        result = subprocess.run(argv, cwd=ROOT, env=env, stdout=stdout, stderr=stderr, timeout=900)
    record.update(exit_code=result.returncode, completed_at=utc(), elapsed_seconds=round(time.monotonic() - started, 3), source_after=fingerprint())
    record['source_stable'] = record['source_before'] == record['source_after']
    for stream in ('stdout', 'stderr'):
        data = (OUT / (label + '.' + stream)).read_bytes()
        record[stream] = {'sha256': sha(data), 'bytes': len(data), 'path': str(OUT / (label + '.' + stream))}
    (OUT / (label + '.json')).write_text(json.dumps(record, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({key: record[key] for key in ('label', 'started_at', 'completed_at', 'exit_code', 'elapsed_seconds', 'source_stable')}, ensure_ascii=False))
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
