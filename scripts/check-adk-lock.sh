#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCK="${ROOT}/adk.lock"
MANIFEST="${ROOT}/agent-dev-kit/manifest.yaml"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

lock_value() {
  local key="$1"
  awk -F'=' -v key="$key" '$1 == key {print $2; exit}' "${LOCK}"
}

[[ -f "${LOCK}" ]] || fail "missing adk.lock"
[[ -f "${MANIFEST}" ]] || fail "missing agent-dev-kit manifest"

locked_version="$(lock_value "agent-dev-kit.version")"
locked_commit="$(lock_value "agent-dev-kit.commit")"
codex_source="$(lock_value "codex.source")"
codex_target="$(lock_value "codex.target")"

[[ -n "${locked_version}" ]] || fail "adk.lock missing agent-dev-kit.version"
[[ -n "${locked_commit}" ]] || fail "adk.lock missing agent-dev-kit.commit"
[[ "${codex_source}" == "~/codex" ]] || fail "adk.lock codex.source must be ~/codex"
[[ "${codex_target}" == "~/.codex" ]] || fail "adk.lock codex.target must be ~/.codex"

manifest_version="$(awk -F': ' '$1=="version"{print $2; exit}' "${MANIFEST}")"
[[ "${manifest_version}" == "${locked_version}" ]] || {
  fail "manifest version ${manifest_version} != adk.lock ${locked_version}"
}

index_commit="$(git -C "${ROOT}" ls-files -s agent-dev-kit | awk '$1=="160000"{print $2; exit}')"
[[ -n "${index_commit}" ]] || fail "agent-dev-kit is not tracked as a gitlink"
[[ "${index_commit}" == "${locked_commit}" ]] || {
  fail "agent-dev-kit gitlink ${index_commit} != adk.lock ${locked_commit}"
}

if [[ -d "${ROOT}/agent-dev-kit/.git" || -f "${ROOT}/agent-dev-kit/.git" ]]; then
  worktree_commit="$(git -C "${ROOT}/agent-dev-kit" rev-parse HEAD)"
  [[ "${worktree_commit}" == "${locked_commit}" ]] || {
    fail "agent-dev-kit worktree ${worktree_commit} != adk.lock ${locked_commit}"
  }
fi

echo "[PASS] adk lock matches manifest and gitlink"
