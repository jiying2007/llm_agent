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
paths = {item["path"] for item in data["gitlinks"]}
assert "agent-dev-kit" in paths
assert "hermes" in paths
assert "hermes_data" in paths
assert "team-codex-assets" in paths
assert data["opaque_count"] >= 3
PY
rm -f /tmp/llm-agent-gitlink-check.json

echo "[PASS] gitlink registry contract"
