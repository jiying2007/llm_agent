# shellcheck shell=bash

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

runtime_evidence_test_init() {
  local root="$1"
  TMP_DIR="$(mktemp -d)"
  COLLECTOR="${root}/scripts/collect-runtime-target-evidence-package.sh"
  CHECKER="${root}/scripts/check-runtime-target-evidence-index.sh"
}

runtime_evidence_test_cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

show_file_head() {
  local file="$1"
  sed -n '1,80p' "${file}" >&2 || true
}

assert_contains() {
  local file="$1"
  local token="$2"
  local message="$3"
  if ! rg -q --fixed-strings -- "${token}" "${file}"; then
    echo "[FAIL] ${message}" >&2
    show_file_head "${file}"
    exit 1
  fi
}

assert_file() {
  local file="$1"
  local message="$2"
  if [[ ! -f "${file}" ]]; then
    fail "${message}"
  fi
}

assert_no_file() {
  local file="$1"
  local message="$2"
  if [[ -f "${file}" ]]; then
    fail "${message}"
  fi
}

assert_canonical_artifacts() {
  local dir="$1"
  local label="$2"
  for artifact in evidence-index.jsonl evidence-index.md current-status.md; do
    assert_file "${dir}/${artifact}" "${label} missing canonical artifact: ${artifact}"
  done
}
