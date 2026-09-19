#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-current-status-consistency.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

"$CHECKER" "$ROOT" --summary-json >"$TMP_DIR/release-clean.json"
"$CHECKER" "$ROOT" --worktree-integration --summary-json >"$TMP_DIR/working-tree.json"

python3 - "$TMP_DIR/release-clean.json" "$TMP_DIR/working-tree.json" "$ROOT/adk.lock" <<'PY'
import json
import sys
from pathlib import Path

release = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
working = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
lock = {}
for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

for result in (release, working):
    assert result["schema"] == "llm-agent-current-status-consistency/v2", result
    assert result["status"] == "pass", result
    assert result["current_adk_version"] == lock["agent-dev-kit.version"], result
    assert result["current_adk_commit"] == lock["agent-dev-kit.commit"], result
    assert result["product_maturity"] == "M5", result
    assert result["product_terminal_scope"] == "product_maturity_v5", result
    assert result["long_term_asset_status"] == "qualification_pending", result
    assert set(result["pending_requirements"]) == {"LTA-02", "LTA-04"}, result
    assert result["current_report"].startswith("reports/architecture/"), result
    assert result["failures"] == [], result

assert release["gate_mode"] == "release-clean", release
assert working["gate_mode"] == "working-tree", working
PY

python3 - "$CHECKER" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for retired in (
    "rehearsal_report",
    "evidence_report",
    "previous_evidence_report",
    "runtime_campaign",
    "runtime_attestation",
    "self_pilot_active",
    "terminal_mature=false",
):
    assert retired not in text, retired
for canonical in (
    "tools.control_plane.status_projection",
    "product_maturity_v5",
    "long_term_asset_qualification.json",
    "qualification_pending",
):
    assert canonical in text, canonical
PY

echo "[PASS] current-status consistency is derived from current projection, Product M5, and separate LTA state"
