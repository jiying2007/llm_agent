#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET_ID=""
PROFILE="minimal"
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-runtime-health.sh [root] [--target <id>] [--profile minimal|security|strict] [--summary-json]

Reads manifests/runtime_targets.json and dispatches to the declared runtime
health adapter. This command is read-only and does not apply assets.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

target_info="$(python3 - "${ROOT}" "${TARGET_ID}" <<'PY'
import json
import os
import sys

root, requested = sys.argv[1:3]
manifest_path = os.path.join(root, "manifests", "runtime_targets.json")
with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

target_id = requested or manifest.get("default_target")
target = next((item for item in manifest.get("targets", []) if item.get("id") == target_id), None)
if not target:
    raise SystemExit(f"[FAIL] runtime target not declared: {target_id}")
if target.get("enabled") is not True:
    raise SystemExit(f"[FAIL] runtime target is not enabled: {target_id}")

health_check = target.get("health_check") or ""
live_root = target.get("live_root") or ""
runtime = target.get("runtime") or ""
if not health_check or not live_root or not runtime:
    raise SystemExit(f"[FAIL] runtime target missing health fields: {target_id}")

print("\t".join([
    target_id,
    runtime,
    os.path.expanduser(live_root),
    health_check,
]))
PY
)"

IFS=$'\t' read -r TARGET_RUNTIME_ID RUNTIME_KIND LIVE_ROOT HEALTH_CHECK <<< "${target_info}"
HEALTH_SCRIPT="${ROOT}/${HEALTH_CHECK}"

if [[ ! -x "${HEALTH_SCRIPT}" ]]; then
  echo "[FAIL] runtime health adapter missing or not executable: ${HEALTH_CHECK}" >&2
  exit 2
fi

if [[ "${RUNTIME_KIND}" != "codex" ]]; then
  echo "[FAIL] no runtime health adapter dispatcher for runtime=${RUNTIME_KIND}" >&2
  exit 2
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  TMP_OUT="$(mktemp)"
  rc=0
  set +e
  "${HEALTH_SCRIPT}" "${LIVE_ROOT}" "${PROFILE}" >"${TMP_OUT}" 2>&1
  rc=$?
  set -e
  status="pass"
  [[ "${rc}" -ne 0 ]] && status="fail"
  summary="$(tr '\n' ' ' <"${TMP_OUT}" | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c 1-240)"
  rm -f "${TMP_OUT}"
  printf '{"status":"%s","target":%s,"runtime":%s,"live_root":%s,"profile":%s,"adapter":%s,"adapter_exit":%s,"summary":%s}\n' \
    "${status}" \
    "$(json_string "${TARGET_RUNTIME_ID}")" \
    "$(json_string "${RUNTIME_KIND}")" \
    "$(json_string "${LIVE_ROOT}")" \
    "$(json_string "${PROFILE}")" \
    "$(json_string "${HEALTH_CHECK}")" \
    "${rc}" \
    "$(json_string "${summary}")"
  exit "${rc}"
fi

echo "[INFO] runtime_target=${TARGET_RUNTIME_ID}"
echo "[INFO] runtime=${RUNTIME_KIND}"
echo "[INFO] live_root=${LIVE_ROOT}"
echo "[INFO] health_adapter=${HEALTH_CHECK}"
"${HEALTH_SCRIPT}" "${LIVE_ROOT}" "${PROFILE}"
