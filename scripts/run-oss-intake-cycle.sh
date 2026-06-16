#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATE="${OSS_INTAKE_DATE:-$(date '+%Y-%m-%d')}"
OUT_JSON=""
OUT_MD=""
QUEUE_JSON=""
QUEUE_MD=""
EVIDENCE_MD=""
DISCOVER=0
DISCOVERY_OUT=""

usage() {
  cat <<USAGE
usage: scripts/run-oss-intake-cycle.sh [root] [--discover] [--discovery-out FILE] [--out-json FILE] [--out-md FILE] [--queue-json FILE] [--queue-md FILE] [--evidence-md FILE]

Runs the P4 OSS intake cycle in report-only mode.
It runs local gates and writes an audit report; it does not fetch, register, remove, absorb, or apply assets.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --discover)
      DISCOVER=1
      shift
      ;;
    --discovery-out)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --discovery-out requires a file" >&2
        exit 1
      }
      DISCOVERY_OUT="$2"
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
    --queue-json)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --queue-json requires a file" >&2
        exit 1
      }
      QUEUE_JSON="$2"
      shift 2
      ;;
    --queue-md)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --queue-md requires a file" >&2
        exit 1
      }
      QUEUE_MD="$2"
      shift 2
      ;;
    --evidence-md)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --evidence-md requires a file" >&2
        exit 1
      }
      EVIDENCE_MD="$2"
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

OUT_JSON="${OUT_JSON:-${ROOT}/reports/oss-intake-cycle-${DATE}.json}"
OUT_MD="${OUT_MD:-${ROOT}/reports/oss-intake-cycle-${DATE}.md}"
QUEUE_JSON="${QUEUE_JSON:-${ROOT}/reports/oss-intake-approval-queue-${DATE}.json}"
QUEUE_MD="${QUEUE_MD:-${ROOT}/reports/oss-intake-approval-queue-${DATE}.md}"
EVIDENCE_MD="${EVIDENCE_MD:-${ROOT}/reports/oss-intake-evidence-bundle-${DATE}.md}"
DISCOVERY_OUT="${DISCOVERY_OUT:-${ROOT}/reports/oss-discovery-candidates-${DATE}.jsonl}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
GATE_NAMES=()

run_gate() {
  local name="$1"
  local command="$2"
  shift 2
  local rc=0
  set +e
  "$@" >"${TMP_DIR}/${name}.out" 2>&1
  rc=$?
  set -e
  printf '%s\n' "${rc}" >"${TMP_DIR}/${name}.rc"
  printf '%s\n' "${command}" >"${TMP_DIR}/${name}.cmd"
  GATE_NAMES+=("${name}")
}

if [[ "${DISCOVER}" -eq 1 ]]; then
  run_gate discover-oss-repos "rtk scripts/discover-oss-repos.sh . --dry-run" "${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --out "${DISCOVERY_OUT}"
fi
run_gate check-oss-intake-ledger "rtk scripts/check-oss-intake-ledger.sh ." "${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}"
run_gate check-oss-registration-plan "rtk scripts/check-oss-registration-plan.sh ." "${ROOT}/scripts/check-oss-registration-plan.sh" "${ROOT}"
run_gate check-oss-removal-plan "rtk scripts/check-oss-removal-plan.sh ." "${ROOT}/scripts/check-oss-removal-plan.sh" "${ROOT}"
run_gate generate-oss-intake-approval-queue "rtk scripts/generate-oss-intake-approval-queue.sh ." "${ROOT}/scripts/generate-oss-intake-approval-queue.sh" "${ROOT}" --out-json "${QUEUE_JSON}" --out-md "${QUEUE_MD}"
run_gate check-oss-approval-queue "rtk scripts/check-oss-approval-queue.sh ." "${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --queue "${QUEUE_JSON}"

