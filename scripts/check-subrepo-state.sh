#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STRICT=0
SUMMARY_JSON=0

for arg in "${@:2}"; do
  case "${arg}" in
    --strict)
      STRICT=1
      ;;
    --summary-json)
      SUMMARY_JSON=1
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-subrepo-state.sh [root] [--strict] [--summary-json]

Default mode enforces strict cleanliness only for agent-dev-kit. Other enabled
reference repositories are reported as observe state. If
subrepos/dirty-baseline.tsv marks an observe repository as expected dirty, the
row is shown as known-dirty to reduce review noise.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: ${arg}" >&2
      exit 1
      ;;
  esac
done

REGISTRY="${ROOT}/subrepos/registry.csv"
BASELINE="${ROOT}/subrepos/dirty-baseline.tsv"
[[ -f "${REGISTRY}" ]] || {
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
}

baseline_field() {
  local repo="$1"
  local field="$2"
  [[ -f "${BASELINE}" ]] || return 1
  awk -F '\t' -v repo="${repo}" -v field="${field}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == field) col = i
      }
      next
    }
    $1 == repo && col {
      print $col
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' "${BASELINE}"
}

missing=0
uninitialized=0
dirty=0
known_dirty=0
unexpected_dirty=0
clean=0
failed=0

if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
  printf '%-28s %-14s %-10s %s\n' "repo" "state" "policy" "detail"
  printf '%-28s %-14s %-10s %s\n' "----------------------------" "--------------" "----------" "------"
fi

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
      expected_state="$(baseline_field "${repo}" "expected_state" || true)"
      reason="$(baseline_field "${repo}" "reason" || true)"
      baseline_ref="$(baseline_field "${repo}" "baseline_ref" || true)"
      if [[ "${policy}" == "observe" && "${expected_state}" == "dirty" ]]; then
        state="known-dirty"
        detail="${detail}; baseline=${baseline_ref:-unknown}; reason=${reason:-expected-observe-state}"
        known_dirty=$((known_dirty + 1))
      else
        unexpected_dirty=$((unexpected_dirty + 1))
      fi
    else
      clean=$((clean + 1))
    fi
  fi

  if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
    printf '%-28s %-14s %-10s %s\n' "${repo}" "${state}" "${policy}" "${detail}"
  fi

  if [[ "${policy}" == "strict" && "${state}" != "clean" ]]; then
    if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
      echo "[FAIL] strict subrepo not clean: ${repo} (${state})" >&2
    fi
    failed=1
  fi

  if [[ "${STRICT}" -eq 1 && "${state}" != "clean" ]]; then
    failed=1
  fi
done < "${REGISTRY}"

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  status="pass"
  [[ "${failed}" -ne 0 ]] && status="fail"
  printf '{"status":"%s","clean":%s,"dirty":%s,"known_dirty":%s,"unexpected_dirty":%s,"uninitialized":%s,"missing":%s,"strict":%s}\n' \
    "${status}" "${clean}" "${dirty}" "${known_dirty}" "${unexpected_dirty}" "${uninitialized}" "${missing}" "${STRICT}"
else
  echo
  echo "[SUMMARY] clean=${clean} dirty=${dirty} known_dirty=${known_dirty} unexpected_dirty=${unexpected_dirty} uninitialized=${uninitialized} missing=${missing} strict=${STRICT}"
fi

if [[ "${failed}" -ne 0 ]]; then
  if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
    echo "[FAIL] subrepo state policy failed" >&2
  fi
  exit 1
fi

if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
  echo "[PASS] subrepo state policy ready"
fi
