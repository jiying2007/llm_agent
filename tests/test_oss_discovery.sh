#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --repo example/manual-discovery --out "${TMP_DIR}/manual.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/manual.jsonl" --summary-json >/dev/null

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --source "${ROOT}/fixtures/oss-intake/discovery-source.md" --out "${TMP_DIR}/source.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/source.jsonl" --summary-json >/dev/null

"${ROOT}/scripts/oss-intake.sh" discover --dry-run --repo example/wrapper-discovery --out "${TMP_DIR}/wrapper.jsonl" >/dev/null

echo "[PASS] oss discovery tests passed"
