#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GDK_DIR="${ROOT}/global-dev-kit"
MANIFEST="${GDK_DIR}/manifest.yaml"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "[FAIL] manifest missing: ${MANIFEST}" >&2
  exit 1
fi

require_token() {
  local token="$1"
  local file="$2"
  if ! rg -q --fixed-strings -- "${token}" "${file}"; then
    echo "[FAIL] missing token in ${file}: ${token}" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  if [[ ! -e "${ROOT}/${path}" ]]; then
    echo "[FAIL] missing runtime routing asset: ${path}" >&2
    exit 1
  fi
}

for profile in personal-core team-core openspec-driven large-refactor incident-response research-intake; do
  require_token "  ${profile}:" "${MANIFEST}"
done

for skill in planning-execution-loop skill-composition-governance security-supply-chain; do
  require_token "  - name: ${skill}" "${MANIFEST}"
  require_path "global-dev-kit/optional-skills/${skill}/SKILL.md"
done

for runbook in runtime-routing.md planning-execution-loop.md production-deployment.md upstream-intake.md compatibility-matrix.md security-supply-chain.md team-delivery.md; do
  require_path "global-dev-kit/docs/runbooks/${runbook}"
done

bash "${ROOT}/scripts/check-skill-routing-conflicts.sh" "${ROOT}"
bash "${GDK_DIR}/scripts/check_profile_coherence.sh"

echo "[PASS] runtime routing production assets ready"
