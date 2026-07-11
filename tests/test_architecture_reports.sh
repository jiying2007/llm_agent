#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-architecture-reports.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${CHECKER}" "${ROOT}" --summary-json >/dev/null

fixture_root="${TMP_DIR}/fixture-root"
mkdir -p "${fixture_root}/reports/architecture" "${fixture_root}/manifests" "${fixture_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${fixture_root}/reports/architecture/README.md"
cp "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md" "${fixture_root}/reports/architecture/good.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${fixture_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${fixture_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
"${CHECKER}" "${fixture_root}" --summary-json >/dev/null

legacy_root="${TMP_DIR}/legacy-root"
mkdir -p "${legacy_root}/reports/architecture" "${legacy_root}/manifests" "${legacy_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${legacy_root}/reports/architecture/README.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${legacy_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${legacy_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
python3 - "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md" "${legacy_root}/reports/architecture/legacy.md" <<'PY'
import re
import sys

source, target = sys.argv[1:3]
with open(source, "r", encoding="utf-8") as handle:
    content = handle.read()
for heading in (
    "Architecture Operating Model",
    "SSOT Matrix",
    "Structured Requirements Review",
    "Landing Protocol",
    "Runtime Delivery Contract",
    "Knowledge Promotion Contract",
    "State Reconciliation Contract",
    "Status Consistency Gate",
    "Comprehensive Optimization Backlog",
):
    content = re.sub(rf"\n## {re.escape(heading)}\n.*?(?=\n## |\Z)", "\n", content, flags=re.S)
with open(target, "w", encoding="utf-8") as handle:
    handle.write(content)
PY

legacy_out="${TMP_DIR}/legacy.out"
if "${CHECKER}" "${legacy_root}" >"${legacy_out}" 2>&1; then
  echo "[FAIL] legacy architecture report unexpectedly passed" >&2
  exit 1
fi
for expected in \
  "missing heading: ## Architecture Operating Model" \
  "missing heading: ## SSOT Matrix" \
  "missing heading: ## Structured Requirements Review" \
  "missing heading: ## Landing Protocol" \
  "missing heading: ## Runtime Delivery Contract" \
  "missing heading: ## Knowledge Promotion Contract" \
  "missing heading: ## State Reconciliation Contract" \
  "missing heading: ## Status Consistency Gate" \
  "missing heading: ## Comprehensive Optimization Backlog"
do
  if ! rg -q --fixed-strings -- "${expected}" "${legacy_out}"; then
    echo "[FAIL] legacy architecture report failure did not include: ${expected}" >&2
    sed -n '1,120p' "${legacy_out}" >&2 || true
    exit 1
  fi
done

bad_root="${TMP_DIR}/bad-root"
mkdir -p "${bad_root}/reports/architecture" "${bad_root}/manifests" "${bad_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${bad_root}/reports/architecture/README.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${bad_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${bad_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
cat >"${bad_root}/reports/architecture/bad.md" <<'EOF'
# Bad Architecture Report

## Summary

missing required sections
EOF

bad_out="${TMP_DIR}/bad.out"
if "${CHECKER}" "${bad_root}" >"${bad_out}" 2>&1; then
  echo "[FAIL] bad architecture report unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "missing heading: ## Scope" "${bad_out}"; then
  echo "[FAIL] bad architecture report failure did not name missing heading" >&2
  sed -n '1,80p' "${bad_out}" >&2 || true
  exit 1
fi

bad_summary="${TMP_DIR}/bad-summary.json"
if "${CHECKER}" "${bad_root}" --summary-json >"${bad_summary}" 2>"${TMP_DIR}/bad-summary.err"; then
  echo "[FAIL] bad architecture report summary unexpectedly passed" >&2
  exit 1
fi
python3 - "${bad_summary}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "fail"
assert data["reports"] == 1
assert data["failures"], "expected failures"
PY

missing_manifest_root="${TMP_DIR}/missing-manifest-root"
mkdir -p "${missing_manifest_root}/reports/architecture"
cp "${ROOT}/reports/architecture/README.md" "${missing_manifest_root}/reports/architecture/README.md"
cp "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md" "${missing_manifest_root}/reports/architecture/good.md"
missing_manifest_out="${TMP_DIR}/missing-manifest.out"
if "${CHECKER}" "${missing_manifest_root}" >"${missing_manifest_out}" 2>&1; then
  echo "[FAIL] missing manifest fixture unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "missing file: manifests/comprehensive_optimization_backlog.json" "${missing_manifest_out}"; then
  echo "[FAIL] missing manifest failure did not name manifest path" >&2
  sed -n '1,120p' "${missing_manifest_out}" >&2 || true
  exit 1
fi

echo "[PASS] architecture report checks behave as expected"
