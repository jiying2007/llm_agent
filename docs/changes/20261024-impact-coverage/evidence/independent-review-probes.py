"""Independent recovery and impact counterchecks, using isolated fixtures only."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from tools.control_plane.gate_runner import _expand_profile
from tools.control_plane.impact import _git_changed_paths, calculate_impact

BASE = Path('/workspace/scratch/712af632e2a5')
ROOT = BASE / 'llm_agent-pr270'
RECOVERY = BASE / 'audit20261024/unpublished-recovery.json'


def git(root: Path, *argv: str) -> bytes:
    return subprocess.check_output(['git', '-C', str(root), *argv], stderr=subprocess.PIPE)


def object_hash(kind: bytes, body: bytes) -> str:
    return hashlib.sha1(kind + b' ' + str(len(body)).encode() + b'\0' + body).hexdigest()


def tree_oid(files: dict[bytes, tuple[bytes, str]]) -> str:
    tree = {}
    for name, value in files.items():
        parts = name.split(b'/')
        current = tree
        for part in parts[:-1]:
            current = current.setdefault(part, {})
        current[parts[-1]] = value

    def digest(nodes: dict) -> str:
        entries = []
        for name, value in nodes.items():
            directory = isinstance(value, dict)
            mode, oid = (b'40000', digest(value)) if directory else value
            entry = mode + b' ' + name + b'\0' + bytes.fromhex(oid)
            entries.append((name + (b'/' if directory else b''), entry))
        return object_hash(b'tree', b''.join(item[1] for item in sorted(entries)))

    return digest(tree)


def recovery_check() -> dict:
    source = json.loads(RECOVERY.read_text())
    head = git(ROOT, 'rev-parse', 'HEAD').decode().strip()
    assert head == source['published_head'], (head, source['published_head'])
    entries = {}
    for entry in git(ROOT, 'ls-tree', '-r', '-z', '--full-tree', 'HEAD').split(b'\0'):
        if not entry:
            continue
        metadata, name = entry.split(b'\t', 1)
        mode, _kind, oid = metadata.split()
        entries[name] = (mode, oid.decode())
    assert tree_oid(entries) == git(ROOT, 'rev-parse', 'HEAD^{tree}').decode().strip()
    checked = []
    for item in source['path_changes']:
        path = ROOT / item['path']
        key = item['path'].encode()
        old = entries.get(key)
        assert (old[1] if old else None) == item['old'], item
        if item['new'] is None:
            assert not path.exists() and not path.is_symlink(), item
            entries.pop(key)
            observed = None
            sha256 = None
        else:
            assert path.is_file() and not path.is_symlink(), item
            data = path.read_bytes()
            observed = object_hash(b'blob', data)
            sha256 = hashlib.sha256(data).hexdigest()
            assert observed == item['new'], item
            assert stat.S_IMODE(path.stat().st_mode) & 0o111 == 0, item
            entries[key] = (item['mode'].encode(), observed)
        checked.append({'path': item['path'], 'expected_blob': item['new'],
                        'actual_blob': observed, 'sha256': sha256, 'match': True})
    synthesized = tree_oid(entries)
    assert synthesized == 'd7f1319c90c70e989978c6b7e1984df2be59e66b', synthesized
    return {'published_head': head, 'recovery_record_sha256': hashlib.sha256(RECOVERY.read_bytes()).hexdigest(),
            'synthesized_recovery_only_tree': synthesized, 'matches': len(checked), 'paths': checked}


def ownership_check() -> dict:
    definition = json.loads((ROOT / 'manifests/gates.json').read_text())
    before = json.loads(git(ROOT, 'show', 'HEAD:manifests/gates.json'))
    gate = definition['gates']['maintenance-budget']
    assert set(definition['gates']) - set(before['gates']) == {'maintenance-budget'}
    assert not set(before['gates']) - set(definition['gates'])
    changed_existing = []
    for name, previous in before['gates'].items():
        current = definition['gates'][name]
        if current != previous:
            assert name == 'root-regression', name
            assert {key: value for key, value in current.items() if key != 'inputs'} == {
                key: value for key, value in previous.items() if key != 'inputs'}
            assert set(previous['inputs']).issubset(current['inputs'])
            changed_existing.append(name)
    assert gate['cache_policy'] == 'disabled' and not gate.get('impact_groups')
    assert gate['argv'] == ['bash', 'scripts/check-maintainability-budgets.sh', '--strict', '--summary-json']
    assert 'maintenance-budget' in _expand_profile(definition, 'contract')
    budgets = 'manifests/comprehensive_optimization_backlog.json'
    previous_budget = json.loads(git(ROOT, 'show', 'HEAD:' + budgets))['maintainability_budgets']
    current_budget = json.loads((ROOT / budgets).read_text())['maintainability_budgets']
    assert current_budget == previous_budget
    assert len(current_budget['budgets']) == 14
    assert (ROOT / 'tools/control_plane/impact.py').read_bytes() == git(ROOT, 'show', 'HEAD:tools/control_plane/impact.py')
    assert (ROOT / '.github/workflows/ci.yml').read_bytes() == git(ROOT, 'show', 'HEAD:.github/workflows/ci.yml')
    expected = {
        'README.md': False,
        'docs/architecture/reviewer-ordinary.md': False,
        'docs/changes/reviewer-prose/notes.md': False,
        'docs/runbooks/reviewer-ordinary.md': False,
        'reports/reviewer-ordinary.md': False,
        'reports/optimization/reviewer-ordinary.md': False,
        'subrepos/adoption-matrix.md': True,
        'schemas/external-practice-candidate.schema.json': True,
        'fixtures/external-practice/cycle-plan.json': True,
        'pyproject.toml': True,
        'reports/README.md': True,
        'docs/runbooks/runtime-target-activation.md': True,
        '.github/workflows/ci.yml': True,
        '.github/CODEOWNERS': True,
    }
    paths = []
    for path, required in expected.items():
        impact = calculate_impact(ROOT, [path], group='integration-deep')
        assert impact['required'] == required, impact
        if path.startswith('reports/') and not required:
            assert 'maintenance-budget' in impact['direct_gates'], impact
        paths.append({'path': path, 'required': impact['required'], 'direct_gates': impact['direct_gates']})
    return {'budget_count': 14, 'budget_unchanged': True, 'impact_algorithm_unchanged': True,
            'github_workflow_unchanged': True, 'existing_gate_fields_changed': changed_existing,
            'new_gate': gate, 'path_probes': paths}


def copy_one(root: Path, relative: str) -> None:
    source, target = ROOT / relative, root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)
    else:
        shutil.copyfile(source, target)


def commit(root: Path) -> str:
    git(root, 'add', '-A')
    git(root, '-c', 'user.name=Independent Review', '-c', 'user.email=review@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '-qm', 'isolated fixture')
    return git(root, 'rev-parse', 'HEAD').decode().strip()


def removal_check(root: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, '-m', 'tools.codex_assets.reference_repository',
                           '--root', str(root), 'check-removal', '--summary-json'],
                          cwd=ROOT, capture_output=True, text=True, timeout=30)


def isolated_rename_delete() -> dict:
    with tempfile.TemporaryDirectory(prefix='independent-root-impact-') as directory:
        root = Path(directory)
        fixture = 'fixtures/reference-repository/removal/pass/removal-plan.json'
        plan = json.loads((ROOT / fixture).read_text())
        inputs = {'manifests/gates.json', 'manifests/reference_repository_lifecycle_policy.json',
                  'fixtures/reference-repository/removal', *plan['required_artifacts'].values()}
        for relative in inputs:
            copy_one(root, relative)
        git(root, 'init', '-q')
        baseline = removal_check(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        base = commit(root)
        original = plan['required_artifacts']['adoption_decision']
        target = 'docs/architecture/reviewer-moved-evidence.md'
        (root / target).parent.mkdir(parents=True)
        (root / original).rename(root / target)
        renamed = commit(root)
        changed = _git_changed_paths(root, base, renamed, 'two-dot')
        assert changed == sorted([original, target]), changed
        missing = removal_check(root)
        assert missing.returncode == 2 and 'artifact is missing or unhashed' in missing.stderr
        impact = calculate_impact(root, changed, group='integration-deep')
        assert impact['required']
        assert not calculate_impact(root, [target], group='integration-deep')['required']
        (root / target).rename(root / original)
        restored = commit(root)
        (root / original).unlink()
        deleted = commit(root)
        deletion_paths = _git_changed_paths(root, restored, deleted, 'two-dot')
        assert deletion_paths == [original], deletion_paths
        deletion = removal_check(root)
        assert deletion.returncode == 2 and 'artifact is missing or unhashed' in deletion.stderr
        assert calculate_impact(root, deletion_paths, group='integration-deep')['required']
        return {'baseline_exit': baseline.returncode, 'rename_paths': changed,
                'rename_consumer_exit': missing.returncode, 'rename_consumer_stderr': missing.stderr,
                'rename_deep_required': True, 'destination_alone_deep_required': False,
                'delete_paths': deletion_paths, 'delete_consumer_exit': deletion.returncode,
                'delete_consumer_stderr': deletion.stderr, 'delete_deep_required': True}


if __name__ == '__main__':
    print(json.dumps({'recovery': recovery_check(), 'ownership': ownership_check(),
                      'isolated_rename_delete': isolated_rename_delete()}, indent=2, ensure_ascii=False))
