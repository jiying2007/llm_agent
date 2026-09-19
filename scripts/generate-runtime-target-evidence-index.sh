#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET_ID=""
OUT=""
JSONL_OUT=""
FORMAT="markdown"

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

usage() {
  cat <<USAGE
usage: scripts/generate-runtime-target-evidence-index.sh [root] --target <id> [--format markdown|jsonl|both] [--out <path>] [--jsonl-out <path>]

Generates a runtime target activation Evidence Index draft. The command is
read-only unless --out or --jsonl-out is provided. It does not run apply,
rollback, health, footprint or source-to-live commands; it only turns the
declared target contract and explain-target result into an auditable checklist.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --jsonl-out)
      JSONL_OUT="${2:-}"
      shift 2
      ;;
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${TARGET_ID}" ]]; then
  echo "[FAIL] --target is required" >&2
  usage >&2
  exit 1
fi

case "${FORMAT}" in
  markdown|jsonl|both)
    ;;
  *)
    echo "[FAIL] unsupported --format: ${FORMAT}" >&2
    exit 1
    ;;
esac

python3 - "$ROOT" "$TARGET_ID" "$OUT" "$JSONL_OUT" "$FORMAT" <<'PY'
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

root, target_id, out_path, jsonl_out_path, output_format = sys.argv[1:6]
targets_path = os.path.join(root, "manifests", "runtime_targets.json")
explain_cmd = [
    os.path.join(root, "scripts", "check-runtime-targets.sh"),
    root,
    "--explain-target",
    target_id,
]


def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def target_prefix(value):
    return re.sub(r"[^A-Z0-9]+", "-", value.upper()).strip("-")


def md_escape(value):
    text = "" if value is None else str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def status_for(condition, blocked_reason="blocked"):
    return "planned" if condition else blocked_reason


def make_entry(evidence_id, gate, command, expected_result, write_scope, artifact_path,
               approval_required, approval_status, execution_status, result_summary,
               notes="", exit_code=None, layer="RuntimeTarget", related_artifact="-"):
    return {
        "schema_version": "runtime-target-evidence-index/v1",
        "evidence_id": evidence_id,
        "target_id": target_id,
        "runtime": target.get("runtime"),
        "gate": gate,
        "command": command,
        "exit_code": exit_code,
        "expected_result": expected_result,
        "result_summary": result_summary,
        "write_scope": write_scope,
        "artifact_path": artifact_path,
        "artifact_exists": os.path.exists(os.path.join(root, artifact_path)),
        "artifact_sha256": None,
        "layer": layer,
        "related_artifact": related_artifact,
        "approval_required": approval_required,
        "approval_status": approval_status,
        "approved_by": None,
        "approved_at": None,
        "approval_scope": None,
        "execution_status": execution_status,
        "created_at": generated_at,
        "notes": notes,
    }


try:
    manifest = read_json(targets_path)
except Exception as exc:
    print(f"[FAIL] failed to read runtime manifests: {exc}", file=sys.stderr)
    sys.exit(1)

targets = manifest.get("targets") or []
target = next((item for item in targets if item.get("id") == target_id), None)
if not target:
    print(f"[FAIL] runtime target not declared: {target_id}", file=sys.stderr)
    sys.exit(1)