overall="pass"
for rc_file in "${TMP_DIR}"/*.rc; do
  if [[ "$(cat "${rc_file}")" -ne 0 ]]; then
    overall="fail"
  fi
done

python3 - "$ROOT" "$TMP_DIR" "$OUT_JSON" "$OUT_MD" "$QUEUE_JSON" "$QUEUE_MD" "$EVIDENCE_MD" "$DATE" "$overall" "${GATE_NAMES[@]}" <<'PY'
import json
import os
import sys

root, tmp_dir, out_json, out_md, queue_json, queue_md, evidence_md, date, overall = sys.argv[1:10]
names = sys.argv[10:]
default_json_ref = f"reports/oss-intake-cycle-{date}.json"
default_md_ref = f"reports/oss-intake-cycle-{date}.md"
default_queue_json_ref = f"reports/oss-intake-approval-queue-{date}.json"
default_queue_md_ref = f"reports/oss-intake-approval-queue-{date}.md"
default_evidence_ref = f"reports/oss-intake-evidence-bundle-{date}.md"
json_ref = os.path.relpath(out_json, root) if os.path.abspath(out_json).startswith(root + os.sep) else default_json_ref
md_ref = os.path.relpath(out_md, root) if os.path.abspath(out_md).startswith(root + os.sep) else default_md_ref
queue_json_ref = os.path.relpath(queue_json, root) if os.path.abspath(queue_json).startswith(root + os.sep) else default_queue_json_ref
queue_md_ref = os.path.relpath(queue_md, root) if os.path.abspath(queue_md).startswith(root + os.sep) else default_queue_md_ref
evidence_ref = os.path.relpath(evidence_md, root) if os.path.abspath(evidence_md).startswith(root + os.sep) else default_evidence_ref
commands = []
for name in names:
    with open(os.path.join(tmp_dir, f"{name}.cmd"), "r", encoding="utf-8") as handle:
        command = handle.read().strip()
    with open(os.path.join(tmp_dir, f"{name}.rc"), "r", encoding="utf-8") as handle:
        rc = int(handle.read().strip())
    commands.append({"name": name, "command": command, "status": "pass" if rc == 0 else "fail"})

report = {
    "schema_version": 1,
    "status": overall,
    "mode": "report-only",
    "date": date,
    "commands": commands,
    "approval_required_before": [
        "network discovery",
        "candidate registration apply",
        "subrepo removal apply",
        "ADK absorption",
        "source-to-live apply",
    ],
    "outputs": [json_ref, md_ref, queue_json_ref, queue_md_ref, evidence_ref],
}

os.makedirs(os.path.dirname(out_json), exist_ok=True)
os.makedirs(os.path.dirname(out_md), exist_ok=True)
with open(out_json, "w", encoding="utf-8") as handle:
    json.dump(report, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
with open(out_md, "w", encoding="utf-8") as handle:
    handle.write("# OSS Intake Cycle\n\n")
    handle.write(f"Date: {date}\nMode: report-only\nStatus: {overall}\n\n")
    handle.write("## Checks\n\n")
    for item in commands:
        handle.write(f"- `{item['command']}`: {item['status']}\n")
    handle.write("\n## Approval Boundaries\n\n")
    for item in report["approval_required_before"]:
        handle.write(f"- {item}\n")
    handle.write("\n## Generated Artifacts\n\n")
    for item in report["outputs"]:
        handle.write(f"- `{item}`\n")

os.makedirs(os.path.dirname(evidence_md), exist_ok=True)
with open(evidence_md, "w", encoding="utf-8") as handle:
    handle.write("# OSS Intake Evidence Bundle\n\n")
    handle.write(f"Date: {date}\nMode: report-only\nStatus: {overall}\n\n")
    handle.write("## Artifacts\n\n")
    for item in report["outputs"]:
        handle.write(f"- `{item}`\n")
    handle.write("\n## Commands\n\n")
    for item in commands:
        handle.write(f"- `{item['command']}`: {item['status']}\n")
    handle.write("\n## Boundary\n\n")
    handle.write("This bundle records evidence only. It does not approve, apply, remove, absorb, commit, push, or modify live Codex assets.\n")

print(f"[PASS] oss intake cycle report written: {os.path.relpath(out_json, root)}")
if overall != "pass":
    sys.exit(2)
PY
