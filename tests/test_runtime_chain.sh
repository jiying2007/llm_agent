#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/check-codex-lock.sh" "$ROOT" --pin-only
python3 -m tools.control_plane.runtime_chain --root "$ROOT" --pin-only --summary-json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"]=="pass" and d["mode"]=="pin-only", d; domains=d["identity_domains"]; assert domains["cross_domain_equality_required"] is False, d; assert domains["root_current_adk"]["commit"] and domains["codex_frozen_adk"]["commit"], d'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reports/promotion/agent-dev-kit"
cp "$ROOT/adk.lock" "$tmp/adk.lock"
cp "$ROOT/codex.lock" "$tmp/codex.lock"
cp "$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json" "$tmp/reports/promotion/agent-dev-kit/promotion-evidence.json"

python3 - "$tmp/codex.lock" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
updated = []
changed = False
for line in lines:
    if line.startswith("agent-dev-kit.commit="):
        updated.append("agent-dev-kit.commit=" + "0" * 40)
        changed = True
    else:
        updated.append(line)
if not changed:
    raise SystemExit("agent-dev-kit.commit missing from codex.lock")
path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY

set +e
PYTHONPATH="$ROOT" python3 -m tools.control_plane.runtime_chain --root "$tmp" --pin-only >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { echo "[FAIL] frozen Codex ADK pin drift did not fail closed" >&2; exit 1; }

echo '[PASS] runtime-chain validates separate current/frozen ADK domains and frozen-pin drift'
