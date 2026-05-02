#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GDK_DIR="${ROOT}/global-dev-kit"
GATE_FILE="${ROOT}/subrepos/phase-gate.env"
AUTO_OPEN=0
REQUIRE_PILOT=0
CHECK_GLOBAL_CODEX=1
CHECK_FULL_SUITE=1

for arg in "${@:2}"; do
  case "${arg}" in
    --open-gate)
      AUTO_OPEN=1
      ;;
    --require-pilot)
      REQUIRE_PILOT=1
      ;;
    --skip-global-codex-check)
      CHECK_GLOBAL_CODEX=0
      ;;
    --skip-full-suite)
      CHECK_FULL_SUITE=0
      ;;
    *)
      echo "[FAIL] unknown arg: ${arg}" >&2
      echo "usage: scripts/check-gdk-harden-readiness.sh <root> [--open-gate] [--require-pilot] [--skip-global-codex-check] [--skip-full-suite]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${GDK_DIR}" ]]; then
  echo "[FAIL] global-dev-kit not found: ${GDK_DIR}" >&2
  exit 1
fi

if [[ ! -f "${GATE_FILE}" ]]; then
  echo "[FAIL] phase gate file missing: ${GATE_FILE}" >&2
  exit 1
fi

echo "[INFO] check gdk harden readiness"
echo "[INFO] gdk=${GDK_DIR}"
echo "[INFO] gate=${GATE_FILE}"

bash "${GDK_DIR}/scripts/validate_assets.sh" --strict
bash "${GDK_DIR}/tests/test_optional_skills.sh"
bash "${GDK_DIR}/tests/test_no_external_repo_refs.sh"

echo "[PASS] gdk harden baseline checks passed"

if [[ "${CHECK_FULL_SUITE}" -eq 1 ]]; then
  bash "${GDK_DIR}/tests/run_all.sh"
  echo "[PASS] gdk full regression suite passed"
fi

if [[ "${REQUIRE_PILOT}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-codex-pilot-evidence.sh" "${ROOT}"
fi

if [[ "${CHECK_GLOBAL_CODEX}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-global-codex-health.sh" "$HOME/.codex" "minimal"
fi

if [[ "${AUTO_OPEN}" -eq 1 ]]; then
  if grep -q '^allow_upstream_sync=' "${GATE_FILE}"; then
    sed -i 's/^allow_upstream_sync=.*/allow_upstream_sync=yes/' "${GATE_FILE}"
  else
    echo "allow_upstream_sync=yes" >> "${GATE_FILE}"
  fi

  if grep -q '^opened_on=' "${GATE_FILE}"; then
    sed -i "s/^opened_on=.*/opened_on=$(date +%F)/" "${GATE_FILE}"
  else
    echo "opened_on=$(date +%F)" >> "${GATE_FILE}"
  fi

  echo "[PASS] phase gate opened"
fi
