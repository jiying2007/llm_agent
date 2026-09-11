#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
OUT="$TMP_DIR/out.json"
ERR="$TMP_DIR/err.log"

# Source-only CI intentionally does not initialize the private ADK checkout.
# The comprehensive checker must fail closed, but it must still emit a stable
# structured projection that distinguishes the current lock pin from the
# historical release baseline. Historical baseline age is not a source error.
if bash "$ROOT/scripts/check-current-status-consistency.sh" "$ROOT" --summary-json >"$OUT" 2>"$ERR"; then
  echo '[FAIL] source-only current-status checker unexpectedly passed without ADK checkout' >&2
  exit 1
fi

if rg -q 'Traceback|SyntaxError|NameError' "$ERR" "$OUT"; then
  echo '[FAIL] current-status checker crashed instead of failing closed' >&2
  cat "$ERR" >&2 || true
  cat "$OUT" >&2 || true
  exit 1
fi

python3 - "$OUT" "$ROOT/adk.lock" "$ROOT/reports/current-status.md" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, lock_path, status_path = map(Path, sys.argv[1:])
data = json.loads(out_path.read_text(encoding="utf-8"))
lock = {}
for line in lock_path.read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
status = status_path.read_text(encoding="utf-8")
release_match = re.search(r"^- agent_dev_kit_release_commit:\s*(.+)$", status, re.MULTILINE)
assert release_match, status
release_commit = release_match.group(1).strip()

assert data["status"] == "fail", data
assert data["current_adk_commit"] == lock["agent-dev-kit.commit"], data
assert data["current_adk_version"] == lock["agent-dev-kit.version"], data
assert data["agent_dev_kit_commit"] == lock["agent-dev-kit.commit"], data
assert data["agent_dev_kit_release_commit"] == release_commit, data
assert data["current_adk_commit"] != data["agent_dev_kit_release_commit"], data
assert data["release_evidence_relation"] == "historical", data
assert isinstance(data["historical_baseline_age_days"], int), data
assert data["historical_baseline_age_days"] > 7, data
assert not any("verification is stale" in item for item in data["failures"]), data
assert any(
    "agent-dev-kit" in item.lower() or "adk" in item.lower()
    for item in data["failures"]
), data
PY

echo '[PASS] current-status checker separates current source from historical release evidence and fails closed without ADK checkout'
