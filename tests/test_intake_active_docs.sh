#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib
import json
import subprocess
import sys
root=Path(sys.argv[1])
manual=(root/'scripts/README.md').read_text(encoding='utf-8')
for retired in ('agent-dev-kit/manifest.yaml', '--skip-sync', '--skip-analyze', 'adk 当前状态（2026-05-23）', 'agent-dev-kit.version=2.9.0'):
    assert retired not in manual, retired
for current in ('agent-dev-kit/manifest.json','manifests/reference_pins.json','--repository','--cache-root','static-partial','coverage'):
    assert current in manual, current
history=root/'reports/optimization/2026-09-25/historical-script-status-2026-05-23.md'
assert history.is_file() and 'agent-dev-kit.version=2.9.0' in history.read_text()
index=(root/'reports/README.md').read_text(encoding='utf-8')
begin='<!-- BEGIN RESEARCH ARCHIVE 2026-09-25 -->'
end='<!-- END RESEARCH ARCHIVE 2026-09-25 -->'
assert index.count(begin)==1 and index.count(end)==1
block=index.split(begin,1)[1].split(end,1)[0]
metadata=json.loads(block.split('```json\n',1)[1].split('```',1)[0])
raw=(root/metadata['archived_path']).read_bytes()
assert len(raw)==metadata['bytes']
assert hashlib.sha256(raw).hexdigest()==metadata['sha256']
assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==metadata['git_blob']
assert metadata['original_status']=='proposal-not-implemented' and metadata['qualification_authority']=='none'
assert not (root/'reports/optimization/2026-09-25/archive.json').exists()
result=subprocess.run([sys.executable,'-m','tools.codex_assets.update_pipeline','--help'],cwd=root,text=True,capture_output=True,timeout=10,check=True)
for current in ('--repository','--cache-root','--report-only','--summary-json'):
    assert current in result.stdout, current
for retired in ('--skip-sync','--skip-analyze'):
    assert retired not in result.stdout, retired
print('[PASS] active intake documentation matches canonical CLI; historical facts stay archived')
PY
