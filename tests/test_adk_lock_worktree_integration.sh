#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-adk-lock.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

locked_commit="$(awk -F= '$1=="agent-dev-kit.commit"{print $2}' "${ROOT}/adk.lock")"
index_commit="$(git -C "${ROOT}" ls-files -s agent-dev-kit | awk '$1=="160000"{print $2; exit}')"
worktree_commit="$(git -C "${ROOT}/agent-dev-kit" rev-parse HEAD)"

[[ "${locked_commit}" == "${worktree_commit}" ]] || {
  echo "[FAIL] fixture requires adk.lock to follow the ADK worktree" >&2
  exit 1
}

bash "${CHECKER}" "${ROOT}" --worktree-integration >"${TMP_DIR}/working.out"
rg -q --fixed-strings "recorded gitlink is an ancestor" "${TMP_DIR}/working.out"

if [[ "${index_commit}" == "${locked_commit}" ]]; then
  bash "${CHECKER}" "${ROOT}" >"${TMP_DIR}/release.out"
else
  if bash "${CHECKER}" "${ROOT}" >"${TMP_DIR}/release.out" 2>&1; then
    echo "[FAIL] release mode accepted an unstaged gitlink" >&2
    exit 1
  fi
  rg -q --fixed-strings "gitlink ${index_commit} != adk.lock ${locked_commit}" "${TMP_DIR}/release.out"
fi

echo "[PASS] ADK lock distinguishes working-tree integration from release-clean identity"
