#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_DIR="${ROOT}/agent-dev-kit"
MANIFEST="${ADK_DIR}/manifest.json"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "[FAIL] manifest missing: ${MANIFEST}" >&2
  exit 1
fi

if ! jq -e '
  (.profiles.core != null)
  and (.profiles["embedded-fullstack"] != null)
  and ([.skills[].name] | index("adk-runtime-router") != null)
  and ([.skills[].name] | index("adk-planning-execution-loop") != null)
  and ((.skill_routing_matrix | length) > 0)
' "$MANIFEST" >/dev/null; then
  echo "[FAIL] active ADK routing contract is incomplete" >&2
  exit 1
fi

for runbook in runtime-routing.md planning-execution-loop.md upstream-intake.md security-supply-chain.md team-delivery.md; do
  if [[ ! -f "$ADK_DIR/docs/runbooks/$runbook" ]]; then
    echo "[FAIL] active ADK runbook missing: $runbook" >&2
    exit 1
  fi
done

bash "${ROOT}/scripts/check-skill-routing-conflicts.sh" "${ROOT}"
bash "${ADK_DIR}/scripts/devkit.sh" validate --strict

echo "[PASS] runtime routing production assets ready"
