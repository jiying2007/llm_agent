#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

case "${2:-}" in
  "" )
    ;;
  -h|--help)
    cat <<USAGE
usage: scripts/check-evidence-bundle.sh [root]

Fails if the aggregated llm_agent / agent-dev-kit evidence bundle reports a
non-pass status.
USAGE
    exit 0
    ;;
  *)
    echo "[FAIL] unknown arg: $2" >&2
    exit 1
    ;;
esac

tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

"${ROOT}/scripts/evidence-bundle.sh" "${ROOT}" --format json --fail-on-needs-fix >"${tmpfile}"
echo "[PASS] evidence bundle gate ready"
