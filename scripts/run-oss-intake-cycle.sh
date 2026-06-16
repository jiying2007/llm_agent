#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATE="${OSS_INTAKE_DATE:-2026-06-16}"
OUT_JSON=""
OUT_MD=""

usage() {
  cat <<USAGE
usage: scripts/run-oss-intake-cycle.sh [root] [--out-json FILE] [--out-md FILE]

Runs the P4 OSS intake cycle in report-only mode.
It runs local gates and writes an audit report; it does not fetch, register, remove, absorb, or apply assets.
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

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
}

run_gate check-oss-intake-ledger "rtk scripts/check-oss-intake-ledger.sh ." "${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}"
run_gate check-oss-registration-plan "rtk scripts/check-oss-registration-plan.sh ." "${ROOT}/scripts/check-oss-registration-plan.sh" "${ROOT}"
run_gate check-oss-removal-plan "rtk scripts/check-oss-removal-plan.sh ." "${ROOT}/scripts/check-oss-removal-plan.sh" "${ROOT}"

overall="pass"
for rc_file in "${TMP_DIR}"/*.rc; do
  if [[ "$(cat "${rc_file}")" -ne 0 ]]; then
    overall="fail"
  fi
done

python3 - "$ROOT" "$TMP_DIR" "$OUT_JSON" "$OUT_MD" "$DATE" "$overall" <<'PY'
import json
import os
import sys

root, tmp_dir, out_json, out_md, date, overall = sys.argv[1:]
default_json_ref = f"reports/oss-intake-cycle-{date}.json"
default_md_ref = f"reports/oss-intake-cycle-{date}.md"
json_ref = os.path.relpath(out_json, root) if os.path.abspath(out_json).startswith(root + os.sep) else default_json_ref
md_ref = os.path.relpath(out_md, root) if os.path.abspath(out_md).startswith(root + os.sep) else default_md_ref
names = [
    "check-oss-intake-ledger",
    "check-oss-registration-plan",
    "check-oss-removal-plan",
]
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
    "outputs": [json_ref, md_ref],
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

print(f"[PASS] oss intake cycle report written: {os.path.relpath(out_json, root)}")
if overall != "pass":
    sys.exit(2)
PY
