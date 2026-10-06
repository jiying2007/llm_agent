#!/usr/bin/env bash
set -euo pipefail
# 注意: 当前生产链路以 ~/codex 为声明式资产仓库，再由其 apply 到 ~/.codex。

CODEX_ROOT="${1:-$HOME/.codex}"
PROFILE="${2:-minimal}"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "${CODEX_ROOT}" ]]; then
  echo "[FAIL] global codex dir missing: ${CODEX_ROOT}" >&2
  exit 1
fi

echo "[INFO] codex_root=${CODEX_ROOT}"
echo "[INFO] profile=${PROFILE}"

case "${PROFILE}" in
  minimal|security|strict)
    ;;
  *)
    echo "[FAIL] unknown profile: ${PROFILE}" >&2
    echo "usage: scripts/check-global-codex-health.sh [CODEX_ROOT] [minimal|security|strict]" >&2
    exit 1
    ;;
esac

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

audit_runtime_security() {
  local config_file="${CODEX_ROOT}/config.toml"

  if [[ ! -f "${config_file}" ]]; then
    echo "[FAIL] codex config missing: ${config_file}" >&2
    return 3
  fi

  if ! PYTHONPATH="$WORKSPACE_ROOT${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m tools.codex_assets.runtime_security --config "$config_file"; then
    echo '[FAIL] global codex endpoint trust audit failed; endpoint values are redacted' >&2
    return 3
  fi

  if command -v codex >/dev/null 2>&1; then
    mcp_output="$(codex mcp list 2>&1)" || {
      echo "${mcp_output}" >&2
      echo "[FAIL] codex mcp list failed in security profile" >&2
      return 3
    }
    echo "${mcp_output}"
  else
    echo '[WARN] codex CLI not found; MCP loaded-list audit skipped' >&2
  fi

  echo "[PASS] global codex security audit ready"
}

if [[ "${PROFILE}" == "security" || "${PROFILE}" == "strict" ]]; then
  audit_runtime_security
fi

echo "[PASS] global codex health ready"
