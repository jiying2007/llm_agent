#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GDK_DIR="${ROOT}/global-dev-kit"
MANIFEST="${GDK_DIR}/manifest.yaml"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "[FAIL] manifest missing: ${MANIFEST}" >&2
  exit 1
fi

collect_manifest_items() {
  local section="$1"
  awk -v section="${section}" '
    $0 ~ "^" section ":" {in_section=1; next}
    in_section && $0 ~ "^[^ ]" {in_section=0}
    in_section && $0 ~ /^  - name:/ {name=$3; next}
    in_section && $0 ~ /^    path:/ {path=$2; print name "|" path}
  ' "${MANIFEST}"
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
  local section="$1"
  local item name path file trigger normalized

  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    IFS='|' read -r name path <<< "${item}"
    file="${GDK_DIR}/${path}"
    [[ -f "${file}" ]] || continue

    while IFS= read -r trigger; do
      normalized="$(printf "%s" "${trigger}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
      [[ -z "${normalized}" ]] && continue
      printf "%s\t%s\t%s\n" "${normalized}" "${name}" "${section}" >> "${tmp_file}"
    done < <(collect_triggers "${file}")
  done < <(collect_manifest_items "${section}")
}

append_items "skills"
append_items "optional_skills"

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
