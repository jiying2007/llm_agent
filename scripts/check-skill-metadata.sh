#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_DIR="${ROOT}/agent-dev-kit"
MANIFEST="${ADK_DIR}/manifest.yaml"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "[FAIL] manifest missing: ${MANIFEST}" >&2
  exit 1
fi

collect_manifest_items() {
  local section="$1"
  awk -v section="${section}" '
    $0 ~ "^" section ":" {in_section=1; next}
    in_section && $0 ~ "^[^ ]" {in_section=0}
    in_section && $0 ~ /^  - name:/ {name=$3; quality_tier=""; next}
    in_section && $0 ~ /^    path:/ {path=$2; next}
    in_section && $0 ~ /^    quality_tier:/ {
      quality_tier=$2
      print name "|" path "|" quality_tier
    }
  ' "${MANIFEST}"
}

frontmatter_value() {
  local file="$1"
  local key="$2"
  awk -v key="${key}" '
    NR==1 && $0=="---" {in_fm=1; next}
    in_fm && $0=="---" {exit}
    in_fm && $0 ~ "^" key ":" {
      value=$0
      sub("^" key ":[ ]*", "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "${file}"
}

fail_count=0

mapfile -t core_items < <(collect_manifest_items "skills")
mapfile -t optional_items < <(collect_manifest_items "optional_skills")

if [[ ${#core_items[@]} -eq 0 ]]; then
  echo "[FAIL] manifest skills section is empty" >&2
  exit 1
fi

if [[ ${#optional_items[@]} -eq 0 ]]; then
  echo "[FAIL] manifest optional_skills section is empty" >&2
  exit 1
fi

declare -A seen_names=()

check_item() {
  local section="$1"
  local item="$2"
  local name path quality_tier file declared_name version last_updated

  IFS='|' read -r name path quality_tier <<< "${item}"
  file="${ADK_DIR}/${path}"

  if [[ -n "${seen_names[${name}]:-}" ]]; then
    echo "[FAIL] duplicate skill name across manifest sections: ${name}" >&2
    ((fail_count+=1))
  fi
  seen_names["${name}"]="${section}"

  if [[ -z "${quality_tier}" ]]; then
    echo "[FAIL] ${section} '${name}' missing quality_tier in manifest" >&2
    ((fail_count+=1))
  fi

  if [[ ! -f "${file}" ]]; then
    echo "[FAIL] ${section} '${name}' file missing: ${file}" >&2
    ((fail_count+=1))
    return
  fi

  declared_name="$(frontmatter_value "${file}" "name")"
  version="$(frontmatter_value "${file}" "version")"
  last_updated="$(frontmatter_value "${file}" "last_updated")"

  if [[ "${declared_name}" != "${name}" ]]; then
    echo "[FAIL] ${section} '${name}' frontmatter name mismatch: ${declared_name}" >&2
    ((fail_count+=1))
  fi

  if [[ -z "${version}" ]]; then
    echo "[FAIL] ${section} '${name}' missing frontmatter field: version" >&2
    ((fail_count+=1))
  elif [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[FAIL] ${section} '${name}' version is not semver: ${version}" >&2
    ((fail_count+=1))
  fi

  if [[ -z "${last_updated}" ]]; then
    echo "[FAIL] ${section} '${name}' missing frontmatter field: last_updated" >&2
    ((fail_count+=1))
  elif [[ ! "${last_updated}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "[FAIL] ${section} '${name}' last_updated format invalid: ${last_updated}" >&2
    ((fail_count+=1))
  elif ! date -d "${last_updated}" +%F >/dev/null 2>&1; then
    echo "[FAIL] ${section} '${name}' last_updated is not a valid date: ${last_updated}" >&2
    ((fail_count+=1))
  fi
}

for item in "${core_items[@]}"; do
  check_item "skills" "${item}"
done

for item in "${optional_items[@]}"; do
  check_item "optional_skills" "${item}"
done

if ((fail_count > 0)); then
  echo "[FAIL] skill metadata checks failed: ${fail_count}" >&2
  exit 2
fi

echo "[PASS] skill metadata checks passed"
