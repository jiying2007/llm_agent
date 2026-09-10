#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCK="${ROOT}/adk.lock"
MANIFEST_JSON="${ROOT}/agent-dev-kit/manifest.json"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

PIN_ONLY=0
WORKTREE_INTEGRATION=0
if [[ $# -gt 0 && "$1" != --* ]]; then
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pin-only) PIN_ONLY=1 ;;
    --worktree-integration) WORKTREE_INTEGRATION=1 ;;
    *) fail "unknown arg: $1" ;;
  esac
  shift
done

lock_value() {
  local key="$1"
  awk -F'=' -v key="$key" '$1 == key {print $2; exit}' "${LOCK}"
}

[[ -f "${LOCK}" ]] || fail "missing adk.lock"

schema="$(lock_value "schema")"
locked_version="$(lock_value "agent-dev-kit.version")"
locked_commit="$(lock_value "agent-dev-kit.commit")"
locked_tree="$(lock_value "agent-dev-kit.tree")"
locked_manifest_blob="$(lock_value "agent-dev-kit.manifest_blob")"

[[ "${schema}" == "llm-agent-adk-lock/v2" ]] || fail "unsupported adk.lock schema: ${schema:-missing}"
[[ -n "${locked_version}" ]] || fail "adk.lock missing agent-dev-kit.version"
[[ "${locked_commit}" =~ ^[0-9a-f]{40}$ ]] || fail "adk.lock agent-dev-kit.commit must be a full SHA"
[[ "${locked_tree}" =~ ^[0-9a-f]{40}$ ]] || fail "adk.lock agent-dev-kit.tree must be a full SHA"
[[ "${locked_manifest_blob}" =~ ^[0-9a-f]{40}$ ]] || fail "adk.lock agent-dev-kit.manifest_blob must be a full Git blob SHA"

index_commit="$(git -C "${ROOT}" ls-files -s agent-dev-kit | awk '$1=="160000"{print $2; exit}')"
[[ -n "${index_commit}" ]] || fail "agent-dev-kit is not tracked as a gitlink"
if [[ "${WORKTREE_INTEGRATION}" -eq 0 ]]; then
  [[ "${index_commit}" == "${locked_commit}" ]] || {
    fail "agent-dev-kit gitlink ${index_commit} != adk.lock ${locked_commit}"
  }
fi

if [[ "${PIN_ONLY}" -eq 1 ]]; then
  echo "[PASS] ADK immutable pin matches gitlink (schema=${schema}, commit=${locked_commit})"
  exit 0
fi

[[ -f "${MANIFEST_JSON}" ]] || fail "agent-dev-kit manifest.json unavailable; initialize the locked ADK checkout or use --pin-only"

manifest_version="$(python3 - "${MANIFEST_JSON}" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)["version"])
PY
)"
[[ "${manifest_version}" == "${locked_version}" ]] || {
  fail "manifest.json version ${manifest_version} != adk.lock ${locked_version}"
}

manifest_blob="$(git -C "${ROOT}/agent-dev-kit" hash-object manifest.json)"
[[ "${manifest_blob}" == "${locked_manifest_blob}" ]] || {
  fail "manifest.json blob ${manifest_blob} != adk.lock ${locked_manifest_blob}"
}

if [[ -d "${ROOT}/agent-dev-kit/.git" || -f "${ROOT}/agent-dev-kit/.git" ]]; then
  worktree_commit="$(git -C "${ROOT}/agent-dev-kit" rev-parse HEAD)"
  worktree_tree="$(git -C "${ROOT}/agent-dev-kit" rev-parse 'HEAD^{tree}')"
  [[ "${worktree_commit}" == "${locked_commit}" ]] || {
    fail "agent-dev-kit worktree ${worktree_commit} != adk.lock ${locked_commit}"
  }
  [[ "${worktree_tree}" == "${locked_tree}" ]] || {
    fail "agent-dev-kit tree ${worktree_tree} != adk.lock ${locked_tree}"
  }
  if [[ "${WORKTREE_INTEGRATION}" -eq 1 ]]; then
    git -C "${ROOT}/agent-dev-kit" merge-base --is-ancestor "${index_commit}" "${worktree_commit}" || {
      fail "agent-dev-kit worktree must descend from recorded gitlink ${index_commit}"
    }
  fi
fi

if [[ "${WORKTREE_INTEGRATION}" -eq 1 ]]; then
  echo "[PASS] ADK lock matches manifest.json/worktree; recorded gitlink is an ancestor"
else
  echo "[PASS] ADK lock matches gitlink, tree and manifest.json"
fi
