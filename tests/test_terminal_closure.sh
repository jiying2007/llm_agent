#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.terminal_closure --root . --summary-json >"$TMP"
python3 - "$ROOT" "$TMP" <<'PY'
import json,sys
from pathlib import Path

root=Path(sys.argv[1])
value=json.load(open(sys.argv[2],encoding="utf-8"))
backlog=json.loads((root/"manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8"))

assert value["schema"]=="llm-agent-terminal-closure/v1", value
assert value["status"]=="pass", value
assert value["release_authorized"] is False, value
assert value["software_ready"] is True, value

items={item["id"]:item for item in backlog["items"]}
open_ids=sorted(
    item_id for item_id,item in items.items()
    if item["implementation_status"]!="done"
)
projected_ids=sorted(item["id"] for item in value["backlog"]["open_items"])
assert projected_ids==open_ids, (projected_ids,open_ids)
assert value["backlog"]["done_items"]+len(projected_ids)==value["backlog"]["total_items"], value
assert value["backlog"]["unexpected_nonterminal_items"]==[], value

blocker_ids=sorted(item["id"] for item in value["external_blockers"])
assert blocker_ids==open_ids, (blocker_ids,open_ids)
for item_id in open_ids:
    assert item_id in {"G9","G21","G22"}, item_id
    assert items[item_id]["implementation_status"]=="blocked", items[item_id]
    assert isinstance(items[item_id].get("blocking_condition"),str) and items[item_id]["blocking_condition"], items[item_id]

if "G9" in open_ids:
    g9=value["domains"]["G9"]
    assert g9["status"]=="blocked-external-evidence", g9
    assert g9["captured_reviewing"] is True, g9
    assert g9["owner_review_recorded"] is False, g9
    assert g9["owner_lifecycle_decision_recorded"] is False, g9
    assert g9["evidence_index"]=="reports/runtime-evidence/knowledge-retention/evidence-index.json", g9
    assert g9["handoff_evidence"]=="reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json", g9
    assert g9["owner_decision_evidence"] is None, g9
    assert g9["hub_master_revision"]=="0fb7ed1e2dbd5f715b9b4382581d696081af1b8c", g9
    assert g9["hub_post_merge_quality_run"]==36218784210, g9

if "G21" in open_ids:
    g21=value["domains"]["G21"]
    assert g21["software_ready"] is True, g21
    assert g21["native_verified"] is False, g21
    assert g21["status"]=="blocked-external-evidence", g21

if "G22" in open_ids:
    g22=value["domains"]["G22"]
    assert g22["software_ready"] is True, g22
    assert g22["effect_evidence_ready"] is False, g22
    assert g22["status"]=="blocked-external-evidence", g22

if open_ids:
    assert value["terminal_ready"] is False, value
    assert value["terminal_status"]=="blocked-external-evidence", value
else:
    assert value["terminal_ready"] is True, value
    assert value["terminal_status"]=="ready", value

boundary=value["authority_boundary"]
assert boundary["projection_has_execution_authority"] is False, boundary
assert boundary["projection_may_fill_owner_review"] is False, boundary
assert boundary["projection_may_create_runtime_or_effect_evidence"] is False, boundary
assert boundary["projection_authorizes_release"] is False, boundary
PY

set +e
python3 -m tools.control_plane.terminal_closure --root . --require-terminal --summary-json >/dev/null
rc=$?
set -e
python3 - "$TMP" "$rc" <<'PY'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
rc=int(sys.argv[2])
if value["terminal_ready"]:
    assert rc==0, (rc,value)
else:
    assert rc==2, (rc,value)
PY

python3 -m tools.control_plane.cli terminal-closure --root . --summary-json   | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["schema"]=="llm-agent-terminal-closure/v1" and v["status"]=="pass", v'

echo '[PASS] terminal closure exposes only real external blockers and no execution authority'
