#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LEDGER=""
REPO=""
ANALYSIS=""
DUPLICATE_CHECK=""
SECURITY_REVIEW=""
OUT_JSON=""
OUT_MD=""
APPLY=0
SUBMODULE_SOURCE=""
TARGET_PATH=""
BRANCH="main"
PRIORITY="P1"
GRADE="A"
OWNER="adk-team"
INTAKE_POLICY="observe-first"
DATE="$(date '+%Y-%m-%d')"
MATERIALIZATION="metadata-only"

usage() {
  cat <<USAGE
usage: scripts/onboard-oss-candidate.sh [root] --ledger FILE --repo owner/name \\
  --analysis FILE --duplicate-check FILE --security-review FILE [--out-json FILE] [--out-md FILE] [--apply --materialization metadata-only|local-submodule]

Generates a gated P2 onboarding plan for an onboard-candidate.
Default mode is dry-run. Apply mode defaults to metadata-only registration and updates
.gitmodules metadata, subrepos/registry.csv, subrepos/adoption-matrix.md,
subrepos/adoption-matrix.jsonl, and manifests/subrepo_lifecycle.json.
local-submodule materialization requires --submodule-source pointing to a reviewed local clone/mirror.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger) LEDGER="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --analysis) ANALYSIS="${2:-}"; shift 2 ;;
    --duplicate-check) DUPLICATE_CHECK="${2:-}"; shift 2 ;;
    --security-review) SECURITY_REVIEW="${2:-}"; shift 2 ;;
    --out-json) OUT_JSON="${2:-}"; shift 2 ;;
    --out-md) OUT_MD="${2:-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --submodule-source) SUBMODULE_SOURCE="${2:-}"; shift 2 ;;
    --materialization) MATERIALIZATION="${2:-}"; shift 2 ;;
    --target-path) TARGET_PATH="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --priority) PRIORITY="${2:-}"; shift 2 ;;
    --grade) GRADE="${2:-}"; shift 2 ;;
    --owner) OWNER="${2:-}"; shift 2 ;;
    --intake-policy) INTAKE_POLICY="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
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

[[ -n "${LEDGER}" && -n "${REPO}" && -n "${ANALYSIS}" && -n "${DUPLICATE_CHECK}" && -n "${SECURITY_REVIEW}" ]] || {
  echo "[FAIL] --ledger, --repo, --analysis, --duplicate-check and --security-review are required" >&2
  exit 1
}

if [[ "${MATERIALIZATION}" != "metadata-only" && "${MATERIALIZATION}" != "local-submodule" ]]; then
  echo "[FAIL] --materialization must be metadata-only or local-submodule" >&2
  exit 1
fi

if [[ "${APPLY}" -eq 1 && "${MATERIALIZATION}" == "local-submodule" && -z "${SUBMODULE_SOURCE}" ]]; then
  echo "[FAIL] local-submodule apply requires --submodule-source pointing to a local reviewed clone/mirror" >&2
  exit 1
fi

REPO_SLUG="${REPO#*/}"
TARGET_PATH="${TARGET_PATH:-${REPO_SLUG}}"
OUT_JSON="${OUT_JSON:-${ROOT}/reports/oss-onboarding-plan-${REPO//\//-}-${DATE}.json}"
OUT_MD="${OUT_MD:-${ROOT}/reports/oss-onboarding-plan-${REPO//\//-}-${DATE}.md}"

"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${LEDGER}" >/dev/null

python3 - "${ROOT}" "${LEDGER}" "${REPO}" "${ANALYSIS}" "${DUPLICATE_CHECK}" "${SECURITY_REVIEW}" "${OUT_JSON}" "${OUT_MD}" "${APPLY}" "${SUBMODULE_SOURCE}" "${TARGET_PATH}" "${BRANCH}" "${PRIORITY}" "${GRADE}" "${OWNER}" "${INTAKE_POLICY}" "${DATE}" "${MATERIALIZATION}" <<'PY'
import csv
import json
import os
import sys

root, ledger_path, repo, analysis, duplicate_check, security_review, out_json, out_md = [os.path.abspath(sys.argv[i]) if i in {1,2,4,5,6,7,8} else sys.argv[i] for i in range(1, 9)]
apply_mode = sys.argv[9] == "1"
submodule_source = sys.argv[10]
target_path = sys.argv[11]
branch = sys.argv[12]
priority = sys.argv[13]
grade = sys.argv[14]
owner = sys.argv[15]
intake_policy = sys.argv[16]
date = sys.argv[17]
materialization = sys.argv[18]

