#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_DIR="${ROOT}/agent-dev-kit"
GATE_FILE="${ROOT}/subrepos/phase-gate.env"
AUTO_OPEN=0
REQUIRE_PILOT=0
CHECK_GLOBAL_CODEX=1
CHECK_FULL_SUITE=1
CHECK_SKILL_METADATA=1
CHECK_ROUTING_CONFLICTS=1
CHECK_DOC_SYNC=1
CHECK_MATRIX_STATUS=1
CHECK_OBSERVE_INTAKE_DEPTH=1
CHECK_DELIVERY_ADOPT_DEPTH=1
CHECK_RUNTIME_ROUTING=1
CHECK_PILOT_COVERAGE=1
CHECK_UPSTREAM_INTAKE=1
CHECK_CODEX_HANDOFF=1
ADK_SUITE_TMP=""
PARITY_RECEIPT_REUSED=0

cleanup_adk_suite_tmp() {
  if [[ -n "${ADK_SUITE_TMP}" && -d "${ADK_SUITE_TMP}" ]]; then
    rm -rf "${ADK_SUITE_TMP}"
  fi
}

trap cleanup_adk_suite_tmp EXIT

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
    --check-skill-metadata)
      CHECK_SKILL_METADATA=1
      ;;
    --check-routing-conflicts)
      CHECK_ROUTING_CONFLICTS=1
      ;;
    --check-doc-sync)
      CHECK_DOC_SYNC=1
      ;;
    --check-matrix-status)
      CHECK_MATRIX_STATUS=1
      ;;
    --check-observe-intake-depth)
      CHECK_OBSERVE_INTAKE_DEPTH=1
      ;;
    --check-delivery-adopt-depth)
      CHECK_DELIVERY_ADOPT_DEPTH=1
      ;;
    --check-runtime-routing)
      CHECK_RUNTIME_ROUTING=1
      ;;
    --check-pilot-coverage)
      CHECK_PILOT_COVERAGE=1
      ;;
    --check-upstream-intake)
      CHECK_UPSTREAM_INTAKE=1
      ;;
    --check-codex-handoff)
      CHECK_CODEX_HANDOFF=1
      ;;
    --skip-skill-metadata-check)
      CHECK_SKILL_METADATA=0
      ;;
    --skip-routing-conflicts-check)
      CHECK_ROUTING_CONFLICTS=0
      ;;
    --skip-doc-sync-check)
      CHECK_DOC_SYNC=0
      ;;
    --skip-matrix-status-check)
      CHECK_MATRIX_STATUS=0
      ;;
    --skip-observe-intake-depth-check)
      CHECK_OBSERVE_INTAKE_DEPTH=0
      ;;
    --skip-delivery-adopt-depth-check)
      CHECK_DELIVERY_ADOPT_DEPTH=0
      ;;
    --skip-runtime-routing-check)
      CHECK_RUNTIME_ROUTING=0
      ;;
    --skip-pilot-coverage-check)
      CHECK_PILOT_COVERAGE=0
      ;;
    --skip-upstream-intake-check)
      CHECK_UPSTREAM_INTAKE=0
      ;;
    --skip-codex-handoff-check)
      CHECK_CODEX_HANDOFF=0
      ;;
    *)
      echo "[FAIL] unknown arg: ${arg}" >&2
      echo "usage: scripts/check-adk-harden-readiness.sh <root> [--open-gate] [--require-pilot] [--skip-global-codex-check] [--skip-full-suite] [--check-skill-metadata] [--check-routing-conflicts] [--check-doc-sync] [--check-matrix-status] [--check-observe-intake-depth] [--check-delivery-adopt-depth] [--check-runtime-routing] [--check-pilot-coverage] [--check-upstream-intake] [--check-codex-handoff] [--skip-skill-metadata-check] [--skip-routing-conflicts-check] [--skip-doc-sync-check] [--skip-matrix-status-check] [--skip-observe-intake-depth-check] [--skip-delivery-adopt-depth-check] [--skip-runtime-routing-check] [--skip-pilot-coverage-check] [--skip-upstream-intake-check] [--skip-codex-handoff-check]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${ADK_DIR}" ]]; then
  echo "[FAIL] agent-dev-kit not found: ${ADK_DIR}" >&2
  exit 1
fi

if [[ ! -f "${GATE_FILE}" ]]; then
  echo "[FAIL] phase gate file missing: ${GATE_FILE}" >&2
  exit 1
fi

echo "[INFO] check adk harden readiness"
echo "[INFO] adk=${ADK_DIR}"
echo "[INFO] gate=${GATE_FILE}"

if [[ "${CHECK_FULL_SUITE}" -eq 1 ]]; then
  receipt_check_output=""
  if receipt_check_output="$(bash "${ADK_DIR}/scripts/run-local-ci-parity.sh" \
    --python all --mode full --check-receipt 2>&1)"; then
    PARITY_RECEIPT_REUSED=1
    echo "[PASS] reuse snapshot-bound Python 3.11/3.12 full parity receipt"
  else
    echo "[INFO] no reusable supported-full parity receipt; require supported host Python"
    ADK_REQUIRE_SUPPORTED_PYTHON=1 bash "${ADK_DIR}/scripts/devkit.sh" validate --quick --summary-json >/dev/null
  fi
