#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATE="${OSS_INTAKE_DATE:-$(date '+%Y-%m-%d')}"
OUT_JSON=""
OUT_MD=""
LEDGERS=()
RATE_LIMITS=()

usage() {
  cat <<USAGE
usage: scripts/generate-oss-intake-approval-queue.sh [root] [--ledger FILE] [--rate-limit FILE] [--out-json FILE] [--out-md FILE]

Generates a report-only OSS intake approval queue from local ledgers and plans.
It does not approve, apply, register, remove, absorb, commit, or push.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-json)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --out-json requires a file" >&2
        exit 1
      }
      OUT_JSON="$2"
      shift 2
      ;;
    --out-md)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --out-md requires a file" >&2
        exit 1
      }
      OUT_MD="$2"
      shift 2
      ;;
    --ledger)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --ledger requires a file" >&2
        exit 1
      }
      LEDGERS+=("$2")
      shift 2
      ;;
    --rate-limit)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --rate-limit requires a file" >&2
        exit 1
      }
      RATE_LIMITS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
    *)
      ROOT="$1"
      shift
      ;;
  esac
done

OUT_JSON="${OUT_JSON:-${ROOT}/reports/oss-intake-approval-queue-${DATE}.json}"
OUT_MD="${OUT_MD:-${ROOT}/reports/oss-intake-approval-queue-${DATE}.md}"

python3 - "$ROOT" "$OUT_JSON" "$OUT_MD" "$DATE" "${#LEDGERS[@]}" "${LEDGERS[@]}" "${#RATE_LIMITS[@]}" "${RATE_LIMITS[@]}" <<'PY'
import glob
import json
import os
import sys
from collections import Counter

root, out_json, out_md, date = sys.argv[1:5]
ledger_count = int(sys.argv[5])
explicit_ledgers = sys.argv[6:6 + ledger_count]
rate_count_index = 6 + ledger_count
rate_count = int(sys.argv[rate_count_index])
rate_limits = sys.argv[rate_count_index + 1:rate_count_index + 1 + rate_count]


def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path


def safe_default(path, default):
    abs_path = os.path.abspath(path)
    return rel(abs_path) if abs_path.startswith(os.path.abspath(root) + os.sep) else default


def evidence_ref(path):
    abs_path = os.path.abspath(path)
    root_abs = os.path.abspath(root)
    return rel(abs_path) if abs_path.startswith(root_abs + os.sep) else f"external/{os.path.basename(path)}"


items = []
seen = set()


def add_item(item):
    if item["id"] in seen:
        return
    seen.add(item["id"])
    items.append(item)


def existing_rel_paths(paths):
    rels = []
    for path in paths:
        abs_path = os.path.abspath(path)
        if os.path.isfile(abs_path):
            rels.append(evidence_ref(abs_path))
    return rels


ledger_paths = [os.path.abspath(path) for path in explicit_ledgers] if explicit_ledgers else sorted(glob.glob(os.path.join(root, "reports/oss-discovery-candidates-*.jsonl")))
rate_limit_evidence = existing_rel_paths(rate_limits)


