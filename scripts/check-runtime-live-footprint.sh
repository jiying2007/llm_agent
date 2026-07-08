#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RUNTIME_ROOT="${HOME}/.codex"
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

Checks whether adk equivalents from the fallback sunset matrix are present in
the configured live runtime. Direct skills, system skills and versioned vendor skills
are all treated as live.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

ADK_DIR="${ROOT}/agent-dev-kit"
MATRIX="${ADK_DIR}/docs/reference/fallback-sunset-matrix.tsv"
[[ -f "${MATRIX}" ]] || {
  echo "[FAIL] fallback matrix missing: ${MATRIX}" >&2
  exit 1
}

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
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

extract_matched_skill() {
  awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^skill=/) {
          value=$i
          sub(/^skill=/, "", value)
          print value
          exit
        }
      }
    }
  ' <<< "$1"
}

rows=0
required=0
live=0
missing_required=0
missing_optional=0
first_missing="-"

while IFS=$'\t' read -r fallback_skill adk_equivalent status owner review_by live_requirement next_step match_text pilot_refs; do
  [[ -n "${fallback_skill}" ]] || continue
  rows=$((rows + 1))

  match_output="$(bash "${ADK_DIR}/scripts/devkit.sh" match --text "${match_text}" 2>/dev/null || true)"
  matched_skill="$(extract_matched_skill "${match_output}")"
  [[ -n "${matched_skill}" ]] || matched_skill="${adk_equivalent%%+*}"

  path="$(skill_live_path "${matched_skill}" || true)"
  if [[ -n "${path}" ]]; then
    live=$((live + 1))
    continue
  fi

  case "${live_requirement}" in
    core-live-required)
      required=$((required + 1))
      missing_required=$((missing_required + 1))
      [[ "${first_missing}" == "-" ]] && first_missing="${matched_skill}"
      ;;
    optional-live-allowed|handoff-ready-only)
      missing_optional=$((missing_optional + 1))
      ;;
  esac
done < <(tail -n +2 "${MATRIX}")

status="pass"
if [[ "${missing_required}" -gt 0 ]]; then
  status="needs-fix"
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  printf '{"status":"%s","runtime_root":%s,"rows":%s,"live":%s,"missing_required":%s,"missing_optional":%s,"first_missing":%s}\n' \
    "${status}" \
    "$(json_string "${RUNTIME_ROOT}")" \
    "${rows}" \
    "${live}" \
    "${missing_required}" \
    "${missing_optional}" \
    "$(json_string "${first_missing}")"
else
  echo "[INFO] runtime_root=${RUNTIME_ROOT}"
  echo "[INFO] fallback_rows=${rows} live_matched=${live} missing_required=${missing_required} missing_optional=${missing_optional}"
  if [[ "${missing_required}" -gt 0 ]]; then
    echo "[WARN] first_missing_required=${first_missing}"
  fi
  echo "[${status}] runtime live footprint checked"
fi

if [[ "${STRICT}" -eq 1 && "${missing_required}" -gt 0 ]]; then
  exit 1
fi