fi

bash "${ADK_DIR}/scripts/validate-assets.sh" --strict
bash "${ADK_DIR}/tests/test_optional_skills.sh"
bash "${ADK_DIR}/tests/test_no_external_repo_refs.sh"
bash "${ROOT}/scripts/check-stale-references.sh" "${ROOT}"
bash "${ROOT}/scripts/check-file-modes.sh" "${ROOT}"
bash "${ROOT}/scripts/check-runtime-targets.sh" "${ROOT}"
bash "${ROOT}/scripts/check-reference-dirty-triage.sh" "${ROOT}"
bash "${ROOT}/scripts/check-file-modes.sh" "${ADK_DIR}"

echo "[PASS] adk harden baseline checks passed"

if [[ "${CHECK_SKILL_METADATA}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-skill-metadata.sh" "${ROOT}"
fi

if [[ "${CHECK_ROUTING_CONFLICTS}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-skill-routing-conflicts.sh" "${ROOT}"
fi

if [[ "${CHECK_DOC_SYNC}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-doc-sync.sh" "${ROOT}"
fi

if [[ "${CHECK_MATRIX_STATUS}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-adoption-matrix-status.sh" "${ROOT}"
  bash "${ROOT}/scripts/check-adoption-real-assets.sh" "${ROOT}"
  bash "${ROOT}/scripts/check-adk-target-evidence.sh" "${ROOT}"
fi

if [[ "${CHECK_OBSERVE_INTAKE_DEPTH}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-observe-intake-depth.sh" "${ROOT}"
fi

if [[ "${CHECK_DELIVERY_ADOPT_DEPTH}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-delivery-adopt-depth.sh" "${ROOT}"
fi

if [[ "${CHECK_RUNTIME_ROUTING}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-runtime-routing.sh" "${ROOT}"
fi

bash "${ADK_DIR}/scripts/check-fallback-sunset.sh" --summary-json

if [[ "${CHECK_UPSTREAM_INTAKE}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-upstream-intake-readiness.sh" "${ROOT}"
fi

if [[ "${CHECK_CODEX_HANDOFF}" -eq 1 ]]; then
  if [[ -x "${ADK_DIR}/scripts/check-codex-handoff.sh" ]]; then
    bash "${ADK_DIR}/scripts/check-codex-handoff.sh" --codex-root "$HOME/codex"
  else
    bash "${ROOT}/scripts/check-runtime-live-footprint.sh" "${ROOT}" --summary-json
    echo "[PASS] runtime live handoff evidence ready"
  fi
fi

if [[ "${CHECK_FULL_SUITE}" -eq 1 && "${PARITY_RECEIPT_REUSED}" -eq 0 ]]; then
  ADK_SUITE_TMP="$(mktemp -d)"
  ADK_SUITE_DIR="${ADK_SUITE_TMP}/agent-dev-kit"
  ADK_EXPECTED_HEAD="$(git -C "${ADK_DIR}" rev-parse HEAD)"
  git clone --quiet --no-hardlinks "${ADK_DIR}" "${ADK_SUITE_DIR}"
  ADK_CLONED_HEAD="$(git -C "${ADK_SUITE_DIR}" rev-parse HEAD)"
  if [[ "${ADK_CLONED_HEAD}" != "${ADK_EXPECTED_HEAD}" ]]; then
    echo "[FAIL] isolated ADK suite clone HEAD mismatch: expected=${ADK_EXPECTED_HEAD} actual=${ADK_CLONED_HEAD}" >&2
    exit 1
  fi
  WORKSPACE_TOP="$(git -C "${ROOT}" rev-parse --show-toplevel)"
  for sibling in OpenSpec oh-my-codex planning-with-files scale-engine superpowers vibeflow; do
    if [[ ! -d "${WORKSPACE_TOP}/${sibling}" ]]; then
      echo "[FAIL] isolated ADK suite sibling source missing: ${sibling}" >&2
      exit 1
    fi
    ln -s "${WORKSPACE_TOP}/${sibling}" "${ADK_SUITE_TMP}/${sibling}"
  done
  echo "[INFO] run ADK full suite from isolated exact-HEAD clone: ${ADK_CLONED_HEAD}"
  ADK_REQUIRE_SUPPORTED_PYTHON=1 bash "${ADK_SUITE_DIR}/tests/run_all.sh"
  cleanup_adk_suite_tmp
  ADK_SUITE_TMP=""
  echo "[PASS] adk full regression suite passed"
fi

if [[ "${REQUIRE_PILOT}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-runtime-pilot.sh" "${ROOT}" evidence
  if [[ "${CHECK_PILOT_COVERAGE}" -eq 1 ]]; then
    bash "${ROOT}/scripts/check-runtime-pilot.sh" "${ROOT}" coverage
  fi
fi

if [[ "${CHECK_GLOBAL_CODEX}" -eq 1 ]]; then
  bash "${ROOT}/scripts/check-runtime-health.sh" "${ROOT}" --profile minimal
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
