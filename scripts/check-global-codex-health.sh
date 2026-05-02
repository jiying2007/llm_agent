#!/usr/bin/env bash
set -euo pipefail

CODEX_ROOT="${1:-$HOME/.codex}"
PROFILE="${2:-minimal}"

if [[ ! -d "${CODEX_ROOT}" ]]; then
  echo "[FAIL] global codex dir missing: ${CODEX_ROOT}" >&2
  exit 1
fi

DOCTOR="${CODEX_ROOT}/control/scripts/doctor.sh"
if [[ ! -f "${DOCTOR}" ]]; then
  echo "[FAIL] doctor script missing: ${DOCTOR}" >&2
  exit 1
fi

echo "[INFO] codex_root=${CODEX_ROOT}"
echo "[INFO] profile=${PROFILE}"

output="$(bash "${DOCTOR}" "${CODEX_ROOT}" "${PROFILE}" 2>&1)" || {
  echo "${output}" >&2
  echo "[FAIL] global codex doctor failed" >&2
  exit 2
}

echo "${output}"

if ! printf "%s\n" "${output}" | rg -q 'errors=0'; then
  echo "[FAIL] global codex doctor output missing errors=0" >&2
  exit 2
fi

echo "[PASS] global codex health ready"

