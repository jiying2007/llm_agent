#!/usr/bin/env bash
set -euo pipefail
# 注意: 当前生产链路以 ~/codex 为声明式资产仓库，再由其 apply 到 ~/.codex。

CODEX_ROOT="${1:-$HOME/.codex}"
PROFILE="${2:-minimal}"

if [[ ! -d "${CODEX_ROOT}" ]]; then
  echo "[FAIL] global codex dir missing: ${CODEX_ROOT}" >&2
  exit 1
fi

echo "[INFO] codex_root=${CODEX_ROOT}"
echo "[INFO] profile=${PROFILE}"

CODEX_REPO="${HOME}/codex"
DOCTOR="${CODEX_REPO}/scripts/doctor.sh"
if [[ ! -f "${DOCTOR}" ]]; then
  echo "[FAIL] ~/codex doctor script missing: ${DOCTOR}" >&2
  exit 2
fi

output="$(cd "${CODEX_REPO}" && bash "${DOCTOR}" --scope live --target "${CODEX_ROOT}" 2>&1)" || {
  echo "${output}" >&2
  echo "[FAIL] ~/codex live doctor failed" >&2
  exit 2
}

echo "${output}"

if ! printf "%s\n" "${output}" | rg -q 'errors=0'; then
  echo "[FAIL] ~/codex live doctor output missing errors=0" >&2
  exit 2
fi

echo "[PASS] global codex health ready"
