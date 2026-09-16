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
cp -a "$ROOT" "$TAMPERED"
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

echo '[PASS] ADK release -> Codex -> digital-worker consumer identity is exact and fail-closed'
