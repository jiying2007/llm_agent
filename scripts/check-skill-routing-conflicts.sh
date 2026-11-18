#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_DIR="${ROOT}/agent-dev-kit"
MANIFEST="${ADK_DIR}/manifest.json"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "[FAIL] manifest missing: ${MANIFEST}" >&2
  exit 1
fi

collect_manifest_items() {
  local section="$1"
  jq -sr --arg section "$section" '
    if length != 1 or (.[0] | type) != "object" then
      error("manifest must contain exactly one JSON object")
    else
      .[0][$section] |
      if type != "array" or length == 0 then
        error("skill section missing or empty: " + $section)
      else
        .[] | [.name, .path] | join("|")
      end
    end
  ' "$MANIFEST"
}

collect_triggers() {
  local file="$1"
  awk '
    NR==1 && $0=="---" {in_fm=1; next}
    in_fm && $0=="---" {exit}
    in_fm && $0 ~ /^triggers:/ {in_list=1; next}
    in_list && $0 ~ /^  - / {
      line=$0
      sub(/^  - /, "", line)
      print line
      next
    }
    in_list && $0 ~ /^[a-z_]+:/ {in_list=0}
  ' "${file}"
}

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

append_items() {
  local section="$1" inventory="$2"
  local item name path file trigger normalized

  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    IFS='|' read -r name path <<< "${item}"
    file="${ADK_DIR}/${path}"
    if [[ ! -f "${file}" || -L "${file}" ]]; then
      echo "[FAIL] missing or unsafe skill file: ${file}" >&2
      return 2
    fi

    while IFS= read -r trigger; do
      normalized="$(printf "%s" "${trigger}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
      [[ -z "${normalized}" ]] && continue
      printf "%s\t%s\t%s\n" "${normalized}" "${name}" "${section}" >> "${tmp_file}"
    done < <(collect_triggers "${file}")
  done <<< "${inventory}"
}

core_raw="$(collect_manifest_items "skills")" || {
  echo "[FAIL] invalid core skill manifest inventory" >&2
  exit 2
}
optional_raw="$(collect_manifest_items "optional_skills")" || {
  echo "[FAIL] invalid optional skill manifest inventory" >&2
  exit 2
}
[[ -n "$core_raw" && -n "$optional_raw" ]] || {
  echo "[FAIL] empty skill manifest inventory" >&2
  exit 2
}
append_items "skills" "$core_raw"
append_items "optional_skills" "$optional_raw"

if [[ ! -s "${tmp_file}" ]]; then
  echo "[FAIL] no triggers found in manifest skills" >&2
  exit 1
fi

conflicts="$(awk -F'\t' '
  {
    key=$1
    skill=$2
    pair=key SUBSEP skill
    if (!(pair in seen)) {
      seen[pair]=1
      count[key]++
      if (skills[key] == "") {
        skills[key]=skill
      } else {
        skills[key]=skills[key] ", " skill
      }
    }
  }
  END {
    for (k in count) {
      if (count[k] > 1) {
        printf "[CONFLICT] trigger=\"%s\" skills=%s\n", k, skills[k]
      }
    }
  }
' "${tmp_file}")"

if [[ -n "${conflicts}" ]]; then
  echo "${conflicts}" >&2
  echo "[FAIL] skill routing conflicts found" >&2
  exit 2
fi

echo "[PASS] no skill routing conflicts"