explain_proc = subprocess.run(
    explain_cmd,
    cwd=root,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
if explain_proc.returncode != 0:
    print(explain_proc.stderr or explain_proc.stdout, file=sys.stderr)
    sys.exit(explain_proc.returncode)

try:
    explain = json.loads(explain_proc.stdout)
except Exception as exc:
    print(f"[FAIL] invalid explain-target JSON for {target_id}: {exc}", file=sys.stderr)
    sys.exit(1)

adapters = manifest.get("health_adapters") or []
adapter_id = target.get("health_adapter")
adapter = next((item for item in adapters if item.get("id") == adapter_id), None)

prefix = target_prefix(target_id)
report_dir = f"reports/runtime-target-activation/{target_id}"
enabled = target.get("enabled") is True
source_ready = bool(target.get("source_repo"))
live_ready = bool(target.get("live_root"))
chain_ready = bool(target.get("source_to_live_chain"))
adapter_ready = bool(adapter and adapter.get("enabled") is True and adapter.get("status") == "active")
activation_ready = explain.get("activation_ready") is True
generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

entries = [
    make_entry(
        f"{prefix}-DECL-001",
        "declare",
        f"rtk scripts/check-runtime-targets.sh . --explain-target {target_id}",
        "activation_ready=true for active targets; clear next_action for candidates",
        "read-only",
        f"{report_dir}/explain-target.json",
        "no",
        "not-required",
        "passed" if activation_ready else "blocked",
        f"explain-target returned activation_ready={str(activation_ready).lower()}; next_action={explain.get('next_action') or '-'}",
        exit_code=explain_proc.returncode,
    ),
    make_entry(
        f"{prefix}-TARGETS-001",
        "declare",
        "rtk scripts/check-runtime-targets.sh . --summary-json",
        "status=pass",
        "read-only",
        f"{report_dir}/runtime-targets.json",
        "no",
        "not-required",
        "planned",
        "not executed by generator; declaration gate must be run separately",
    ),
    make_entry(
        f"{prefix}-ADAPTERS-001",
        "health",
        "rtk scripts/check-runtime-health-adapters-fixtures.sh .",
        "fixture pass and adapter contract remains read-only",
        "workspace-local",
        f"{report_dir}/adapter-fixtures.md",
        "no",
        "not-required",
        status_for(adapter_ready, "blocked"),
        "not executed by generator; fixture proves adapter contract, not runtime health",
    ),
    make_entry(
        f"{prefix}-HEALTH-001",
        "health",
        f"rtk scripts/check-runtime-health.sh . --target {target_id} --profile minimal --summary-json",
        "status=pass",
        "read-only",
        f"{report_dir}/runtime-health.json",
        "no",
        "not-required",
        status_for(enabled and adapter_ready, "blocked"),
        "not executed by generator; candidate targets remain blocked until enabled",
    ),
    make_entry(
        f"{prefix}-FOOTPRINT-001",
        "footprint",
        target.get("footprint_check") or "<target footprint command>",
        "no missing required assets and no unexplained overwrite/delete",
        "read-only",
        f"{report_dir}/footprint-policy.json",
        "no",
        "not-required",
        status_for(enabled and bool(target.get("footprint_check")), "blocked"),
        "not executed by generator; footprint evidence must be captured separately",
    ),
    make_entry(
        f"{prefix}-PLAN-001",
        "dry-run",
        "<source repo plan command>",
        "plan generated and reviewed",
        "source-repo-only",
        f"{report_dir}/apply-plan.md",
        "no",
        "not-required",
        status_for(source_ready and chain_ready, "blocked"),
        "placeholder command; planned rows are not evidence",
        related_artifact="source-to-live plan",
    ),
    make_entry(
        f"{prefix}-DRYRUN-001",
        "dry-run",
        "<source repo apply dry-run>",
        "dry-run only; no live root write",
        "source-repo-only",
        f"{report_dir}/apply-dry-run.md",
        "no",
        "not-required",
        status_for(source_ready and chain_ready, "blocked"),
        "placeholder command; dry-run artifact must be attached before activation",
        related_artifact="source-to-live dry-run",
    ),
    make_entry(
        f"{prefix}-ROLLBACK-001",
        "rollback",
        "<rollback dry-run or documented procedure>",
        "rollback path reviewed; real rollback requires approval",
        "read-only",
        f"{report_dir}/rollback.md",
        "yes",
        "required",
        status_for(source_ready and live_ready, "blocked"),
        "real rollback is a live operation and requires explicit approval",
        related_artifact="rollback plan",
    ),
    make_entry(
        f"{prefix}-APPLY-001",
        "apply",
        "<source repo apply command>",
        "live root updated only within approved scope",
        "live-root",
        f"{report_dir}/apply-report.md",
        "yes",
        "required",
        "blocked",
        "real apply is blocked until approval, dry-run, rollback, health and footprint evidence are complete",
        related_artifact="apply report",
    ),
]

allowed_gates = {"declare", "dry-run", "health", "footprint", "apply", "rollback", "activation"}
allowed_scopes = {"read-only", "source-repo-only", "workspace-local", "live-root", "rollback-live-root"}
allowed_status = {"planned", "passed", "failed", "blocked", "approved"}
allowed_approval = {"not-required", "required", "approved", "denied", "expired"}
for entry in entries:
    if entry["gate"] not in allowed_gates:
        raise SystemExit(f"invalid gate: {entry['gate']}")
    if entry["write_scope"] not in allowed_scopes:
        raise SystemExit(f"invalid write scope: {entry['write_scope']}")
    if entry["execution_status"] not in allowed_status:
        raise SystemExit(f"invalid status: {entry['execution_status']}")
    if entry["approval_status"] not in allowed_approval:
        raise SystemExit(f"invalid approval_status: {entry['approval_status']}")
    if entry["write_scope"] in {"live-root", "rollback-live-root"} and entry["approval_required"] != "yes":
        raise SystemExit(f"live write row missing approval: {entry['evidence_id']}")
    if entry["execution_status"] in {"passed", "failed", "approved"} and entry["command"].startswith("<"):
        raise SystemExit(f"placeholder command cannot be completed evidence: {entry['evidence_id']}")

lines = [
    f"# Runtime Target Evidence Index: {target_id}",
    "",
    f"- generated_at: {generated_at}",
    f"- target_id: {target_id}",
    f"- runtime: {target.get('runtime')}",
    f"- enabled: {str(target.get('enabled')).lower()}",
    f"- role: {target.get('role')}",
    f"- source_repo: {target.get('source_repo') or '-'}",
    f"- live_root: {target.get('live_root') or '-'}",
    f"- health_adapter: {adapter_id or '-'}",
    f"- activation_ready: {str(activation_ready).lower()}",
    f"- next_action: {explain.get('next_action') or '-'}",
    f"- evidence_index_path: {report_dir}/evidence-index.md",
    f"- evidence_jsonl_path: {report_dir}/evidence-index.jsonl",
    "",
    "## Evidence Index",
    "",
    "| Evidence ID | Target ID | Gate | Command | Exit Code | Expected Result | Result Summary | Write Scope | Artifact / Report | Layer | Related Artifact | Approval Required | Approval Status | Status |",
    "|---|---|---|---|---:|---|---|---|---|---|---|---|---|---|",
]

for entry in entries:
    lines.append(
        "| "
        + " | ".join(
            md_escape(value)
            for value in (
                entry["evidence_id"],
                target_id,
                entry["gate"],
                f"`{entry['command']}`",
                "-" if entry["exit_code"] is None else entry["exit_code"],
                entry["expected_result"],
                entry["result_summary"],
                entry["write_scope"],
                f"`{entry['artifact_path']}`",
                entry["layer"],
                entry["related_artifact"],
                entry["approval_required"],
                entry["approval_status"],
                entry["execution_status"],
            )
        )
        + " |"
    )

lines.extend(
    [
        "",
        "## Boundaries",
        "",
        "- This file is a checklist draft, not proof that artifacts already exist.",
        "- `check-runtime-targets.sh` validates declarations and evidence categories only.",
        "- required_evidence is not artifact evidence; declaration gate only.",
        "- Real apply, live root writes and real rollback require explicit human approval.",
        "- Candidate targets remain blocked until source_repo, live_root, source_to_live_chain and a read-only active health adapter are declared.",
        "",
    ]
)

markdown_content = "\n".join(lines)
jsonl_content = "\n".join(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) for entry in entries) + "\n"

if output_format in {"markdown", "both"} and out_path:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(markdown_content)
    print(f"[PASS] runtime target evidence index written: {out_path}")
if output_format in {"jsonl", "both"} and jsonl_out_path:
    os.makedirs(os.path.dirname(jsonl_out_path), exist_ok=True)
    with open(jsonl_out_path, "w", encoding="utf-8") as handle:
        handle.write(jsonl_content)
    print(f"[PASS] runtime target evidence jsonl written: {jsonl_out_path}")

if output_format == "markdown" and not out_path:
    print(markdown_content, end="")
elif output_format == "jsonl" and not jsonl_out_path:
    print(jsonl_content, end="")
elif output_format == "both" and not out_path and not jsonl_out_path:
    print(markdown_content, end="")
PY
