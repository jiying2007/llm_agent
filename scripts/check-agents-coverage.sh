#!/usr/bin/env bash
set -e
set -u

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT_AGENTS="${ROOT}/AGENTS.md"
REGISTRY="${ROOT}/subrepos/registry.csv"
OVERLAY_DIR="${ROOT}/subrepos/agents"
MAX_ROOT_AGENTS_LINES=180

if [[ ! -f "${ROOT_AGENTS}" ]]; then
  echo "[ERROR] root AGENTS.md not found: ${ROOT_AGENTS}" >&2
  exit 1
fi

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[ERROR] registry not found: ${REGISTRY}" >&2
  exit 1
fi

root_lines="$(wc -l <"${ROOT_AGENTS}" | tr -d ' ')"
if [[ "${root_lines}" -gt "${MAX_ROOT_AGENTS_LINES}" ]]; then
  echo "[ERROR] root AGENTS.md too large: lines=${root_lines} limit=${MAX_ROOT_AGENTS_LINES}" >&2
  exit 2
fi

for token in "subrepos/registry.csv" "subrepos/adoption-matrix.md" "docs/llm-agent-maintenance-guide.md"; do
  if ! rg -q --fixed-strings -- "${token}" "${ROOT_AGENTS}"; then
    echo "[ERROR] root AGENTS.md missing slim coverage token: ${token}" >&2
    exit 2
  fi
done

missing_path=0
covered_by_root=0
covered_by_local=0
covered_by_overlay=0
active_count=0

printf '%-28s %-10s %-10s\n' "repo" "path" "coverage"
printf '%-28s %-10s %-10s\n' "----------------------------" "----------" "----------"

while IFS=, read -r repo _group _priority _sync_mode _branch enabled _notes status _owner _last_reviewed_on _intake_policy _grade; do
  [[ "${repo}" == "repo" || -z "${repo}" ]] && continue
  [[ "${enabled}" == "yes" && "${status}" == "active" ]] || continue

  active_count=$((active_count + 1))

  path_state="YES"
  if [[ ! -e "${ROOT}/${repo}" ]]; then
    path_state="NO"
    missing_path=$((missing_path + 1))
  fi

  coverage_state="ROOT-SSOT"
  if [[ -e "${ROOT}/${repo}/AGENTS.md" ]]; then
    coverage_state="LOCAL"
    covered_by_local=$((covered_by_local + 1))
  elif [[ -e "${OVERLAY_DIR}/${repo}.md" ]]; then
    coverage_state="OVERLAY"
    covered_by_overlay=$((covered_by_overlay + 1))
  else
    covered_by_root=$((covered_by_root + 1))
  fi

  printf '%-28s %-10s %-10s\n' "${repo}" "${path_state}" "${coverage_state}"
done <"${REGISTRY}"

echo
echo "[SUMMARY] active=${active_count} root_ssot=${covered_by_root} local=${covered_by_local} overlay=${covered_by_overlay} missing_path=${missing_path} root_agents_lines=${root_lines}"

if ((missing_path > 0)); then
  exit 2
fi

echo "[OK] AGENTS coverage complete"
