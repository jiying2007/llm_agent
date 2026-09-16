#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.active_contracts \
  --root "$ROOT" \
  --as-of 2026-09-11 \
  --summary-json >"$TMP"
python3 - "$TMP" "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root = Path(sys.argv[2])
assert data["status"] == "pass", data
assert data["item_count"] >= 22, data
assert data["failures"] == [], data

targets = json.loads((root / "manifests/runtime_targets.json").read_text(encoding="utf-8"))
adapters = json.loads((root / "manifests/runtime_health_adapters.json").read_text(encoding="utf-8"))
expected_runtimes = {"codex", "claude-code", "opencode"}
assert set(targets["supported_runtime_kinds"]) == expected_runtimes, targets
assert {item["runtime"] for item in targets["targets"]} == expected_runtimes, targets
assert {item["runtime"] for item in adapters["adapters"]} == expected_runtimes, adapters

for relative in (
    "README.md",
    "docs/llm-agent-maintenance-guide.md",
    "docs/runbooks/runtime-target-activation.md",
):
    text = (root / relative).read_text(encoding="utf-8")
    assert "hermes-agent" not in text, relative
    assert "Hermes Agent" not in text, relative
PY

echo '[PASS] active governance references are fresh and retired runtime surfaces are absent'
