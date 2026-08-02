#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WORKTREE_INTEGRATION=0

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
  --worktree-integration)
    WORKTREE_INTEGRATION=1
    shift
    ;;
  -h|--help)
    cat <<USAGE
usage: scripts/check-evidence-bundle.sh [root] [--worktree-integration]

Fails if the aggregated llm_agent / agent-dev-kit evidence bundle reports a
non-pass status.
USAGE
    exit 0
    ;;
  *)
    echo "[FAIL] unknown arg: $1" >&2
    exit 1
    ;;
  esac
done

tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

bundle_args=("${ROOT}" --format json --fail-on-needs-fix)
[[ "${WORKTREE_INTEGRATION}" -eq 0 ]] || bundle_args+=(--worktree-integration)
"${ROOT}/scripts/evidence-bundle.sh" "${bundle_args[@]}" >"${tmpfile}"
echo "[PASS] evidence bundle gate ready"
