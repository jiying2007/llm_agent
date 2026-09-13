#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCK="${ROOT}/codex.lock"
fail() { echo "[FAIL] $*" >&2; exit 1; }
PIN_ONLY=0
if [[ $# -gt 0 && "$1" != --* ]]; then shift; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pin-only) PIN_ONLY=1 ;;
    *) fail "unknown arg: $1" ;;
  esac
  shift
done
lock_value() { local key="$1"; awk -F'=' -v key="$key" '$1 == key {print $2; exit}' "$LOCK"; }
[[ -f "$LOCK" ]] || fail "missing codex.lock"
[[ "$(lock_value schema)" == "llm-agent-codex-lock/v1" ]] || fail "unsupported codex.lock schema"
locked_commit="$(lock_value codex.commit)"
locked_tree="$(lock_value codex.tree)"
[[ "$locked_commit" =~ ^[0-9a-f]{40}$ ]] || fail "codex.commit must be a full SHA"
[[ "$locked_tree" =~ ^[0-9a-f]{40}$ ]] || fail "codex.tree must be a full SHA"
for key in codex.provider_lock_blob codex.runtime_control_blob codex.runtime_binding_blob codex.agents_blob codex.validator_blob codex.workflow_blob agent-dev-kit.commit agent-dev-kit.tree agent-dev-kit.manifest_blob; do
  value="$(lock_value "$key")"
  [[ "$value" =~ ^[0-9a-f]{40}$ ]] || fail "$key must be a full Git SHA"
done
[[ "$(lock_value agent-dev-kit.release_artifact_sha256)" =~ ^[0-9a-f]{64}$ ]] || fail "release artifact digest must be sha256 hex"
index_commit="$(git -C "$ROOT" ls-files -s codex | awk '$1=="160000"{print $2; exit}')"
[[ -n "$index_commit" ]] || fail "codex is not tracked as a gitlink"
[[ "$index_commit" == "$locked_commit" ]] || fail "codex gitlink $index_commit != codex.lock $locked_commit"
if [[ "$PIN_ONLY" -eq 1 ]]; then
  echo "[PASS] Codex immutable pin matches gitlink (commit=$locked_commit)"
  exit 0
fi
[[ -d "$ROOT/codex" ]] || fail "codex worktree unavailable; initialize the locked submodule or use --pin-only"
[[ "$(git -C "$ROOT/codex" rev-parse HEAD)" == "$locked_commit" ]] || fail "codex worktree commit mismatch"
[[ "$(git -C "$ROOT/codex" rev-parse 'HEAD^{tree}')" == "$locked_tree" ]] || fail "codex worktree tree mismatch"
check_blob() {
  local key="$1" path="$2" expected actual
  expected="$(lock_value "$key")"
  actual="$(git -C "$ROOT/codex" rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "$path blob $actual != codex.lock $expected"
}
check_blob codex.provider_lock_blob manifests/provider-locks/agent-dev-kit.json
check_blob codex.runtime_control_blob manifests/runtime_control.json
check_blob codex.runtime_binding_blob manifests/integrations/digital-worker-runtime-binding.json
check_blob codex.agents_blob manifests/agents.json
check_blob codex.validator_blob scripts/validate-runtime-binding.py
check_blob codex.workflow_blob .github/workflows/runtime-binding-contract.yml
echo "[PASS] Codex lock matches gitlink, tree and terminal control-plane blobs"
