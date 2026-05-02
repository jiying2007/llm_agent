#!/usr/bin/env bash
set -u

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT_AGENTS="${ROOT}/AGENTS.md"

if [[ ! -f "${ROOT_AGENTS}" ]]; then
  echo "[ERROR] root AGENTS.md not found: ${ROOT_AGENTS}" >&2
  exit 1
fi

missing_local=0
missing_root=0

printf '%-28s %-8s %-8s\n' "repo" "local" "root"
printf '%-28s %-8s %-8s\n' "----------------------------" "--------" "--------"

while IFS= read -r repo; do
  [[ "${repo}" == "." || -z "${repo}" ]] && continue

  local_state="YES"
  if [[ ! -e "${ROOT}/${repo}/AGENTS.md" ]]; then
    local_state="NO"
    ((missing_local+=1))
  fi

  root_state="YES"
  if ! rg -q --fixed-strings "${repo}" "${ROOT_AGENTS}"; then
    root_state="NO"
    ((missing_root+=1))
  fi

  printf '%-28s %-8s %-8s\n' "${repo}" "${local_state}" "${root_state}"
done < <(find "${ROOT}" -mindepth 2 -maxdepth 2 -type d -name .git -printf '%h\n' | sed "s#^${ROOT}/##" | sort)

echo
echo "[SUMMARY] local_missing=${missing_local} root_missing=${missing_root}"

if ((missing_local > 0 || missing_root > 0)); then
  exit 2
fi

echo "[OK] AGENTS coverage complete"

