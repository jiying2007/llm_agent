#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The real repository must remain BLOCKED before the configured 30-day window.
set +e
python3 -m tools.control_plane.longitudinal_operation \
  --root "$ROOT" \
  --as-of 2026-09-15T11:35:00Z \
  --summary-json >"$TMP/current.json"
CURRENT_RC=$?
set -e
[[ "$CURRENT_RC" -eq 2 ]] || { echo "[FAIL] current LTA-04 should be BLOCKED before 30 days" >&2; exit 1; }
python3 - "$TMP/current.json" <<'PY'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "blocked", value
assert value["reason"] == "observation-window-not-complete", value
assert value["eligible_after"] == "2026-10-12T04:19:00Z", value
assert value["pilot_id"] == "software-m5-v5-independent-pilot-20260912", value
assert value["repository_id"] == "digital-worker", value
PY

FIXTURE="$TMP/fixture"
mkdir -p "$FIXTURE/manifests" "$FIXTURE/reports/field-evidence" "$FIXTURE/reports/long-term-assets"

cat >"$FIXTURE/manifests/long_term_asset_qualification.json" <<'JSON'
{
  "schema": "llm-agent-long-term-asset-qualification/v1",
  "blocking_requirements": [
    {
      "id": "LTA-04",
      "status": "blocked_time_evidence",
      "implementation_status": "certifier-ready",
      "pilot_id": "pilot-independent",
      "repository_id": "independent-repo",
      "minimum_calendar_days": 30,
      "default_evidence_path": "reports/long-term-assets/longitudinal-operation-current.json"
    }
  ]
}
JSON

cat >"$FIXTURE/manifests/software_m5_pilot_ledger.json" <<'JSON'
{
  "schema": "llm-agent-software-m5-pilot-ledger/v1",
  "event_log": "reports/field-evidence/software-m5-v5-events.jsonl",
  "repositories": [
    {"id": "independent-repo", "path": "external", "classification": "independent", "real_software": true}
  ],
  "operators": [
    {"id": "operator-primary", "operator_type": "human", "role": "repository-owner", "independent_reviewer": false}
  ],
  "pilots": [
    {
      "id": "pilot-independent",
      "environment_class": "independent",
      "status": "active",
      "started_at": "2026-01-01T00:00:00Z",
      "ended_at": null,
      "repositories": ["independent-repo"],
      "operators": ["operator-primary"]
    }
  ]
}
JSON

python3 - "$FIXTURE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
field = root / "reports/field-evidence"
long_term = root / "reports/long-term-assets"

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()

def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

specs = [
    ("pilot-start", "pilot_started", "2026-01-01T00:00:00Z"),
    ("fault-1", "fault_observed", "2026-01-10T00:00:00Z"),
    ("regression-1", "regression_observed", "2026-01-15T00:00:00Z"),
    ("recovery-1", "recovery_completed", "2026-01-20T00:00:00Z"),
]
previous = "0" * 64
events = []
for sequence, (event_id, event_type, occurred) in enumerate(specs, start=1):
    evidence_rel = f"reports/field-evidence/{event_id}.json"
    evidence_path = root / evidence_rel
    evidence_path.write_text(json.dumps({"event": event_id}) + "\n", encoding="utf-8")
    event = {
        "schema": "llm-agent-software-field-event/v1",
        "sequence": sequence,
        "event_id": event_id,
        "pilot_id": "pilot-independent",
        "occurred_at": occurred,
        "recorded_at": occurred,
        "event_type": event_type,
        "evidence_layer": "field",
        "repository_id": "independent-repo",
        "operator_id": "operator-primary",
        "summary": event_type,
        "evidence": [evidence_rel],
        "evidence_sha256": {evidence_rel: sha(evidence_path)},
        "metrics": {},
        "previous_hash": previous,
    }
    event["event_hash"] = digest(event)
    previous = event["event_hash"]
    events.append(event)
event_log = field / "software-m5-v5-events.jsonl"
event_log.write_text("".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n" for item in events), encoding="utf-8")

summary = {
    "schema": "llm-agent-longitudinal-operation-evidence/v1",
    "qualification": "LTA-04",
    "status": "complete",
    "pilot_id": "pilot-independent",
    "repository_id": "independent-repo",
    "observation": {
        "started_at": "2026-01-01T00:00:00Z",
        "observed_through": "2026-02-01T00:00:00Z"
    },
    "source": {
        "event_log": "reports/field-evidence/software-m5-v5-events.jsonl",
        "event_log_sha256": sha(event_log),
        "event_chain_head": events[-1]["event_hash"],
        "event_count": len(events)
    },
    "outcomes": {
        "incidents": {"count": 1, "event_ids": ["fault-1"]},
        "regressions": {"count": 1, "event_ids": ["regression-1"]},
        "recoveries": {"count": 1, "event_ids": ["recovery-1"]},
        "unresolved_risks": []
    },
    "review": {
        "operator_id": "operator-primary",
        "standard": "solo-maintainer-long-term-asset-v1",
        "decision": "approve",
        "reviewed_at": "2026-02-01T00:00:00Z"
    }
}
summary["summary_sha256"] = digest(summary)
(long_term / "longitudinal-operation-current.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 -m tools.control_plane.longitudinal_operation \
  --root "$FIXTURE" \
  --as-of 2026-02-02T00:00:00Z \
  --summary-json >"$TMP/pass.json"
python3 - "$TMP/pass.json" <<'PY'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "pass", value
assert value["incidents"] == 1, value
assert value["regressions"] == 1, value
assert value["recoveries"] == 1, value
assert value["unresolved_risks"] == 0, value
PY

python3 - "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
value = json.loads(path.read_text())
value["outcomes"]["unresolved_risks"] = [
    {"id": "risk-1", "severity": "high", "disposition": "blocking", "summary": "unresolved blocking risk"}
]
value.pop("summary_sha256", None)
payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
value["summary_sha256"] = hashlib.sha256(payload).hexdigest()
path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
PY
set +e
python3 -m tools.control_plane.longitudinal_operation \
  --root "$FIXTURE" \
  --as-of 2026-02-02T00:00:00Z \
  --summary-json >"$TMP/risk-blocked.json"
RISK_RC=$?
set -e
[[ "$RISK_RC" -eq 2 ]] || { echo "[FAIL] blocking risk must keep LTA-04 BLOCKED" >&2; exit 1; }
python3 - "$TMP/risk-blocked.json" <<'PY'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "blocked", value
assert value["reason"] == "unresolved-blocking-risks", value
PY

# Tampering with event evidence after it was hash-bound must be a hard FAIL.
echo '{"event":"tampered"}' >"$FIXTURE/reports/field-evidence/pilot-start.json"
set +e
python3 -m tools.control_plane.longitudinal_operation \
  --root "$FIXTURE" \
  --as-of 2026-02-02T00:00:00Z \
  --summary-json >"$TMP/tampered.json"
TAMPER_RC=$?
set -e
[[ "$TAMPER_RC" -eq 1 ]] || { echo "[FAIL] tampered field evidence must FAIL" >&2; exit 1; }
python3 - "$TMP/tampered.json" <<'PY'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "fail", value
assert "digest drift" in value["error"], value
PY

echo "[PASS] LTA-04 longitudinal operation certifier"
