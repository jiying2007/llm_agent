#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/scripts/check-codex-lock.sh" "$ROOT" --pin-only
python3 -m tools.control_plane.runtime_chain --root "$ROOT" --pin-only --summary-json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"]=="pass" and d["mode"]=="pin-only", d'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reports/promotion/agent-dev-kit"
cp "$ROOT/adk.lock" "$tmp/adk.lock"
cp "$ROOT/codex.lock" "$tmp/codex.lock"
cp "$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json" "$tmp/reports/promotion/agent-dev-kit/promotion-evidence.json"
python3 - "$tmp/codex.lock" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8')
t=t.replace('agent-dev-kit.commit=59cbd5cb40ca7077ee5407636bfc617e295ec7e5', 'agent-dev-kit.commit=' + '0'*40)
p.write_text(t, encoding='utf-8')
PY
set +e
PYTHONPATH="$ROOT" python3 -m tools.control_plane.runtime_chain --root "$tmp" --pin-only >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { echo "[FAIL] runtime-chain pin drift did not fail closed" >&2; exit 1; }
echo '[PASS] runtime-chain pin and negative drift regression passed'
