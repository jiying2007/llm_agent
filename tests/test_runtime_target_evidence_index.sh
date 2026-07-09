#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

GENERATOR="${ROOT}/scripts/generate-runtime-target-evidence-index.sh"
CHECKER="${ROOT}/scripts/check-runtime-target-evidence-index.sh"

codex_out="${TMP_DIR}/codex-home.md"
candidate_out="${TMP_DIR}/claude-code-home.md"
codex_jsonl="${TMP_DIR}/codex-home.jsonl"

"${GENERATOR}" "${ROOT}" --target codex-home --format both --out "${codex_out}" --jsonl-out "${codex_jsonl}" >/dev/null
"${GENERATOR}" "${ROOT}" --target claude-code-home --out "${candidate_out}" >/dev/null

if ! rg -q --fixed-strings -- "CODEX-HOME-DECL-001" "${codex_out}"; then
  echo "[FAIL] codex evidence index missing stable evidence id" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "- activation_ready: true" "${codex_out}"; then
  echo "[FAIL] codex evidence index missing activation_ready=true" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"schema_version":"runtime-target-evidence-index/v1"' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing schema_version" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"approval_status":"required"' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing approval_status=required" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"artifact_sha256":null' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing artifact_sha256 placeholder" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "CLAUDE-CODE-HOME-DECL-001" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing stable evidence id" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "- activation_ready: false" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing activation_ready=false" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "Candidate targets remain blocked" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing blocked boundary" >&2
  exit 1
fi

missing_out="${TMP_DIR}/missing.out"
if "${GENERATOR}" "${ROOT}" --target missing-runtime-home >"${missing_out}" 2>&1; then
  echo "[FAIL] missing target evidence index unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "runtime target not declared: missing-runtime-home" "${missing_out}"; then
  echo "[FAIL] missing target evidence index did not explain failure" >&2
  sed -n '1,80p' "${missing_out}" >&2 || true
  exit 1
fi

"${CHECKER}" "${ROOT}" >/dev/null

echo "[PASS] runtime target evidence index generator behaves as expected"
