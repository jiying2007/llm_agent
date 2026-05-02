#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"

if [[ -d "${ROOT}/codex" ]]; then
  echo "[FAIL] local codex directory still exists: ${ROOT}/codex" >&2
  exit 1
fi

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
fi

line="$(awk -F',' '$1=="codex"{print $0}' "${REGISTRY}" | tail -n1 || true)"
if [[ -z "${line}" ]]; then
  echo "[FAIL] registry missing codex row" >&2
  exit 2
fi

enabled="$(awk -F',' '$1=="codex"{print $6}' "${REGISTRY}" | tail -n1)"
notes="$(awk -F',' '$1=="codex"{print $7}' "${REGISTRY}" | tail -n1)"
status="$(awk -F',' '$1=="codex"{print $8}' "${REGISTRY}" | tail -n1)"
intake_policy="$(awk -F',' '$1=="codex"{print $11}' "${REGISTRY}" | tail -n1)"

if [[ "${enabled}" != "no" ]]; then
  echo "[FAIL] codex registry enabled must be no, got: ${enabled}" >&2
  exit 2
fi

if [[ "${status}" != "disabled" ]]; then
  echo "[FAIL] codex registry status must be disabled, got: ${status}" >&2
  exit 2
fi

if [[ "${intake_policy}" != "pilot-first" ]]; then
  echo "[FAIL] codex registry intake_policy must be pilot-first, got: ${intake_policy}" >&2
  exit 2
fi

if ! printf "%s\n" "${notes}" | rg -q '~/.codex'; then
  echo "[FAIL] codex registry notes must mention ~/.codex policy" >&2
  exit 2
fi

echo "[PASS] global codex target policy ready"
