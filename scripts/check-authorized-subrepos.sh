#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"
GITMODULES="${ROOT}/.gitmodules"
LIFECYCLE="${ROOT}/manifests/subrepo_lifecycle.json"

[[ -f "${REGISTRY}" ]] || {
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
}

mapfile -t authorized < <(
  awk -F',' 'NR > 1 && $6 == "yes" && $8 == "active" {print $1}' "${REGISTRY}" | sort
)

mapfile -t registered < <(
  if [[ -f "${GITMODULES}" ]]; then
    git config -f "${GITMODULES}" --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | sort
  fi
)

mapfile -t root_local < <(
  if [[ -f "${LIFECYCLE}" ]]; then
    python3 - "${LIFECYCLE}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

for entry in data.get("entries", []):
    if entry.get("materialization") == "root-local-reference":
        repo = entry.get("repo")
        if repo:
            print(repo)
PY
  fi | sort
)

failed=0

for repo in "${authorized[@]}"; do
  if ! printf '%s\n' "${registered[@]}" | grep -Fxq "${repo}"; then
    if printf '%s\n' "${root_local[@]}" | grep -Fxq "${repo}"; then
      if [[ ! -d "${ROOT}/${repo}" ]] || ! git -C "${ROOT}/${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[FAIL] root-local reference is not a git worktree: ${repo}" >&2
        failed=1
      fi
    else
      echo "[FAIL] active registry repo missing from .gitmodules: ${repo}" >&2
      failed=1
    fi
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
