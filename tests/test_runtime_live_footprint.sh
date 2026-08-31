#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-runtime-live-footprint.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FIXTURE_ROOT="${TMP_DIR}/root"
RUNTIME_ROOT="${TMP_DIR}/runtime"
mkdir -p "${FIXTURE_ROOT}/manifests" "${RUNTIME_ROOT}/vendor/skills/adk-runtime-router/2.0.0"

printf '%s\n' 'fixture' >"${RUNTIME_ROOT}/vendor/skills/adk-runtime-router/2.0.0/SKILL.md"
printf '%s\n' '{
  "schema_version": 1,
  "status": "active",
  "default_target": "codex-home",
  "targets": [{
    "id": "codex-home",
    "live_root": "~/.codex",
    "runtime_footprint": {
      "required_skills": ["adk-runtime-router"],
      "forbidden_skills": ["using-superpowers"],
      "forbidden_paths": ["vendor/plugins/superpowers"]
    }
  }]
}' >"${FIXTURE_ROOT}/manifests/runtime_targets.json"

pass_output="$(${CHECK} "${FIXTURE_ROOT}" --runtime-root "${RUNTIME_ROOT}" --summary-json)"
[[ "${pass_output}" == *'"status":"pass"'* ]] || {
  echo "[FAIL] clean native footprint did not pass: ${pass_output}" >&2
  exit 1
}

mkdir -p "${RUNTIME_ROOT}/vendor/plugins/superpowers/1.0.0/skills/using-superpowers"
printf '%s\n' 'fixture' >"${RUNTIME_ROOT}/vendor/plugins/superpowers/1.0.0/skills/using-superpowers/SKILL.md"
forbidden_output="$(${CHECK} "${FIXTURE_ROOT}" --runtime-root "${RUNTIME_ROOT}" --summary-json)"
[[ "${forbidden_output}" == *'"status":"needs-fix"'* && "${forbidden_output}" == *'"forbidden_skills":1'* && "${forbidden_output}" == *'"forbidden_paths":1'* ]] || {
  echo "[FAIL] forbidden compatibility footprint was not detected: ${forbidden_output}" >&2
  exit 1
}
if "${CHECK}" "${FIXTURE_ROOT}" --runtime-root "${RUNTIME_ROOT}" --strict >/dev/null 2>&1; then
  echo "[FAIL] strict footprint unexpectedly accepted forbidden compatibility assets" >&2
  exit 1
fi

rm -rf "${RUNTIME_ROOT}/vendor/plugins/superpowers" "${RUNTIME_ROOT}/vendor/skills/adk-runtime-router"
missing_output="$(${CHECK} "${FIXTURE_ROOT}" --runtime-root "${RUNTIME_ROOT}" --summary-json)"
[[ "${missing_output}" == *'"missing_required":1'* ]] || {
  echo "[FAIL] missing required ADK skill was not detected: ${missing_output}" >&2
  exit 1
}

echo "[PASS] runtime live footprint enforces native ADK required/forbidden policy"
