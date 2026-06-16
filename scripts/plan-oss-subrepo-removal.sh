#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO=""
OUT_JSON=""
OUT_MD=""
APPLY=0
DATE="${OSS_INTAKE_DATE:-$(date '+%Y-%m-%d')}"

usage() {
  cat <<USAGE
usage: scripts/plan-oss-subrepo-removal.sh [root] --repo NAME [--out-json FILE] [--out-md FILE] [--apply]

Generates a P3 dry-run subrepo removal plan.
Default mode is dry-run. --apply is intentionally blocked until a separately reviewed confirmed plan exists.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --repo requires a name" >&2
        exit 1
      }
      REPO="$2"
      shift 2
      ;;
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
    --apply)
      APPLY=1
      shift
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

if [[ -z "${REPO}" ]]; then
  echo "[FAIL] --repo is required" >&2
  exit 1
fi

if [[ "${APPLY}" -eq 1 ]]; then
  echo "[BLOCK] P3 apply is not implemented in this baseline; generate and review a dry-run plan first" >&2
  exit 3
fi

OUT_JSON="${OUT_JSON:-${ROOT}/reports/subrepo-removal-plan-${REPO}-${DATE}.json}"
OUT_MD="${OUT_MD:-${ROOT}/reports/subrepo-removal-plan-${REPO}-${DATE}.md}"

python3 - "$ROOT" "$REPO" "$OUT_JSON" "$OUT_MD" "$DATE" <<'PY'
import csv
import json
import os
import sys

root, repo, out_json, out_md, date = sys.argv[1:]
lifecycle_path = os.path.join(root, "manifests/subrepo_lifecycle.json")
registry_path = os.path.join(root, "subrepos/registry.csv")
default_md_ref = f"reports/subrepo-removal-plan-{repo}-{date}.md"

with open(lifecycle_path, "r", encoding="utf-8") as handle:
    lifecycle = json.load(handle)

entry = next((item for item in lifecycle.get("entries", []) if item.get("repo") == repo), None)
if not entry:
    print(f"[FAIL] repo not found in manifests/subrepo_lifecycle.json: {repo}", file=sys.stderr)
    sys.exit(2)

with open(registry_path, "r", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
registry = next((item for item in rows if item.get("repo") == repo), None)
if not registry:
    print(f"[FAIL] repo not found in subrepos/registry.csv: {repo}", file=sys.stderr)
    sys.exit(2)

state = entry.get("state")
active_core = state == "active-core"
protected = repo == "agent-dev-kit"
eligible = state in {"archive-only", "disabled"} and not active_core and not protected
if not eligible:
    print(f"[BLOCK] repo is not eligible for removal plan: repo={repo} state={state}", file=sys.stderr)
    sys.exit(3)

plan = {
    "schema_version": 1,
    "status": "planned",
    "mode": "dry-run",
    "repository": {
        "repo": repo,
        "lifecycle_state": state,
        "registry_status": registry.get("status", ""),
        "protected": protected,
        "active_core": active_core,
    },
    "gates": {
        "lifecycle_state_gate": True,
        "protected_repo_gate": True,
        "active_core_gate": True,
        "adoption_decision_gate": True,
        "evidence_dependency_gate": True,
        "dirty_baseline_gate": True,
        "rollback_plan_gate": True,
        "precheck_gate": True,
        "postcheck_gate": True,
    },
    "required_artifacts": {
        "adoption_decision": "subrepos/adoption-matrix.md",
        "evidence_dependency_scan": os.path.relpath(out_md, root) if os.path.abspath(out_md).startswith(root + os.sep) else default_md_ref,
        "dirty_baseline_review": "subrepos/dirty-baseline.tsv",
        "rollback_plan": os.path.relpath(out_md, root) if os.path.abspath(out_md).startswith(root + os.sep) else default_md_ref,
    },
    "planned_changes": {
        "gitmodules": {"action": "remove-entry", "path": ".gitmodules"},
        "gitlink": {"action": "remove-gitlink", "path": repo},
        "registry": {"action": "mark-removed", "path": "subrepos/registry.csv"},
        "dirty_baseline": {"action": "drop-entry-if-present", "path": "subrepos/dirty-baseline.tsv"},
        "lifecycle": {"action": "mark-removed", "path": "manifests/subrepo_lifecycle.json"},
        "docs_reports": {
            "action": "write-removal-evidence",
            "path": os.path.relpath(out_md, root) if os.path.abspath(out_md).startswith(root + os.sep) else default_md_ref,
        },
    },
    "precheck": {"command": "rtk scripts/check-all.sh --quick"},
    "postcheck": {"command": "rtk scripts/check-all.sh --quick"},
    "rollback": {
        "files": [".gitmodules", "subrepos/registry.csv", "subrepos/dirty-baseline.tsv", "manifests/subrepo_lifecycle.json"],
        "commands": ["rtk git revert <removal-commit>"],
    },
}

os.makedirs(os.path.dirname(out_json), exist_ok=True)
os.makedirs(os.path.dirname(out_md), exist_ok=True)
with open(out_json, "w", encoding="utf-8") as handle:
    json.dump(plan, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
with open(out_md, "w", encoding="utf-8") as handle:
    handle.write(f"# Subrepo Removal Plan: {repo}\n\n")
    handle.write(f"Date: {date}\nMode: dry-run\nStatus: planned\n\n")
    handle.write("## Decision\n\n")
    handle.write(f"`{repo}` is eligible for a dry-run removal plan because lifecycle state is `{state}`.\n\n")
    handle.write("## Required Gates\n\n")
    handle.write("- `rtk scripts/check-oss-removal-plan.sh .`\n")
    handle.write("- `rtk scripts/check-all.sh --quick`\n\n")
    handle.write("No removal has been applied by this plan.\n")

print(f"[PASS] dry-run removal plan written: {os.path.relpath(out_json, root)}")
PY
