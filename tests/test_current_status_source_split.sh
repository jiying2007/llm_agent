#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Source-only CI keeps submodules disabled. M5 projection must still be complete
# because it is bound to root-side lock, signed promotion evidence and field/runtime evidence.
python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --summary-json >"$TMP"

python3 - "$TMP" "$ROOT/adk.lock" "$ROOT/reports/current-status.md" "$ROOT/manifests/software_m5_policy.json" <<'PY'
import json
import sys
from pathlib import Path

projection = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lock = {}
for line in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
status = Path(sys.argv[3]).read_text(encoding="utf-8")
policy = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))

assert projection["status"] == "pass", projection
assert projection["source"]["adk_lock_commit"] == lock["agent-dev-kit.commit"], projection
assert projection["current_projection"]["consistent"] is True, projection
assert projection["release_authorized"] is True, projection
assert "- release_evidence_relation: current" in status, status
assert "- current_product_maturity: M5" in status, status
assert policy["definition"] == "production-qualified", policy
assert policy["operational_advisories"]["recommended_observation_days"] >= 30, policy
assert policy["operational_advisories"]["second_human_operator"] is True, policy
assert policy["operational_advisories"]["multi_runtime_campaign"] is True, policy
PY

# A source rollover may legitimately make the generated current projection
# release_authorized=false while the historical verified baseline remains true.
# Those namespaces must not overwrite each other during projection validation.
PYTHONPATH="$ROOT" python3 - <<'PY'
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.control_plane.status_projection import (
    BEGIN_MARKER,
    END_MARKER,
    _generated_md_fields,
    _md_fields,
)

with TemporaryDirectory() as tmp:
    path = Path(tmp) / "current-status.md"
    path.write_text(
        "# Current Product Status\n\n"
        f"{BEGIN_MARKER}\n"
        "- projection_schema: llm-agent-current-status/v1\n"
        "- release_evidence_relation: historical\n"
        "- release_authorized: false\n"
        f"{END_MARKER}\n\n"
        "## Last Verified Product Baseline\n\n"
        "- last_verified_at: 2026-09-12\n"
        "- root_product_commit: deadbeef\n"
        "- release_authorized: true\n",
        encoding="utf-8",
    )
    assert _generated_md_fields(path)["release_authorized"] == "false"
    assert _generated_md_fields(path)["release_evidence_relation"] == "historical"
    assert _md_fields(path)["release_authorized"] == "true"
PY

echo "[PASS] source-only status projection carries current M5 identity while long-run evidence stays advisory"
