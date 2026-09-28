#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"
GITMODULES="${ROOT}/.gitmodules"
GITLINKS="${ROOT}/manifests/gitlinks.json"

[[ -f "${REGISTRY}" ]] || {
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
}
[[ -f "${GITLINKS}" ]] || {
  echo "[FAIL] gitlink manifest missing: ${GITLINKS}" >&2
  exit 1
}
jq -e '.schema == "llm-agent-gitlinks/v2" and (.gitlinks | type == "array")' "${GITLINKS}" >/dev/null || {
  echo "[FAIL] gitlink manifest is invalid" >&2
  exit 1
}

mapfile -t authorized < <(
  awk -F',' 'NR > 1 && $4 == "pull" && $6 == "yes" && $8 == "active" {print $1}' "${REGISTRY}"
  jq -r '.gitlinks[] | select(.kind == "frozen-evidence-dependency" and .required == true) | .path' "${GITLINKS}"
)
mapfile -t authorized < <(printf '%s\n' "${authorized[@]}" | sort -u)

mapfile -t registered < <(
  if [[ -f "${GITMODULES}" ]]; then
    git config -f "${GITMODULES}" --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | sort
  fi
)

failed=0

for repo in "${authorized[@]}"; do
  if ! printf '%s\n' "${registered[@]}" | grep -Fxq "${repo}"; then
    echo "[FAIL] authorized gitlink missing from .gitmodules: ${repo}" >&2
    failed=1
  fi
  if ! git -C "${ROOT}" ls-files -s -- "${repo}" | awk '$1=="160000"{found=1} END{exit !found}'; then
    echo "[FAIL] authorized submodule missing gitlink in index: ${repo}" >&2
    failed=1
  fi
done

for repo in "${registered[@]}"; do
  if ! printf '%s\n' "${authorized[@]}" | grep -Fxq "${repo}"; then
    echo "[FAIL] unauthorized submodule in .gitmodules: ${repo}" >&2
    failed=1
  fi
done

while IFS= read -r entry; do
  mode="${entry%% *}"
  path="${entry##*$'\t'}"
  [[ "${mode}" == "160000" ]] || continue
  if ! printf '%s\n' "${authorized[@]}" | grep -Fxq "${path}"; then
    echo "[FAIL] unauthorized gitlink in index: ${path}" >&2
    failed=1
  fi
done < <(git -C "${ROOT}" ls-files -s)

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "[PASS] authorized subrepos match registry allowlist"
