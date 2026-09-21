#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -m tools.control_plane.gitlink_registry --root "$ROOT" --summary-json >/tmp/llm-agent-gitlink-check.json
python3 - /tmp/llm-agent-gitlink-check.json <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "pass", data
assert data["tracked_count"] == 2, data
assert data["submodule_count"] == 2, data
items = {item["path"]: item for item in data["gitlinks"]}
assert set(items) == {"agent-dev-kit", "codex"}, items
assert items["agent-dev-kit"]["kind"] == "managed-dependency", items
assert items["codex"]["kind"] == "frozen-evidence-dependency", items
PY
rm -f /tmp/llm-agent-gitlink-check.json

echo "[PASS] tracked gitlinks distinguish current managed dependencies from frozen evidence dependencies"