repo_name = repo.split("/", 1)[1]

def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path

def require_file(path, label):
    if not os.path.isfile(path):
        raise SystemExit(f"[FAIL] missing {label}: {path}")

for path, label in (
    (ledger_path, "ledger"),
    (analysis, "analysis report"),
    (duplicate_check, "duplicate check"),
    (security_review, "security review"),
):
    require_file(path, label)

candidate = None
with open(ledger_path, "r", encoding="utf-8") as handle:
    for line in handle:
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("repo") == repo:
            candidate = row
            break
if candidate is None:
    raise SystemExit(f"[FAIL] candidate not found in ledger: {repo}")

registry_path = os.path.join(root, "subrepos/registry.csv")
matrix_path = os.path.join(root, "subrepos/adoption-matrix.md")
lifecycle_path = os.path.join(root, "manifests/subrepo_lifecycle.json")

registry_conflict = False
with open(registry_path, "r", encoding="utf-8", newline="") as handle:
    for row in csv.DictReader(handle):
        if row.get("repo") == repo_name:
            registry_conflict = True
            break

target_abs = os.path.join(root, target_path)
target_path_conflict = os.path.exists(target_abs)

phase_gate = False
with open(os.path.join(root, "subrepos/phase-gate.env"), "r", encoding="utf-8") as handle:
    for line in handle:
        if line.strip() == "allow_upstream_sync=yes":
            phase_gate = True
            break

gates = {
    "candidate_score_gate": candidate.get("score", 0) >= 90 and candidate.get("decision") == "onboard-candidate",
    "hard_reject_gate": candidate.get("hard_rejects") == [],
    "analysis_report_gate": True,
    "duplicate_check_gate": True,
    "security_review_gate": True,
    "phase_gate": phase_gate,
    "registry_conflict_gate": not registry_conflict,
    "target_path_gate": not target_path_conflict,
    "materialization_gate": materialization == "metadata-only" or bool(submodule_source),
    "rollback_plan_gate": True,
}

plan = {
    "schema_version": 1,
    "status": "planned",
    "mode": "apply" if apply_mode else "dry-run",
    "candidate": {
        "repo": candidate["repo"],
        "url": candidate["url"],
        "score": candidate["score"],
        "decision": candidate["decision"],
        "domain_fit": candidate["domain_fit"],
        "hard_rejects": candidate["hard_rejects"],
    },
    "gates": gates,
    "required_artifacts": {
        "ledger": rel(ledger_path),
        "analysis_report": rel(analysis),
        "duplicate_check": rel(duplicate_check),
        "security_review": rel(security_review),
    },
    "planned_changes": {
        "registry": {
            "repo": repo_name,
            "group": candidate["domain_fit"],
            "priority": priority,
            "sync_mode": "fetch",
            "branch": branch,
            "enabled": "yes",
            "notes": "OSS intake P2 onboard-candidate",
            "status": "active",
            "owner": owner,
            "last_reviewed_on": date,
            "intake_policy": intake_policy,
            "grade": grade,
        },
        "gitmodules": {
            "name": repo_name,
            "path": target_path,
            "url": candidate["url"],
            "materialization": materialization,
        },
        "adoption_matrix": {
            "date": date,
            "source_repo": repo_name,
            "category": candidate["domain_fit"],
            "capability": "P2 gated onboarding candidate",
            "value": "高",
            "cost": "中",
            "risk": "中",
            "decision": "observe",
            "state": "pending",
            "target": "agent-dev-kit",
            "evidence": rel(out_md),
        },
    },
    "rollback": {
        "files": [
            ".gitmodules",
            "subrepos/registry.csv",
            "subrepos/adoption-matrix.md",
            "subrepos/adoption-matrix.jsonl",
            "manifests/subrepo_lifecycle.json",
        ],
        "commands": [
            f"rtk git submodule deinit -f {target_path}",
            f"rtk git rm -f {target_path}",
        ],
    },
}

if not all(gates.values()):
    failed = ", ".join(key for key, value in gates.items() if not value)
    raise SystemExit(f"[FAIL] onboarding gates failed: {failed}")

os.makedirs(os.path.dirname(out_json), exist_ok=True)
with open(out_json, "w", encoding="utf-8") as handle:
    json.dump(plan, handle, ensure_ascii=False, indent=2)
    handle.write("\n")

