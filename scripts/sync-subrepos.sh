#!/usr/bin/env bash
set -u

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MODE="${2:-fetch}"
REGISTRY="${ROOT}/subrepos/registry.csv"
GATE_FILE="${ROOT}/subrepos/phase-gate.env"
FORCE_FLAG="${3:-}"
FORCE=0

if [[ "${FORCE_FLAG}" == "--force" ]]; then
  FORCE=1
fi

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[ERROR] registry not found: ${REGISTRY}" >&2
  exit 1
fi

if [[ "${MODE}" != "fetch" && "${MODE}" != "pull" ]]; then
  echo "[ERROR] MODE must be fetch or pull" >&2
  exit 1
fi

allow_sync="yes"
phase_name="unknown"
if [[ -f "${GATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${GATE_FILE}"
  allow_sync="${allow_upstream_sync:-no}"
  phase_name="${phase:-unknown}"
fi

if [[ "${allow_sync}" != "yes" && "${FORCE}" -ne 1 ]]; then
  echo "[BLOCK] upstream sync disabled by phase gate" >&2
  echo "[INFO] phase=${phase_name} allow_upstream_sync=${allow_sync}" >&2
  echo "[INFO] run scripts/check-gdk-harden-readiness.sh first" >&2
  echo "[INFO] override once: scripts/sync-subrepos.sh . ${MODE} --force" >&2
  exit 3
fi

ok=0
fail=0
skip=0

echo "[INFO] root=${ROOT}"
echo "[INFO] mode=${MODE}"
echo "[INFO] registry=${REGISTRY}"
echo "[INFO] phase=${phase_name}"
echo "[INFO] force=${FORCE}"

while IFS=',' read -r repo group priority sync_mode branch enabled notes status owner last_reviewed_on intake_policy; do
  if [[ "${repo}" == "repo" || -z "${repo}" ]]; then
    continue
  fi
  if [[ "${enabled}" != "yes" || "${status}" == "disabled" ]]; then
    echo "[SKIP] ${repo}: disabled (enabled=${enabled} status=${status})"
    ((skip+=1))
    continue
  fi

  repo_path="${ROOT}/${repo}"
  if [[ ! -d "${repo_path}" || ! -d "${repo_path}/.git" ]]; then
    echo "[SKIP] ${repo}: not a git repo directory"
    ((skip+=1))
    continue
  fi

  if [[ "${MODE}" == "fetch" ]]; then
    if git -C "${repo_path}" fetch --all --prune >/dev/null 2>&1; then
      echo "[ OK ] ${repo}: fetch"
      ((ok+=1))
    else
      echo "[FAIL] ${repo}: fetch failed"
      ((fail+=1))
    fi
    continue
  fi

  if [[ "${sync_mode}" != "pull" ]]; then
    echo "[SKIP] ${repo}: sync_mode=${sync_mode}, pull skipped"
    ((skip+=1))
    continue
  fi

  current_branch="$(git -C "${repo_path}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "${current_branch}" ]]; then
    echo "[SKIP] ${repo}: detached HEAD"
    ((skip+=1))
    continue
  fi

  if [[ "${branch}" != "-" && "${branch}" != "${current_branch}" ]]; then
    echo "[SKIP] ${repo}: current=${current_branch}, expected=${branch}"
    ((skip+=1))
    continue
  fi

  if git -C "${repo_path}" pull --ff-only >/dev/null 2>&1; then
    echo "[ OK ] ${repo}: pull ${current_branch}"
    ((ok+=1))
  else
    echo "[FAIL] ${repo}: pull failed"
    ((fail+=1))
  fi
done < "${REGISTRY}"

echo
echo "[SUMMARY] ok=${ok} fail=${fail} skip=${skip}"

if ((fail > 0)); then
  exit 2
fi
