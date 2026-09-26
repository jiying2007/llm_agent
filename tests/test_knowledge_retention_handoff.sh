#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.knowledge_retention_handoff --root "$ROOT" --summary-json >"$TMP"
python3 - "$ROOT" "$TMP" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1])
value=json.load(open(sys.argv[2],encoding="utf-8"))
assert value["schema"]=="llm-agent-knowledge-retention-handoff/v1", value
assert value["status"]=="pass", value
assert value["handoff_status"]=="ready-for-external-hub-dry-run", value
assert value["promotion_authorized"] is False, value
assert value["external_action_required"] is True, value
assert value["writes_knowledge_hub"] is False, value
assert value["writes_source_repository"] is False, value
boundary=value["knowledge_hub_boundary"]
assert boundary["capture_mode"]=="dry-run", boundary
assert boundary["target_status"]=="reviewing", boundary
assert boundary["promotion"]=="none", boundary
assert boundary["owner_review_required"] is True, boundary
candidate=root/value["candidate"]
raw=candidate.read_bytes()
assert hashlib.sha256(raw).hexdigest()==value["candidate_sha256"]
assert len(raw)==value["candidate_bytes"]
capture=value["commands"]["capture_dry_run"]
assert "knowledge-capture.sh" in capture and "--dry-run" in capture
assert "--status reviewing" in capture and "--generated-by-ai" in capture
assert "knowledge-promote.sh" not in capture and "--apply" not in capture
assert "knowledge-status.sh" in value["commands"]["status"]
text=raw.decode("utf-8")
assert "promotion: none" in text
assert "Knowledge Hub **dry-run capture 与 owner review**" in text
PY


EVIDENCE="$ROOT/reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json"
test -s "$EVIDENCE"
python3 - "$EVIDENCE" <<'PY'
import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
assert value["status"]=="pass", value
assert value["source"]["candidate_sha256"]=="3d56a96bba926f014fcf68de8bb880bdf2356d88651ca66a3964df41ac7fbd6d", value
assert value["schema"]=="llm-agent-g9-hub-handoff-evidence/v2", value
assert value["capture"]["status"]=="applied", value
assert value["capture"]["created_status"]=="reviewing", value
assert value["capture"]["promotion"]=="none", value
assert value["capture"]["manual_validation_pending"] is True, value
assert value["knowledge_hub"]["governed_capture"]["merged"] is True, value
assert value["knowledge_hub"]["governed_capture"]["final_pr_quality_conclusion"]=="success", value
assert value["knowledge_hub"]["governed_capture"]["security_review_conclusion"]=="success", value
assert value["knowledge_hub"]["governed_capture"]["post_merge_quality_run"]==36218784210, value
assert value["knowledge_hub"]["governed_capture"]["post_merge_quality_conclusion"]=="success", value\nassert value["authority_boundary"]["owner_review_recorded"] is False, value
assert value["authority_boundary"]["lifecycle_decision_recorded"] is False, value
assert value["authority_boundary"]["root_may_apply_or_promote"] is False, value
assert value["remaining_blocker"]=="real-human-owner-lifecycle-decision-in-knowledge-hub", value
PY

echo '[PASS] knowledge retention handoff is sanitized, Hub-evidenced, and owner-review bounded'
