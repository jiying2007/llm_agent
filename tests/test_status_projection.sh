#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
CERT="$(mktemp)"
trap 'rm -f "$TMP" "$CERT"' EXIT

python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --summary-json >"$TMP"

MODE="$(python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path
p = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print("CERTIFIED" if p["release_authorized"] is True else "HISTORICAL_NOT_AUTHORIZED")
PY
)"

if [[ "$MODE" == "CERTIFIED" ]]; then
  bash "$ROOT/scripts/software-m5.sh" certify --summary-json >"$CERT"
  python3 - "$TMP" "$CERT" "$ROOT/reports/current-status.md" "$ROOT/adk.lock" <<'PY'
import json
import re
import sys
from pathlib import Path

projection = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
cert = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
status = Path(sys.argv[3]).read_text(encoding="utf-8")
lock = {}
for line in Path(sys.argv[4]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

match = re.search(r"^- projection_inputs_sha256:\s*([0-9a-f]{64})$", status, re.MULTILINE)
assert match, status
assert projection["schema"] == "llm-agent-status-projection/v3", projection
assert projection["status"] == "pass", projection
assert projection["source"]["pin_consistent"] is True, projection
assert projection["source"]["adk_lock_commit"] == lock["agent-dev-kit.commit"], projection
assert projection["current_projection"]["consistent"] is True, projection
assert projection["current_projection"]["mismatches"] == {}, projection
assert projection["current_projection"]["inputs_sha256"] == match.group(1), projection
assert projection["current_evidence_state"] == "verified-for-current-source", projection
assert projection["last_verified_baseline"]["source_inputs_match"] is True, projection
assert projection["last_verified_baseline"]["fresh_for_current_source"] is True, projection
assert projection["release_authorized"] is True, projection
assert "- release_evidence_relation: current" in status, status
assert "- release_authorized: true" in status, status
assert cert["software_m5_certified"] is True, cert
assert cert["certification_status"] == "pass", cert
assert cert["blocking_gates"] == [], cert
assert cert["declaration_status"] == "pass", cert
PY
  python3 -m tools.control_plane.status_projection \
    --root "$ROOT" \
    --today 2026-09-12 \
    --require-fresh \
    --summary-json >/dev/null
  echo "[PASS] current source is fresh and release-authorized"
  exit 0
fi

python3 - "$TMP" "$ROOT/reports/current-status.md" "$ROOT/adk.lock" <<'PY'
import json
import re
import sys
from pathlib import Path

projection = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
status = Path(sys.argv[2]).read_text(encoding="utf-8")
lock = {}
for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

match = re.search(r"^- projection_inputs_sha256:\s*([0-9a-f]{64})$", status, re.MULTILINE)
assert match, status
assert projection["schema"] == "llm-agent-status-projection/v3", projection
assert projection["status"] == "pass", projection
assert projection["source"]["pin_consistent"] is True, projection
assert projection["source"]["adk_lock_commit"] == lock["agent-dev-kit.commit"], projection
assert projection["current_projection"]["consistent"] is True, projection
assert projection["current_projection"]["mismatches"] == {}, projection
assert projection["current_projection"]["inputs_sha256"] == match.group(1), projection
assert projection["current_evidence_state"] == "source-current-evidence-historical", projection
assert projection["last_verified_baseline"]["source_inputs_match"] is False, projection
assert projection["last_verified_baseline"]["fresh_for_current_source"] is False, projection
assert projection["release_authorized"] is False, projection
begin = "<!-- BEGIN GENERATED CURRENT SOURCE PROJECTION -->"
end = "<!-- END GENERATED CURRENT SOURCE PROJECTION -->"
assert status.count(begin) == 1 and status.count(end) == 1, status
block = status.split(begin, 1)[1].split(end, 1)[0]
assert re.search(r"^- release_evidence_relation:\s*historical$", block, re.MULTILINE), block
assert re.search(r"^- release_authorized:\s*false$", block, re.MULTILINE), block
PY

if python3 -m tools.control_plane.status_projection \
  --root "$ROOT" \
  --today 2026-09-12 \
  --require-fresh \
  --summary-json >/dev/null 2>&1; then
  echo "[FAIL] historical qualification unexpectedly passed fresh-status" >&2
  exit 1
fi

if bash "$ROOT/scripts/software-m5.sh" certify --summary-json >"$CERT" 2>/dev/null; then
  echo "[FAIL] historical qualification unexpectedly passed Software M5 certify" >&2
  exit 1
fi

echo "[PASS] current source is explicitly historical-not-authorized and fail-closed"

# Adversarial source parsing must fail closed independently of the current
# historical-vs-current product authorization decision.
python3 - <<'PYSTRICT'
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.control_plane.status_projection import _json_object, _kv, _md_fields

with TemporaryDirectory() as temporary:
    root = Path(temporary)
    source = root / "scorecard.json"
    source.write_text('{"overall":{"level":"M3"}}', encoding="utf-8")
    assert _json_object(source) == {"overall": {"level": "M3"}}
    invalid_json = [
        '{"overall":{},"overall":{"level":"M5"}}',
        '{"overall":{"level":"M3","level":"M5"}}',
        '{"overall":{"terminal_mature":NaN}}',
        '{"overall":{"terminal_mature":1e10000}}',
        '{"overall":' + "[" * 70 + "0" + "]" * 70 + "}",
        '{"overall":0}' + " " * (1024 * 1024),
    ]
    for candidate in invalid_json:
        source.write_text(candidate, encoding="utf-8")
        try:
            _json_object(source)
        except RuntimeError:
            pass
        else:
            raise AssertionError("invalid product status source JSON accepted")
    source.write_text('{"overall":{}}', encoding="utf-8")
    link = root / "alias.json"
    link.symlink_to(source)
    try:
        _json_object(link)
    except RuntimeError:
        pass
    else:
        raise AssertionError("symlinked status source accepted")

    lock = root / "adk.lock"
    lock.write_text("agent-dev-kit.version=8.1.1\nagent-dev-kit.version=0.0.0\n", encoding="utf-8")
    try:
        _kv(lock)
    except RuntimeError:
        pass
    else:
        raise AssertionError("duplicate version-lock key accepted")

    status = root / "current-status.md"
    status.write_text("# Status\n\n- release_authorized: false\n- release_authorized: true\n", encoding="utf-8")
    try:
        _md_fields(status)
    except RuntimeError:
        pass
    else:
        raise AssertionError("duplicate current-product field accepted")

print("[PASS] current product-source JSON, lock and projection fields are strict")
PYSTRICT

# Status and lock authority must read only bounded regular UTF-8 sources.
python3 - <<'PYINPUT'
import os
import tempfile
from pathlib import Path
from tools.control_plane.status_projection import (
    MAX_LOCK_BYTES, MAX_STATUS_BYTES, _kv, _md_fields, _read_status_text,
)

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    lock = root / "adk.lock"
    lock.write_text("schema=llm-agent-adk-lock/v2\nagent-dev-kit.version=8.1.1\n", encoding="utf-8")
    assert _kv(lock)["agent-dev-kit.version"] == "8.1.1"
    status = root / "status.md"
    status.write_text("# Current\n- release_authorized: false\n", encoding="utf-8")
    assert _md_fields(status)["release_authorized"] == "false"
    for path, reader, budget in (
        (lock, _kv, MAX_LOCK_BYTES),
        (status, _md_fields, MAX_STATUS_BYTES),
    ):
        original = path.read_bytes()
        for data in (b"\xff", b"x" * (budget + 1)):
            path.write_bytes(data)
            try:
                reader(path)
            except RuntimeError:
                pass
            else:
                raise AssertionError("unsafe or oversized status input passed")
        path.write_bytes(original)
        leaf = path.with_name(path.name + ".link")
        leaf.symlink_to(path)
        aliased = root / "alias-dir"
        if not aliased.exists():
            aliased.symlink_to(root, target_is_directory=True)
        for unsafe in (leaf, aliased / path.name):
            try:
                reader(unsafe)
            except RuntimeError:
                pass
            else:
                raise AssertionError("symlinked input passed")
        if hasattr(os, "mkfifo"):
            fifo = path.with_name(path.name + ".fifo")
            os.mkfifo(fifo)
            try:
                reader(fifo)
            except RuntimeError:
                pass
            else:
                raise AssertionError("FIFO input passed")
    try:
        _read_status_text(status, label="status", limit=0)
    except RuntimeError:
        pass
    else:
        raise AssertionError("zero budget unexpectedly passed")
print("[PASS] bounded regular UTF-8 version lock and current-status input")
PYINPUT
