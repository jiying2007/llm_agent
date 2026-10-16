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
  "schema": "llm-agent-long-term-asset-qualification/v2",
  "qualification_requirements": [
    {
      "id": "LTA-04",
      "status": "observation_window_in_progress",
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
    ("independent-observation-day31", "pilot_observed", "2026-02-01T00:00:00Z"),
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
assert value["status"] == "simulated_pass", value
assert value["simulated"] is True and value["terminal_qualified"] is False, value
assert value["incidents"] == 1, value
assert value["regressions"] == 1, value
assert value["recoveries"] == 1, value
assert value["unresolved_risks"] == 0, value
PY

# A correctly rehashed, owner-reviewed *calendar-only* summary cannot prove
# 30 days of independent field operation when the end-of-window observation
# and its actual digest-bound source evidence are missing.
cp "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl" "$TMP/full-window-events.jsonl"
cp "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" "$TMP/full-window-summary.json"
python3 - "$FIXTURE" <<'PYNEG'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
event_log = root / "reports/field-evidence/software-m5-v5-events.jsonl"
summary_path = root / "reports/long-term-assets/longitudinal-operation-current.json"
events = [json.loads(line) for line in event_log.read_text(encoding="utf-8").splitlines()]
assert events[-1]["event_type"] == "pilot_observed"
events.pop()
event_log.write_text("".join(json.dumps(e, ensure_ascii=False, separators=(",", ":")) + "\n" for e in events), encoding="utf-8")
summary = json.loads(summary_path.read_text(encoding="utf-8"))
summary["source"]["event_log_sha256"] = hashlib.sha256(event_log.read_bytes()).hexdigest()
summary["source"]["event_chain_head"] = events[-1]["event_hash"]
summary["source"]["event_count"] = len(events)
summary.pop("summary_sha256")
summary["summary_sha256"] = hashlib.sha256(
    json.dumps(summary, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/start-only-summary.json"
START_ONLY_RC=$?
set -e
[[ "$START_ONLY_RC" -eq 2 ]] || { echo "[FAIL] rehashed calendar-only summary must stay BLOCKED" >&2; exit 1; }
python3 - "$TMP/start-only-summary.json" <<'PYNEG'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert value["status"] == "blocked", value
assert value["reason"] == "end-window-field-evidence-missing", value
assert value["simulated"] is True and value["terminal_qualified"] is False, value
PYNEG
cp "$TMP/full-window-events.jsonl" "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl"
cp "$TMP/full-window-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

# Duplicate JSON keys can preserve the *parsed* digest while presenting
# contradictory source bytes to reviewers. Both the summary and event ledger
# must reject duplicates before computing any source or chain authority.
python3 - "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" <<'PYNEG'
from pathlib import Path
import sys
path = Path(sys.argv[1])
original = path.read_text(encoding="utf-8")
assert original.count('"status": "complete"') == 1
path.write_text(original.replace('"status": "complete"', '"status": "complete", "status": "complete"', 1), encoding="utf-8")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/duplicate-summary-fields.json"
DUP_SUMMARY_RC=$?
set -e
[[ "$DUP_SUMMARY_RC" -eq 1 ]] || { echo "[FAIL] duplicate summary fields must fail" >&2; exit 1; }
python3 - "$TMP/duplicate-summary-fields.json" <<'PYNEG'
import json, sys
value=json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "fail" and "duplicate JSON object key" in value["error"], value
PYNEG
cp "$TMP/full-window-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

python3 - "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl" <<'PYNEG'
from pathlib import Path
import sys
path = Path(sys.argv[1])
original = path.read_text(encoding="utf-8")
assert '"event_type":"pilot_started"' in original
path.write_text(original.replace('"event_type":"pilot_started"', '"event_type":"pilot_started","event_type":"pilot_started"', 1), encoding="utf-8")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/duplicate-event-fields.json"
DUP_EVENT_RC=$?
set -e
[[ "$DUP_EVENT_RC" -eq 1 ]] || { echo "[FAIL] duplicate event fields must fail" >&2; exit 1; }
python3 - "$TMP/duplicate-event-fields.json" <<'PYNEG'
import json, sys
value=json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "fail" and "duplicate JSON object key" in value["error"], value
PYNEG
cp "$TMP/full-window-events.jsonl" "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl"


# Event evidence references are exact one-to-one declarations, not a
# multiplier for repeated hashing of large files or hidden extra digests.
# Recompute the *entire* chain in an isolated fixture to exercise validation.
python3 - "$FIXTURE" <<'PYNEG'
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from tools.control_plane.longitudinal_operation import (
    LongitudinalError, _read_events, MAX_EVENT_EVIDENCE_REFS,
)
root=Path(sys.argv[1])
event_log=root/"reports/field-evidence/software-m5-v5-events.jsonl"
baseline=event_log.read_bytes()
def digest(value):
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()).hexdigest()
def chain(events):
    prev="0"*64
    for event in events:
        event["previous_hash"]=prev
        event.pop("event_hash",None)
        event["event_hash"]=digest(event)
        prev=event["event_hash"]
    event_log.write_text("".join(json.dumps(event,ensure_ascii=False,separators=(",",":"))+"\n" for event in events),encoding="utf-8")
try:
    for case,error in (
        ("duplicate", "event evidence references must be unique"),
        ("budget", "event evidence reference count exceeds budget"),
        ("unlisted-digest", "event evidence digest keys do not match references"),
    ):
        events=[json.loads(line) for line in baseline.decode("utf-8").splitlines()]
        original=events[0]["evidence"][0]
        if case=="duplicate":
            events[0]["evidence"].append(original)
        elif case=="budget":
            events[0]["evidence"]=[original]*(MAX_EVENT_EVIDENCE_REFS+1)
        else:
            events[0]["evidence_sha256"]["reports/field-evidence/unlisted-fixture.json"]="0"*64
        chain(events)
        try:
            _read_events(root,event_log,datetime(2026,2,2,tzinfo=timezone.utc))
        except LongitudinalError as exc:
            assert error in str(exc),(case,str(exc))
        else:
            raise AssertionError("event evidence authorization bypass: "+case)
finally:
    event_log.write_bytes(baseline)
_read_events(root,event_log,datetime(2026,2,2,tzinfo=timezone.utc))
PYNEG

# An alternate summary is for simulated candidate review, never a real PASS.
cp "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" "$FIXTURE/reports/long-term-assets/unpromoted-candidate.json"
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --evidence reports/long-term-assets/unpromoted-candidate.json --summary-json >"$TMP/noncanonical-summary.json"
CANDIDATE_RC=$?
set -e
[[ "$CANDIDATE_RC" -eq 2 ]] || { echo "[FAIL] alternate summary must stay BLOCKED in real mode" >&2; exit 1; }
python3 - "$TMP/noncanonical-summary.json" <<'PYNEG'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["status"]=="blocked" and value["reason"]=="noncanonical-summary-review-only", value
PYNEG
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --evidence reports/long-term-assets/unpromoted-candidate.json --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/candidate-simulation.json"
python3 - "$TMP/candidate-simulation.json" <<'PYNEG'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["status"]=="simulated_pass", value
assert value["simulated"] is True and value["terminal_qualified"] is False, value
PYNEG
rm "$FIXTURE/reports/long-term-assets/unpromoted-candidate.json"

# All official field evidence must have durable Git HEAD identity, not only
# locally consistent JSON hashes. Use an isolated Git fixture, never a live repo.
python3 - <<'PYNEG'
import subprocess
import tempfile
from pathlib import Path
from tools.control_plane.longitudinal_operation import (
    _verify_committed_evidence, LongitudinalBlocked,
)
with tempfile.TemporaryDirectory() as temp:
    root=Path(temp).resolve()
    def git(*args):
        subprocess.run(["git","-C",str(root),*args],check=True,
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    git("init","-q")
    tracked=root/"field.json"
    tracked.write_text('{"source":"reviewed"}\n',encoding="utf-8")
    special=root/"meta[1].json"
    special.write_text("{}\n",encoding="utf-8")
    git("add","-A")
    git("-c","user.name=Fixture Owner","-c","user.email=owner@example.invalid","commit","-qm","fixture")
    _verify_committed_evidence(root,{tracked,special})
    tracked.write_text('{"source":"locally-altered"}\n',encoding="utf-8")
    try:
        _verify_committed_evidence(root,{tracked})
    except LongitudinalBlocked as exc:
        assert str(exc)=="terminal-evidence-worktree-drift", str(exc)
    else:
        raise AssertionError("dirty evidence was granted terminal authority")
    git("add","-A")
    try:
        _verify_committed_evidence(root,{tracked})
    except LongitudinalBlocked as exc:
        assert str(exc)=="terminal-evidence-worktree-drift", str(exc)
    else:
        raise AssertionError("staged evidence was granted terminal authority")
    tracked.write_text('{"source":"reviewed"}\n',encoding="utf-8")
    git("add","-A")
    _verify_committed_evidence(root,{tracked,special})
    # Git porcelain intentionally ignores assume-unchanged/skip-worktree,
    # but terminal evidence must still match the actual raw blob at HEAD.
    for flag, clear_flag in (
        ("--assume-unchanged", "--no-assume-unchanged"),
        ("--skip-worktree", "--no-skip-worktree"),
    ):
        git("update-index", flag, "field.json")
        tracked.write_text('{"source":"tampered-under-index-flag"}\n', encoding="utf-8")
        status=subprocess.run(
            ["git","-C",str(root),"status","--porcelain=v1","--","field.json"],
            check=True,capture_output=True,text=True,
        )
        assert status.stdout == "", (flag, status.stdout)
        try:
            _verify_committed_evidence(root,{tracked})
        except LongitudinalBlocked as exc:
            assert str(exc)=="terminal-evidence-worktree-drift", (flag, str(exc))
        else:
            raise AssertionError("hidden raw evidence mutation bypassed HEAD identity: "+flag)
        git("update-index", clear_flag, "field.json")
        git("restore", "--", "field.json")
        _verify_committed_evidence(root,{tracked})
    # Detect a staged change even if the worktree has been restored to HEAD.
    tracked.write_text('{"source":"different-staged-blob"}\n', encoding="utf-8")
    git("add", "field.json")
    tracked.write_text('{"source":"reviewed"}\n', encoding="utf-8")
    try:
        _verify_committed_evidence(root,{tracked})
    except LongitudinalBlocked as exc:
        assert str(exc)=="terminal-evidence-worktree-drift", str(exc)
    else:
        raise AssertionError("staged-only drift bypassed HEAD identity")
    git("reset","-q","HEAD","--","field.json")
    _verify_committed_evidence(root,{tracked,special})
    untracked=root/"not-promoted.json"
    untracked.write_text("{}\n",encoding="utf-8")
    try:
        _verify_committed_evidence(root,{untracked})
    except LongitudinalBlocked as exc:
        assert str(exc)=="terminal-evidence-not-committed", str(exc)
    else:
        raise AssertionError("untracked evidence was granted terminal authority")
PYNEG

# A well-formed, hash-rebound terminal observation must still come from a
# registered human operator on the configured independent pilot.
python3 - "$FIXTURE" <<'PYNEG'
import hashlib, json, sys
from pathlib import Path
root = Path(sys.argv[1])
event_log = root / "reports/field-evidence/software-m5-v5-events.jsonl"
summary_path = root / "reports/long-term-assets/longitudinal-operation-current.json"
events = [json.loads(line) for line in event_log.read_text(encoding="utf-8").splitlines()]
assert events[-1]["event_type"] == "pilot_observed"
events[-1]["operator_id"] = "unregistered-automation"
unsigned = dict(events[-1])
unsigned.pop("event_hash")
digest = lambda obj: hashlib.sha256(json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()
events[-1]["event_hash"] = digest(unsigned)
event_log.write_text("".join(json.dumps(e, ensure_ascii=False, separators=(",", ":"))+"\n" for e in events), encoding="utf-8")
summary = json.loads(summary_path.read_text(encoding="utf-8"))
summary["source"]["event_log_sha256"] = hashlib.sha256(event_log.read_bytes()).hexdigest()
summary["source"]["event_chain_head"] = events[-1]["event_hash"]
summary.pop("summary_sha256")
summary["summary_sha256"] = digest(summary)
summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/unregistered-observation.json"
UNREGISTERED_RC=$?
set -e
[[ "$UNREGISTERED_RC" -eq 1 ]] || { echo "[FAIL] unregistered terminal observation operator must FAIL" >&2; exit 1; }
python3 - "$TMP/unregistered-observation.json" <<'PYNEG'
import json, sys
value=json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"]=="fail" and "registered human operator" in value["error"], value
assert value["simulated"] is True and value["terminal_qualified"] is False, value
PYNEG
cp "$TMP/full-window-events.jsonl" "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl"
cp "$TMP/full-window-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

# Bound memory/CPU work before parsing or hashing untrusted field receipts.
# Sparse oversized files avoid allocating memory during the budget tests.
python3 - "$FIXTURE" <<'PYNEG'
import tempfile
import sys
from datetime import datetime, timezone
from pathlib import Path
from tools.control_plane.longitudinal_operation import (
    LongitudinalError, _load_object, _read_events,
    MAX_JSON_DOCUMENT_BYTES, MAX_EVENT_LOG_BYTES,
    MAX_EVENT_LINE_BYTES, MAX_FIELD_EVIDENCE_BYTES,
)
root=Path(sys.argv[1])
as_of=datetime(2026, 2, 2, tzinfo=timezone.utc)
def must_reject(work, text):
    try:
        work()
    except LongitudinalError as exc:
        assert text in str(exc), (text, str(exc))
    else:
        raise AssertionError("unexpected acceptance: "+text)

with tempfile.TemporaryDirectory() as tmp:
    temp=Path(tmp)
    obj=temp/"summary.json"
    for sample in ('{"value": NaN}', '{"value": Infinity}', '{"value": 1e999}'):
        obj.write_text(sample, encoding="utf-8")
        must_reject(lambda: _load_object(obj, "sample"), "non-finite JSON number")
    with obj.open("wb") as stream:
        stream.truncate(MAX_JSON_DOCUMENT_BYTES+1)
    must_reject(lambda: _load_object(obj, "sample"), "JSON byte budget")
    event_log=temp/"events.jsonl"
    event_log.write_text(" " * (MAX_EVENT_LINE_BYTES + 1)+"\n", encoding="utf-8")
    must_reject(lambda: _read_events(root, event_log, as_of), "line exceeds byte budget")
    with event_log.open("wb") as stream:
        stream.truncate(MAX_EVENT_LOG_BYTES+1)
    must_reject(lambda: _read_events(root, event_log, as_of), "event log exceeds byte budget")

evidence_path = root/"reports/field-evidence/pilot-start.json"
original = evidence_path.read_bytes()
try:
    with evidence_path.open("wb") as stream:
        stream.truncate(MAX_FIELD_EVIDENCE_BYTES+1)
    event_log=root/"reports/field-evidence/software-m5-v5-events.jsonl"
    must_reject(lambda: _read_events(root, event_log, as_of), "event evidence exceeds byte budget")
finally:
    evidence_path.write_bytes(original)
PYNEG

# Negative tests: a re-signed/hashed summary may not silently omit known
# fault, regression, or recovery events. Run through the full validator,
# not only the category helper.
cp "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" "$TMP/baseline-summary.json"
for category in incidents regressions recoveries; do
  python3 - "$TMP/baseline-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" "$category" <<'PYNEG'
import hashlib
import json
import sys
from pathlib import Path
source, target, category = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
value = json.loads(source.read_text())
value["outcomes"][category] = {"count": 0, "event_ids": []}
value.pop("summary_sha256")
value["summary_sha256"] = hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
PYNEG
  set +e
  python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/omitted-$category.json"
  OMIT_RC=$?
  set -e
  [[ "$OMIT_RC" -eq 1 ]] || { echo "[FAIL] omitted $category must fail" >&2; exit 1; }
  python3 - "$TMP/omitted-$category.json" <<'PYNEG'
import json, sys
from pathlib import Path
value=json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "fail" and "exactly cover" in value["error"], value
assert value["simulated"] is True and value["terminal_qualified"] is False, value
PYNEG
done
cp "$TMP/baseline-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

# A review issued before the observed-through instant must not certify later
# events even when the summary digest is otherwise valid.
python3 - "$TMP/baseline-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json" <<'PYNEG'
import hashlib, json, sys
from pathlib import Path
value=json.loads(Path(sys.argv[1]).read_text())
value["review"]["reviewed_at"]="2026-01-31T00:00:00Z"
value.pop("summary_sha256")
value["summary_sha256"]=hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()).hexdigest()
Path(sys.argv[2]).write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/early-review.json"
EARLY_RC=$?
set -e
[[ "$EARLY_RC" -eq 1 ]] || { echo "[FAIL] review before observation end must fail" >&2; exit 1; }
python3 - "$TMP/early-review.json" <<'PYNEG'
import json, sys
from pathlib import Path
value=json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "fail" and "after the observed window" in value["error"], value
PYNEG
cp "$TMP/baseline-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

# Duplicate IDs invalidate a correctly rehashed event chain before a summary
# is loaded. Restore the original event log for the remaining tests.
cp "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl" "$TMP/baseline-events.jsonl"
python3 - "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl" <<'PYNEG'
import hashlib, json, sys
from pathlib import Path
path=Path(sys.argv[1])
events=[json.loads(line) for line in path.read_text().splitlines()]
events[-1]["event_id"]=events[-2]["event_id"]
events[-1].pop("event_hash")
events[-1]["event_hash"]=hashlib.sha256(json.dumps(events[-1],ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()).hexdigest()
path.write_text("".join(json.dumps(e,ensure_ascii=False,separators=(",",":"))+"\n" for e in events))
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/duplicate-events.json"
DUP_RC=$?
set -e
[[ "$DUP_RC" -eq 1 ]] || { echo "[FAIL] duplicate event IDs must fail" >&2; exit 1; }
python3 - "$TMP/duplicate-events.json" <<'PYNEG'
import json, sys
from pathlib import Path
value=json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "fail" and "duplicate event_id" in value["error"], value
PYNEG
cp "$TMP/baseline-events.jsonl" "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl"

# A well-formed, fully rehashed non-field event must not become terminal
# evidence simply because its type and summary category still match.
python3 - "$FIXTURE" <<'PYNEG'
import hashlib
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
event_log = root / "reports/field-evidence/software-m5-v5-events.jsonl"
summary_path = root / "reports/long-term-assets/longitudinal-operation-current.json"
events = [json.loads(line) for line in event_log.read_text().splitlines()]
events[1]["evidence_layer"] = "synthetic"

def digest(value):
    data = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(data).hexdigest()

previous = "0" * 64
for event in events:
    event["previous_hash"] = previous
    event.pop("event_hash", None)
    event["event_hash"] = digest(event)
    previous = event["event_hash"]
event_log.write_text("".join(json.dumps(e, ensure_ascii=False, separators=(",", ":")) + "\n" for e in events))
summary = json.loads(summary_path.read_text())
summary["source"]["event_log_sha256"] = hashlib.sha256(event_log.read_bytes()).hexdigest()
summary["source"]["event_chain_head"] = events[-1]["event_hash"]
summary.pop("summary_sha256", None)
summary["summary_sha256"] = digest(summary)
summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
PYNEG
set +e
python3 -m tools.control_plane.longitudinal_operation --root "$FIXTURE" --as-of 2026-02-02T00:00:00Z --summary-json >"$TMP/non-field-event.json"
NON_FIELD_RC=$?
set -e
[[ "$NON_FIELD_RC" -eq 1 ]] || { echo "[FAIL] non-field terminal events must fail" >&2; exit 1; }
python3 - "$TMP/non-field-event.json" <<'PYNEG'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
assert value["status"] == "fail" and "field-only evidence" in value["error"], value
PYNEG
cp "$TMP/baseline-events.jsonl" "$FIXTURE/reports/field-evidence/software-m5-v5-events.jsonl"
cp "$TMP/baseline-summary.json" "$FIXTURE/reports/long-term-assets/longitudinal-operation-current.json"

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
