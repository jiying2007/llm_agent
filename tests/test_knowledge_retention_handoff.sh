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

echo '[PASS] knowledge retention handoff is sanitized, dry-run-only, and owner-review bounded'
