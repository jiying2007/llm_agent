#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -m tools.control_plane.cli consumer-chain --root "$ROOT" --summary-json >"$TMP/consumer.json"
python3 - "$TMP/consumer.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["status"] == "pass", receipt
assert receipt["mode"] == "pin-only", receipt
assert receipt["agent_dev_kit"]["version"] == "5.1.1", receipt
assert len(receipt["agent_dev_kit"]["commit"]) == 40, receipt
assert len(receipt["codex"]["commit"]) == 40, receipt
assert receipt["digital_worker"]["repository"] == "jiying2007/digital-worker", receipt
assert receipt["digital_worker"]["runtime_enablement_from_reference_pin"] is False, receipt
assert len(receipt["digital_worker"]["commit"]) == 40, receipt
assert len(receipt["digital_worker"]["pilot_event_hash"]) == 64, receipt
PY

# A reference pin that no longer matches the already hash-bound pilot-start
# evidence must make the end-to-end consumer chain fail closed.
TAMPERED="$TMP/tampered"
python3 "$ROOT/tests/m5_snapshot_fixture.py" "$ROOT" "$TAMPERED" --owned-only
python3 - "$TAMPERED/manifests/reference_pins.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for pin in data["pins"]:
    if pin.get("id") == "digital-worker":
        pin["commit"] = "0" * 40
        break
else:
    raise SystemExit("digital-worker pin missing")
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if (
  cd "$TAMPERED"
  python3 -m tools.control_plane.cli consumer-chain --root . --summary-json >/dev/null 2>&1
); then
  echo '[FAIL] consumer chain accepted a reference pin that conflicts with immutable pilot evidence' >&2
  exit 1
fi

# Deliberately mutate only the disposable copied repository. The consumer
# chain must not read arbitrary host paths, symlinks, or unbounded evidence.
PYTHONPATH="$ROOT" python3 - "$ROOT" "$TAMPERED" <<'PY'
import json
import sys
from pathlib import Path

from tools.control_plane import consumer_chain as consumer
from tools.control_plane.longitudinal_operation import (
    MAX_EVENT_LOG_BYTES, MAX_FIELD_EVIDENCE_BYTES, _digest,
)

source, root = map(Path, sys.argv[1:3])
registry = root / "manifests/reference_pins.json"
registry.write_bytes((source / "manifests/reference_pins.json").read_bytes())
pin = consumer._digital_worker_pin(root)
baseline = consumer._pilot_binding(root, pin)
assert len(baseline["event_hash"]) == 64, baseline

ledger_path = root / "manifests/software_m5_pilot_ledger.json"
original_ledger = ledger_path.read_bytes()
ledger = json.loads(original_ledger)
event_path = root / ledger["event_log"]
original_events = event_path.read_bytes()
events = [json.loads(line) for line in original_events.splitlines()]
independent = next(event for event in events if event.get("repository_id") == "digital-worker")
field_path = root / independent["evidence"][0]
original_field = field_path.read_bytes()

def reject(label, expected):
    try:
        consumer._pilot_binding(root, pin)
    except (OSError, ValueError, RuntimeError) as exc:
        assert expected in str(exc), (label, str(exc))
    else:
        raise AssertionError(f"{label} incorrectly passed consumer evidence binding")

try:
    modified = dict(ledger, event_log="../outside.jsonl")
    ledger_path.write_text(json.dumps(modified), encoding="utf-8")
    reject("event-log traversal", "repository-relative path")
    ledger_path.write_bytes(original_ledger)

    event_path.write_bytes(original_events.replace(
        b'"event_hash":', b'"event_hash":"forged","event_hash":', 1
    ))
    reject("ambiguous JSONL event", "duplicate JSON object key")
    event_path.write_bytes(original_events)

    # A signed/hash-bound event can be rehashed by an attacker who controls
    # a local fixture, but its evidence references must still be unique.
    duplicate = dict(independent, evidence=independent["evidence"] * 2)
    duplicate.pop("event_hash")
    duplicate["event_hash"] = _digest(duplicate)
    events[-1] = duplicate
    event_path.write_text("".join(json.dumps(e) + "\n" for e in events), encoding="utf-8")
    reject("duplicate evidence ref", "event evidence references must be unique")
    event_path.write_bytes(original_events)

    changed = dict(independent, summary="tampered without event rehash")
    events[-1] = changed
    event_path.write_text("".join(json.dumps(e) + "\n" for e in events), encoding="utf-8")
    reject("tampered event payload", "event_hash does not match content")
    event_path.write_bytes(original_events)

    broken = dict(independent, previous_hash="f" * 64)
    broken.pop("event_hash")
    broken["event_hash"] = _digest(broken)
    events[-1] = broken
    event_path.write_text("".join(json.dumps(e) + "\n" for e in events), encoding="utf-8")
    reject("broken event chain", "previous_hash chain is broken")
    event_path.write_bytes(original_events)

    with event_path.open("wb") as handle:
        handle.truncate(MAX_EVENT_LOG_BYTES + 1)
    reject("oversized JSONL", "byte budget")
    event_path.write_bytes(original_events)

    with field_path.open("wb") as handle:
        handle.truncate(MAX_FIELD_EVIDENCE_BYTES + 1)
    reject("oversized evidence", "byte budget")
    field_path.write_bytes(original_field)

    alias = event_path.with_name("consumer-chain-symlink-original.jsonl")
    alias.write_bytes(original_events)
    event_path.unlink()
    event_path.symlink_to(alias.name)
    reject("event-log symlink", "symlink")
    event_path.unlink()
    event_path.write_bytes(original_events)
    alias.unlink()

    alias = field_path.with_name("consumer-chain-symlink-original.json")
    alias.write_bytes(original_field)
    field_path.unlink()
    field_path.symlink_to(alias.name)
    reject("field-evidence symlink", "symlink")
    field_path.unlink()
    field_path.write_bytes(original_field)
    alias.unlink()
finally:
    ledger_path.write_bytes(original_ledger)
    if event_path.is_symlink():
        event_path.unlink()
    event_path.write_bytes(original_events)
    if field_path.is_symlink():
        field_path.unlink()
    field_path.write_bytes(original_field)

assert consumer._pilot_binding(root, pin) == baseline
PY

echo '[PASS] ADK release -> Codex -> digital-worker consumer identity is exact, bounded and fail-closed'