lines = [
    f"# OSS Onboarding Plan: {repo}",
    "",
    f"> Status: {'apply-ready' if apply_mode else 'dry-run'}",
    f"> Candidate: `{repo}`",
    "",
    "## Gates",
    "",
    "| gate | result |",
    "|---|---|",
]
for gate, value in gates.items():
    lines.append(f"| {gate} | {'pass' if value else 'fail'} |")
lines.extend([
    "",
    "## Planned Changes",
    "",
    f"- registry: `subrepos/registry.csv` row for `{repo_name}`",
    f"- submodule path: `{target_path}`",
    f"- materialization: `{materialization}`",
    f"- adoption matrix: `observe/pending` row with evidence `{rel(out_md)}`",
    "- ADK absorption: not performed in P2 registration",
    "",
    "## Rollback",
    "",
])
for command in plan["rollback"]["commands"]:
    lines.append(f"- `{command}`")
lines.append("")
with open(out_md, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))

print(f"[PASS] wrote onboarding plan: {rel(out_json)} and {rel(out_md)}")
PY

"${ROOT}/scripts/check-oss-registration-plan.sh" "${ROOT}" --no-fixtures --plan "${OUT_JSON}" >/dev/null

if [[ "${APPLY}" -eq 0 ]]; then
  exit 0
fi

if [[ "${MATERIALIZATION}" == "local-submodule" && ! -d "${SUBMODULE_SOURCE}" ]]; then
  echo "[FAIL] --submodule-source must be an existing local directory: ${SUBMODULE_SOURCE}" >&2
  exit 1
fi

if [[ "${MATERIALIZATION}" == "local-submodule" && -e "${ROOT}/${TARGET_PATH}" ]]; then
  echo "[FAIL] target path already exists: ${TARGET_PATH}" >&2
  exit 1
fi

if [[ "${MATERIALIZATION}" == "local-submodule" ]]; then
  rtk git -C "${ROOT}" submodule add --name "${REPO_SLUG}" "${SUBMODULE_SOURCE}" "${TARGET_PATH}"
else
  if rg -q "\\[submodule \"${REPO_SLUG}\"\\]" "${ROOT}/.gitmodules"; then
    echo "[FAIL] .gitmodules already contains ${REPO_SLUG}" >&2
    exit 1
  fi
  GITMODULE_URL="$(
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["planned_changes"]["gitmodules"]["url"])' "${OUT_JSON}"
  )"
  {
    printf '[submodule "%s"]\n' "${REPO_SLUG}"
    printf '\tpath = %s\n' "${TARGET_PATH}"
    printf '\turl = %s\n' "${GITMODULE_URL}"
  } >> "${ROOT}/.gitmodules"
fi

python3 - "${ROOT}" "${OUT_JSON}" <<'PY'
import csv
import json
import os
import sys

root = os.path.abspath(sys.argv[1])
plan_path = os.path.abspath(sys.argv[2])
with open(plan_path, "r", encoding="utf-8") as handle:
    plan = json.load(handle)

registry_path = os.path.join(root, "subrepos/registry.csv")
matrix_path = os.path.join(root, "subrepos/adoption-matrix.md")
lifecycle_path = os.path.join(root, "manifests/subrepo_lifecycle.json")

registry = plan["planned_changes"]["registry"]
with open(registry_path, "a", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=[
        "repo", "group", "priority", "sync_mode", "branch", "enabled", "notes",
        "status", "owner", "last_reviewed_on", "intake_policy", "grade"
    ])
    writer.writerow(registry)

matrix = plan["planned_changes"]["adoption_matrix"]
row = "| {date} | {source_repo} | {category} | {capability} | {value} | {cost} | {risk} | {decision} | {state} | {target} | {evidence} |\n".format(**matrix)
with open(matrix_path, "a", encoding="utf-8") as handle:
    handle.write(row)

with open(lifecycle_path, "r", encoding="utf-8") as handle:
    lifecycle = json.load(handle)
lifecycle["entries"].append({
    "repo": registry["repo"],
    "state": "active-reference",
    "owner": registry["owner"],
    "review_window": "quarterly",
    "automation_eligible": False,
    "evidence": [
        "subrepos/registry.csv",
        matrix["evidence"],
    ],
})
with open(lifecycle_path, "w", encoding="utf-8") as handle:
    json.dump(lifecycle, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

"${ROOT}/scripts/export-adoption-matrix-jsonl.sh" "${ROOT}" >/dev/null
echo "[PASS] applied gated onboarding registration for ${REPO}"