for ledger_path in ledger_paths:
    with open(ledger_path, "r", encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = json.loads(line)
            repo = row.get("repo", "")
            if explicit_ledgers and (row.get("hard_rejects") or (row.get("source") == "github-search" and row.get("decision") == "discovered")):
                slug = repo.replace("/", "-")
                evidence = [evidence_ref(ledger_path)] + rate_limit_evidence + [item for item in row.get("evidence", []) if isinstance(item, str)]
                hard_rejects = row.get("hard_rejects", [])
                if hard_rejects:
                    reason = f"candidate requires L1 review before scoring; hard_rejects={','.join(hard_rejects)}"
                    next_step = "Review hard rejects and decide whether to reject, archive, or request corrected metadata."
                    status = "blocked"
                else:
                    reason = "GitHub metadata candidate requires L1 scoring triage before any onboarding review"
                    next_step = "Review metadata, then run scoring and security triage before any onboarding plan."
                    status = "pending-approval"
                add_item({
                    "id": f"candidate-review-{slug}",
                    "type": "candidate-review",
                    "approval_level": "L1-plan-review",
                    "repo": repo,
                    "status": status,
                    "reason": reason,
                    "evidence": evidence,
                    "recommended_next_step": next_step,
                    "blocked_auto_actions": ["candidate registration apply", "ADK absorption"],
                })
            if row.get("decision") != "onboard-candidate":
                continue
            slug = repo.replace("/", "-")
            plans = sorted(glob.glob(os.path.join(root, f"reports/oss-onboarding-plan-{slug}-*.json")))
            evidence = [evidence_ref(ledger_path)] + rate_limit_evidence
            if plans:
                evidence.append(rel(plans[-1]))
                reason = "onboard-candidate has a dry-run onboarding plan"
                next_step = "Review the dry-run onboarding plan before any metadata write."
            else:
                reason = "onboard-candidate is missing a dry-run onboarding plan"
                next_step = "Generate and review a dry-run onboarding plan before considering metadata apply."
            add_item({
                "id": f"candidate-registration-apply-{slug}",
                "type": "candidate-registration-apply",
                "approval_level": "L2-metadata-apply",
                "repo": repo,
                "status": "pending-approval",
                "reason": reason,
                "evidence": evidence,
                "recommended_next_step": next_step,
                "blocked_auto_actions": ["candidate registration apply", "ADK absorption"],
            })

for plan_path in sorted(glob.glob(os.path.join(root, "reports/subrepo-removal-plan-*.json"))):
    with open(plan_path, "r", encoding="utf-8") as handle:
        plan = json.load(handle)
    repo = plan.get("repository", {}).get("repo", "")
    if not repo:
        continue
    add_item({
        "id": f"subrepo-removal-apply-{repo}",
        "type": "subrepo-removal-apply",
        "approval_level": "L3-destructive-or-live-apply",
        "repo": repo,
        "status": "pending-approval",
        "reason": "subrepo has a dry-run removal plan",
        "evidence": [rel(plan_path)],
        "recommended_next_step": "Review the dry-run removal plan; P3 apply mode remains blocked in this baseline.",
        "blocked_auto_actions": ["subrepo removal apply", "source-to-live apply"],
    })

for cycle_path in sorted(glob.glob(os.path.join(root, "reports/oss-intake-cycle-*.json"))):
    with open(cycle_path, "r", encoding="utf-8") as handle:
        cycle = json.load(handle)
    if cycle.get("status") == "pass":
        continue
    add_item({
        "id": f"cycle-gate-review-{os.path.basename(cycle_path).removesuffix('.json')}",
        "type": "cycle-gate-review",
        "approval_level": "L1-plan-review",
        "repo": "llm_agent",
        "status": "blocked",
        "reason": "OSS intake cycle contains a failing gate",
        "evidence": [rel(cycle_path)],
        "recommended_next_step": "Review failing cycle gates and rerun the report-only cycle after fixes.",
        "blocked_auto_actions": ["candidate registration apply", "subrepo removal apply"],
    })

type_counts = Counter(item["type"] for item in items)
level_counts = Counter(item["approval_level"] for item in items)
queue = {
    "schema_version": 1,
    "status": "needs-approval" if items else "empty",
    "mode": "report-only",
    "date": date,
    "summary": {
        "items": len(items),
        "by_type": dict(type_counts),
        "by_level": dict(level_counts),
    },
    "items": items,
}

os.makedirs(os.path.dirname(out_json), exist_ok=True)
os.makedirs(os.path.dirname(out_md), exist_ok=True)
with open(out_json, "w", encoding="utf-8") as handle:
    json.dump(queue, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
with open(out_md, "w", encoding="utf-8") as handle:
    handle.write("# OSS Intake Approval Queue\n\n")
    handle.write(f"Date: {date}\nMode: report-only\nStatus: {queue['status']}\n\n")
    handle.write("## Items\n\n")
    if items:
        handle.write("| id | type | level | repo | status |\n")
        handle.write("|---|---|---|---|---|\n")
        for item in items:
            handle.write(f"| {item['id']} | {item['type']} | {item['approval_level']} | {item['repo']} | {item['status']} |\n")
    else:
        handle.write("No approval items.\n")
    handle.write("\nNo approval has been executed by this report.\n")

print(f"[PASS] approval queue written: {safe_default(out_json, f'reports/oss-intake-approval-queue-{date}.json')} items={len(items)}")
PY

"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --queue "${OUT_JSON}" --summary-json >/dev/null
