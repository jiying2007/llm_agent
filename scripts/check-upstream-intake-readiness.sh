#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"
REGISTRY="${ROOT}/subrepos/registry.csv"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi
if [[ ! -f "${REGISTRY}" ]]; then
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
fi

tmp_enabled="$(mktemp)"
tmp_matrix="$(mktemp)"
tmp_missing="$(mktemp)"
trap 'rm -f "${tmp_enabled}" "${tmp_matrix}" "${tmp_missing}"' EXIT

awk -F',' 'NR>1 && $6=="yes" && $2!="adk-core" {print $1}' "${REGISTRY}" | sort -u > "${tmp_enabled}"
awk -F'|' '/^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|/ {repo=$3; gsub(/^ +| +$/, "", repo); print repo}' "${MATRIX}" | sort -u > "${tmp_matrix}"
comm -23 "${tmp_enabled}" "${tmp_matrix}" > "${tmp_missing}" || true

if [[ -s "${tmp_missing}" ]]; then
  echo "[FAIL] enabled upstream repos missing in adoption matrix (adk-core excluded):" >&2
  cat "${tmp_missing}" >&2
  exit 1
fi

awk -F'|' '
  BEGIN { failed=0; checked=0 }
  /^\| 20/ {
    decision=$9
    status=$10
    target=$11
    evidence=$12
    gsub(/^ +| +$/, "", decision)
    gsub(/^ +| +$/, "", status)
    gsub(/^ +| +$/, "", target)
    gsub(/^ +| +$/, "", evidence)

    if (decision == "adopt" && status == "done") {
      checked++
      if (target !~ /agent-dev-kit|codex/) {
        print "[FAIL] adopt row missing production target:" $0 > "/dev/stderr"
        failed=1
      }
      if (evidence !~ /agent-dev-kit\/|reports\/|scripts\//) {
        print "[FAIL] adopt row missing local evidence:" $0 > "/dev/stderr"
        failed=1
      }
    }
  }
  END {
    if (checked == 0) {
      print "[FAIL] no adopt+done rows checked" > "/dev/stderr"
      exit 1
    }
    if (failed) {
      exit 1
    }
    printf("[PASS] upstream intake readiness checks passed (%d adopt rows)\n", checked)
  }
' "${MATRIX}"
