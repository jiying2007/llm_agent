#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

usage() {
  cat <<USAGE
Usage:
  scripts/check-openai-adoption-review.sh [ROOT]

Checks the OpenAI official-docs freshness and adoption review chain:
  official source freshness -> adoption needs-review -> target evidence -> review queue

Environment:
  OPENAI_ADOPTION_REVIEW_TODAY=YYYY-MM-DD  Override today's date for fixtures.
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

python3 - "$ROOT" <<'PY'
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

root = Path(sys.argv[1])
queue = []

def add(kind, item_id, reason, action, next_action):
    queue.append(
        {
            "type": kind,
            "id": item_id,
            "reason": reason,
            "action": action,
            "next_action": next_action,
        }
    )

def load_json(path, label):
    if not path.is_file():
        add("file", label, "missing-file", "fail", f"restore {path.relative_to(root)}")
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add("file", label, f"invalid-json:{exc}", "fail", f"fix JSON syntax in {path.relative_to(root)}")
        return {}

def parse_date(value):
    try:
        return dt.date.fromisoformat(value)
    except (TypeError, ValueError):
        return None

def clean_cell(value):
    return value.strip().strip("`")

def split_md_row(line):
    cells = [clean_cell(part) for part in line.strip().strip("|").split("|")]
    return cells if len(cells) >= 11 else []

def evidence_paths(evidence, prefixes):
    for item in re.split(r"[;,]", evidence or ""):
        path = item.strip().strip("`")
        if not path:
            continue
        path = path.split("#", 1)[0].strip()
        if any(path.startswith(prefix) for prefix in prefixes):
            yield path

def has_existing_evidence(evidence, prefixes):
    return any((root / path).exists() for path in evidence_paths(evidence, prefixes))

def check_adoption_row(row, item_id, prefixes, missing_action):
    repo = row.get("repo") or row.get("来源仓库") or ""
    decision = row.get("decision") or row.get("决策") or ""
    state = row.get("state") or row.get("验收状态") or ""
    target = row.get("target") or row.get("回灌目标") or ""
    evidence = row.get("evidence") or row.get("证据") or ""
    if repo != "OpenAI Developers":
        return False
    if decision not in {"adopt", "observe"}:
        return False
    if state != "done":
        return False
    if "agent-dev-kit" not in target:
        return False
    if not has_existing_evidence(evidence, prefixes):
        add(
            "adoption",
            item_id,
            "missing-target-evidence",
            missing_action,
            "add an existing agent-dev-kit/... evidence path or move row out of done",
        )
    return True

today_raw = os.environ.get("OPENAI_ADOPTION_REVIEW_TODAY")
today = parse_date(today_raw) if today_raw else dt.date.today()
if today is None:
    add("config", "OPENAI_ADOPTION_REVIEW_TODAY", "invalid-date", "fail", "use YYYY-MM-DD")
    today = dt.date.today()

manifest_path = root / "agent-dev-kit/manifests/official_docs_freshness_gates.json"
manifest = load_json(manifest_path, "official-docs-freshness-gates")
review_policy = manifest.get("review_policy", {})
adoption_policy = manifest.get("adoption_review_policy", {})
allowed_domains = set(review_policy.get("allowed_domains", []))
review_status_values = set(review_policy.get("review_status_values", []))
required_fields = list(review_policy.get("required_fields", []))
for extra in ("url", "retrieved_at", "review_status", "expires_at", "adoption_scope"):
    if extra not in required_fields:
        required_fields.append(extra)

source_expiry_action = adoption_policy.get("source_expiry_action", "needs-review")
missing_review_status_action = adoption_policy.get("missing_review_status_action", "fail")
missing_target_evidence_action = adoption_policy.get("missing_target_evidence_action", "fail")
prefixes = adoption_policy.get("required_target_evidence_prefixes") or ["agent-dev-kit/"]

if adoption_policy.get("review_queue_output") != "stdout":
    add(
        "policy",
        "adoption_review_policy.review_queue_output",
        "invalid-review-queue-output",
        "fail",
        "set review_queue_output to stdout",
    )

for linked in (
    "agent-dev-kit/docs/reference-adoption-matrix.md",
    "subrepos/adoption-matrix.jsonl",
):
    if linked not in adoption_policy.get("linked_matrices", []):
        add("policy", linked, "missing-linked-matrix", "fail", "add linked matrix to adoption_review_policy")

sources = manifest.get("sources", [])
if not sources:
    add("source", "official-docs-freshness-gates", "empty-sources", "fail", "add official docs sources")

for idx, source in enumerate(sources, 1):
    sid = source.get("id") or f"source#{idx}"
    for field in required_fields:
        if source.get(field) in ("", None, []):
            action = missing_review_status_action if field == "review_status" else "fail"
            add("source", sid, f"missing-source-field:{field}", action, f"fill {field} in official docs source")
    url = source.get("url", "")
    if url:
        domain = urlparse(url).netloc
        if allowed_domains and domain not in allowed_domains:
            add("source", sid, f"non-official-domain:{domain}", "fail", "replace with an allowed OpenAI official docs URL")
    status = source.get("review_status")
    if status not in review_status_values:
        add("source", sid, f"invalid-review-status:{status}", missing_review_status_action, "set review_status to an allowed value")
    expires_at = parse_date(source.get("expires_at"))
    if expires_at is None:
        add("source", sid, "invalid-expires-at", "fail", "set expires_at as YYYY-MM-DD")
    elif expires_at < today:
        add("source", sid, "source-expired", source_expiry_action, "refresh official docs source and update adoption decision")

jsonl_checked = 0
jsonl_path = root / "subrepos/adoption-matrix.jsonl"
if not jsonl_path.is_file():
    add("adoption", "subrepos/adoption-matrix.jsonl", "missing-file", "fail", "restore structured adoption matrix")
else:
    for lineno, line in enumerate(jsonl_path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            add("adoption", f"jsonl:{lineno}", f"invalid-jsonl:{exc}", "fail", "fix adoption matrix JSONL row")
            continue
        if check_adoption_row(row, f"subrepos/adoption-matrix.jsonl:{lineno}", prefixes, missing_target_evidence_action):
            jsonl_checked += 1

ref_checked = 0
ref_path = root / "agent-dev-kit/docs/reference-adoption-matrix.md"
if not ref_path.is_file():
    add("adoption", "agent-dev-kit/docs/reference-adoption-matrix.md", "missing-file", "fail", "restore ADK reference adoption matrix")
else:
    for lineno, line in enumerate(ref_path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.startswith("| 20"):
            continue
        cells = split_md_row(line)
        if not cells:
            continue
        row = {
            "date": cells[0],
            "repo": cells[1],
            "category": cells[2],
            "capability": cells[3],
            "decision": cells[7],
            "state": cells[8],
            "target": cells[9],
            "evidence": cells[10],
        }
        if check_adoption_row(row, f"agent-dev-kit/docs/reference-adoption-matrix.md:{lineno}", prefixes, missing_target_evidence_action):
            ref_checked += 1

if queue:
    print(f"[FAIL] openai adoption review queue has {len(queue)} item(s)", file=sys.stderr)
    for item in queue:
        print(
            "  - "
            f"type={item['type']} id={item['id']} reason={item['reason']} "
            f"action={item['action']} next={item['next_action']}",
            file=sys.stderr,
        )
    sys.exit(1)

print(
    "[PASS] openai adoption review ready "
    f"sources={len(sources)} root_rows={jsonl_checked} reference_rows={ref_checked} today={today.isoformat()}"
)
PY
