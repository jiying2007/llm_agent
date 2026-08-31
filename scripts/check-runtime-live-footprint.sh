#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RUNTIME_ROOT="${HOME}/.codex"
RUNTIME_ROOT_EXPLICIT=0
SUMMARY_JSON=0
STRICT=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-root)
      RUNTIME_ROOT="${2:-}"
      RUNTIME_ROOT_EXPLICIT=1
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-runtime-live-footprint.sh [root] [--runtime-root <path>] [--summary-json] [--strict]

Checks the default target's declared runtime footprint: required ADK skills
must be live, while forbidden compatibility skills and paths must be absent.
Direct skills, system skills and versioned vendor skills are all inspected.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

TARGETS="${ROOT}/manifests/runtime_targets.json"
[[ -f "${TARGETS}" ]] || {
  echo "[FAIL] runtime targets missing: ${TARGETS}" >&2
  exit 1
}

if [[ "${RUNTIME_ROOT_EXPLICIT}" -eq 0 && -f "${TARGETS}" ]]; then
  RUNTIME_ROOT="$(python3 - "${TARGETS}" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

default_id = manifest.get("default_target")
target = next((item for item in manifest.get("targets", []) if item.get("id") == default_id), None)
if not target:
    raise SystemExit("runtime default target missing")
live_root = target.get("live_root")
if not live_root:
    raise SystemExit("runtime default live_root missing")
print(os.path.expanduser(live_root))
PY
)"
fi

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

manifest_values() {
  local field="$1"
  python3 - "${TARGETS}" "${field}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

target_id = manifest.get("default_target")
target = next((item for item in manifest.get("targets", []) if item.get("id") == target_id), None)
if not target:
    raise SystemExit("runtime default target missing")
footprint = target.get("runtime_footprint")
if not isinstance(footprint, dict):
    raise SystemExit("runtime default target footprint missing")
values = footprint.get(sys.argv[2])
if not isinstance(values, list):
    raise SystemExit("runtime footprint field must be an array")
for value in values:
    if not isinstance(value, str) or not value:
        raise SystemExit("runtime footprint values must be non-empty strings")
    print(value)
PY
}

skill_live_path() {
  local skill="$1"
  local found=""

  if [[ -f "${RUNTIME_ROOT}/skills/${skill}/SKILL.md" ]]; then
    printf "%s" "${RUNTIME_ROOT}/skills/${skill}/SKILL.md"
    return 0
  fi
  if [[ -f "${RUNTIME_ROOT}/skills/.system/${skill}/SKILL.md" ]]; then
    printf "%s" "${RUNTIME_ROOT}/skills/.system/${skill}/SKILL.md"
    return 0
  fi
  if [[ -d "${RUNTIME_ROOT}/vendor/skills/${skill}" ]]; then
    found="$(find "${RUNTIME_ROOT}/vendor/skills/${skill}" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
      printf "%s" "${found}"
      return 0
    fi
  fi
  if [[ -d "${RUNTIME_ROOT}/vendor/plugins" ]]; then
    found="$(find "${RUNTIME_ROOT}/vendor/plugins" -path "*/skills/${skill}/SKILL.md" -type f -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
      printf "%s" "${found}"
      return 0
    fi
  fi

  return 1
}

required=0
live=0
missing_required=0
first_missing="-"
forbidden_skills=0
forbidden_paths=0
first_forbidden="-"
required_values="$(manifest_values required_skills)" || exit 1
forbidden_skill_values="$(manifest_values forbidden_skills)" || exit 1
forbidden_path_values="$(manifest_values forbidden_paths)" || exit 1

while IFS= read -r required_skill; do
  [[ -n "${required_skill}" ]] || continue
  required=$((required + 1))
  path="$(skill_live_path "${required_skill}" || true)"
  if [[ -n "${path}" ]]; then
    live=$((live + 1))
    continue
  fi
  missing_required=$((missing_required + 1))
  [[ "${first_missing}" == "-" ]] && first_missing="${required_skill}"
done <<< "${required_values}"

while IFS= read -r forbidden_skill; do
  [[ -n "${forbidden_skill}" ]] || continue
  path="$(skill_live_path "${forbidden_skill}" || true)"
  if [[ -n "${path}" ]]; then
    forbidden_skills=$((forbidden_skills + 1))
    [[ "${first_forbidden}" == "-" ]] && first_forbidden="${forbidden_skill}"
  fi
done <<< "${forbidden_skill_values}"

while IFS= read -r forbidden_path; do
  [[ -n "${forbidden_path}" ]] || continue
  if [[ -e "${RUNTIME_ROOT}/${forbidden_path}" || -L "${RUNTIME_ROOT}/${forbidden_path}" ]]; then
    forbidden_paths=$((forbidden_paths + 1))
    [[ "${first_forbidden}" == "-" ]] && first_forbidden="${forbidden_path}"
  fi
done <<< "${forbidden_path_values}"

[[ "${required}" -gt 0 ]] || {
  echo "[FAIL] runtime footprint required_skills is empty" >&2
  exit 1
}

status="pass"
if [[ "${missing_required}" -gt 0 || "${forbidden_skills}" -gt 0 || "${forbidden_paths}" -gt 0 ]]; then
  status="needs-fix"
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  printf '{"status":"%s","runtime_root":%s,"required":%s,"live":%s,"missing_required":%s,"forbidden_skills":%s,"forbidden_paths":%s,"first_missing":%s,"first_forbidden":%s}\n' \
    "${status}" \
    "$(json_string "${RUNTIME_ROOT}")" \
    "${required}" \
    "${live}" \
    "${missing_required}" \
    "${forbidden_skills}" \
    "${forbidden_paths}" \
    "$(json_string "${first_missing}")" \
    "$(json_string "${first_forbidden}")"
else
  echo "[INFO] runtime_root=${RUNTIME_ROOT}"
  echo "[INFO] required=${required} live_matched=${live} missing_required=${missing_required} forbidden_skills=${forbidden_skills} forbidden_paths=${forbidden_paths}"
  if [[ "${missing_required}" -gt 0 ]]; then
    echo "[WARN] first_missing_required=${first_missing}"
  fi
  if [[ "${forbidden_skills}" -gt 0 || "${forbidden_paths}" -gt 0 ]]; then
    echo "[WARN] first_forbidden=${first_forbidden}"
  fi
  echo "[${status}] runtime live footprint checked"
fi

if [[ "${STRICT}" -eq 1 && ( "${missing_required}" -gt 0 || "${forbidden_skills}" -gt 0 || "${forbidden_paths}" -gt 0 ) ]]; then
  exit 1
fi
