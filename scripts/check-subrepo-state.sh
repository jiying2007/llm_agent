#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STRICT=0
if [[ "${2:-}" == "--strict" ]]; then
  STRICT=1
fi

REGISTRY="${ROOT}/subrepos/registry.csv"
[[ -f "${REGISTRY}" ]] || {
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
}

missing=0
uninitialized=0
dirty=0
clean=0
failed=0

printf '%-28s %-14s %-10s %s\n' "repo" "state" "policy" "detail"
printf '%-28s %-14s %-10s %s\n' "----------------------------" "--------------" "----------" "------"

while IFS=',' read -r repo group priority sync_mode branch enabled notes status owner reviewed intake grade; do
  [[ "${repo}" == "repo" ]] && continue
  [[ "${enabled}" == "yes" && "${status}" == "active" ]] || continue

  policy="observe"
  [[ "${repo}" == "agent-dev-kit" ]] && policy="strict"

  path="${ROOT}/${repo}"
  state="clean"
  detail="-"

  if [[ ! -e "${path}" ]]; then
    state="missing"
    detail="path not found"
    missing=$((missing + 1))
  elif ! git -C "${path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    state="uninitialized"
    detail="submodule not initialized"
    uninitialized=$((uninitialized + 1))
  else
    porcelain="$(git -C "${path}" status --porcelain)"
    if [[ -n "${porcelain}" ]]; then
      state="dirty"
      detail="$(printf '%s\n' "${porcelain}" | wc -l | tr -d ' ') changes"
      dirty=$((dirty + 1))
    else
      clean=$((clean + 1))
    fi
  fi

  printf '%-28s %-14s %-10s %s\n' "${repo}" "${state}" "${policy}" "${detail}"

  if [[ "${policy}" == "strict" && "${state}" != "clean" ]]; then
    echo "[FAIL] strict subrepo not clean: ${repo} (${state})" >&2
    failed=1
  fi

  if [[ "${STRICT}" -eq 1 && "${state}" != "clean" ]]; then
    failed=1
  fi
done < "${REGISTRY}"

echo
echo "[SUMMARY] clean=${clean} dirty=${dirty} uninitialized=${uninitialized} missing=${missing} strict=${STRICT}"

if [[ "${failed}" -ne 0 ]]; then
  echo "[FAIL] subrepo state policy failed" >&2
  exit 1
fi

echo "[PASS] subrepo state policy ready"
