#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/check-codex-lock.sh" "$ROOT" --pin-only

python3 -m tools.control_plane.runtime_chain --root "$ROOT" --pin-only --summary-json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"]=="pass" and d["mode"]=="pin-only", d; assert d["current_agent_dev_kit"]["version"]=="5.2.0", d; assert d["frozen_codex_provider"]["version"]=="5.1.1", d; assert d["current_agent_dev_kit"]["commit"] != d["frozen_codex_provider"]["commit"], d'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reports/promotion/agent-dev-kit"
cp "$ROOT/codex.lock" "$tmp/codex.lock"
cp "$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json" "$tmp/reports/promotion/agent-dev-kit/promotion-evidence.json"

python3 - "$tmp/codex.lock" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines()
updated = []
changed = False
for line in lines:
    if line.startswith("agent-dev-kit.commit="):
        updated.append("agent-dev-kit.commit=" + "0" * 40)
        changed = True
    else:
        updated.append(line)
if not changed:
    raise SystemExit("agent-dev-kit.commit missing from codex.lock fixture")
p.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY

set +e
PYTHONPATH="$ROOT" python3 - "$tmp" <<'PY'
from pathlib import Path
import sys

from tools.control_plane.runtime_chain import _pin_check

try:
    _pin_check(Path(sys.argv[1]))
except RuntimeError:
    raise SystemExit(1)
raise SystemExit(0)
PY
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { echo "[FAIL] frozen Codex provider pin drift did not fail closed" >&2; exit 1; }

echo '[PASS] current ADK and frozen Codex provider identities are independently fail-closed'
