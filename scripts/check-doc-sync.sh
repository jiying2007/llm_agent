#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"
SCRIPTS_README="${ROOT}/scripts/README.md"
ADOPTION_MATRIX="${ROOT}/subrepos/adoption-matrix.md"
ROOT_AGENTS="${ROOT}/AGENTS.md"
MAX_ROOT_AGENTS_LINES=180

required_docs=(
  "${REGISTRY}"
  "${SCRIPTS_README}"
  "${ADOPTION_MATRIX}"
  "${ROOT_AGENTS}"
  "${ROOT}/docs/llm-agent-maintenance-guide.md"
  "${ROOT}/docs/absorption-governance.md"
  "${ROOT}/docs/runbooks/external-practice-intake.md"
  "${ROOT}/docs/runbooks/reference-repository-lifecycle.md"
  "${ROOT}/docs/runbooks/wechat-metadata-intake.md"
  "${ROOT}/architecture/external-practice-intake-terminal.md"
)

for path in "${required_docs[@]}"; do
  if [[ ! -f "${path}" ]]; then
    echo "[FAIL] required governance document missing: ${path}" >&2
    exit 1
  fi
done

root_agents_lines="$(wc -l <"${ROOT_AGENTS}" | tr -d ' ')"
if [[ "${root_agents_lines}" -gt "${MAX_ROOT_AGENTS_LINES}" ]]; then
  echo "[FAIL] root AGENTS.md exceeds slim-entry budget: lines=${root_agents_lines} limit=${MAX_ROOT_AGENTS_LINES}" >&2
  exit 2
fi

root_agents_tokens=(
  "subrepos/registry.csv"
  "subrepos/adoption-matrix.md"
  "docs/llm-agent-maintenance-guide.md"
  "docs/absorption-governance.md"
  "external-practice"
  "Gitee"
  "agent-dev-kit/"
)

for token in "${root_agents_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${ROOT_AGENTS}"; then
    echo "[FAIL] root AGENTS.md missing slim-entry token: ${token}" >&2
    exit 2
  fi
done

expected_header="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade"
actual_header="$(head -n 1 "${REGISTRY}")"
if [[ "${actual_header}" != "${expected_header}" ]]; then
  echo "[FAIL] registry header out of sync" >&2
  echo "[INFO] expected: ${expected_header}" >&2
  echo "[INFO] actual  : ${actual_header}" >&2
  exit 2
fi

readme_tokens=(
  "practice-intake.sh"
  "check-practice-intake.sh"
  "external_practice_sources.json"
  "external_practice_cycle.json"
  "external-practice-candidate/v1"
  "onboard-reference-repository.sh"
  "check-reference-repository-registration.sh"
  "check-reference-repository-removal.sh"
  "plan-reference-repository-removal.sh"
  "external-practice-intake.md"
  "reference-repository-lifecycle.md"
  "wechat-metadata-intake.md"
  "Gitee"
  "degraded-empty"
  "--allow-network"
  "report-only"
  "check-adoption-matrix-status.sh"
  "check-adoption-real-assets.sh"
  "check-adk-target-evidence.sh"
  "check-runtime-targets.sh"
  "check-runtime-health.sh"
  "python3 -m tools.codex_assets execution-policy"
  "check-runtime-routing.sh"
  "check-runtime-pilot.sh"
  "check-runtime-live-footprint.sh"
  "check-loop-readiness.sh"
  "check-scale-engine-governance.sh"
  "check-token-budget.sh"
  "check-file-modes.sh"
  "check-root-regression.sh"
  "tests/run_all.sh"
  "tests/test_check_all_contract.sh"
  "--summary-json"
)

for token in "${readme_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${SCRIPTS_README}"; then
    echo "[FAIL] scripts/README.md missing token: ${token}" >&2
    exit 2
  fi
done

retired_operator_doc_tokens=(
  "~/codex/scripts/runtime-control.sh"
  "scripts/execution-policy.sh"
  "agent-dev-kit/scripts/check-profile-coherence.sh"
)
for token in "${retired_operator_doc_tokens[@]}"; do
  if rg -q --fixed-strings -- "${token}" "${SCRIPTS_README}"; then
    echo "[FAIL] scripts/README.md references retired operator path: ${token}" >&2
    exit 2
  fi
done

required_executables=(
  "scripts/practice-intake.sh"
  "scripts/check-practice-intake.sh"
  "scripts/onboard-reference-repository.sh"
  "scripts/check-reference-repository-registration.sh"
  "scripts/check-reference-repository-removal.sh"
  "scripts/plan-reference-repository-removal.sh"
  "scripts/check-architecture-reports.sh"
  "scripts/check-current-status-consistency.sh"
  "scripts/software-m5.sh"
  "scripts/check-software-m5-readiness.sh"
  "scripts/check-runtime-pilot.sh"
  "scripts/check-runtime-pilot-evidence.sh"
  "scripts/check-runtime-pilot-coverage.sh"
  "scripts/check-runtime-live-footprint.sh"
  "scripts/check-runtime-health.sh"
  "scripts/check-runtime-health-adapters-fixtures.sh"
  "scripts/check-runtime-targets.sh"
  "scripts/generate-runtime-target-evidence-index.sh"
  "scripts/check-runtime-target-evidence-index.sh"
  "scripts/collect-runtime-target-evidence-package.sh"
  "scripts/check-reference-dirty-triage.sh"
  "scripts/generate-reference-dirty-triage.sh"
  "scripts/classify-repo-worktree.sh"
  "scripts/check-reference-source-integrity.sh"
  "scripts/check-asset-inventory.sh"
  "scripts/check-workspace-entrypoints.sh"
  "scripts/check-adoption-real-assets.sh"
  "scripts/check-adk-target-evidence.sh"
  "scripts/check-loop-readiness.sh"
  "scripts/check-scale-engine-governance.sh"
  "scripts/check-stale-references.sh"
  "scripts/check-token-budget.sh"
  "scripts/check-file-modes.sh"
  "scripts/check-root-regression.sh"
  "tests/run_all.sh"
  "tests/test_check_all_contract.sh"
  "tests/test_external_practice_intake.sh"
  "tests/test_reference_repository_registration.sh"
  "tests/test_reference_repository_removal.sh"
  "tests/test_reference_source_integrity.sh"
  "tests/test_runtime_health_adapters.sh"
  "tests/test_runtime_target_evidence_index.sh"
  "tests/test_runtime_target_evidence_package.sh"
  "tests/test_runtime_target_evidence_promotion.sh"
)

for executable in "${required_executables[@]}"; do
  if [[ ! -x "${ROOT}/${executable}" ]]; then
    echo "[FAIL] required executable missing or not executable: ${executable}" >&2
    exit 2
  fi
done

required_assets=(
  "manifests/external_practice_sources.json"
  "manifests/external_practice_cycle.json"
  "manifests/reference_repository_lifecycle_policy.json"
  "manifests/runtime_targets.json"
  "schemas/external-practice-candidate.schema.json"
  "schemas/external-practice-decision.schema.json"
  "fixtures/external-practice"
  "fixtures/reference-repository/removal"
)

for asset in "${required_assets[@]}"; do
  if [[ ! -e "${ROOT}/${asset}" ]]; then
    echo "[FAIL] required governance asset missing: ${asset}" >&2
    exit 2
  fi
done

for retired in \
  manifests/reference_repository_registration_policy.json \
  manifests/reference_repository_removal_policy.json \
  manifests/runtime_health_adapters.json \
  manifests/long_term_asset_rehearsal.json
do
  if [[ -e "${ROOT}/${retired}" ]]; then
    echo "[FAIL] retired split governance asset still exists: ${retired}" >&2
    exit 2
  fi
done

matrix_tokens=("类别标签" "验收状态" "codex-cookbook")
for token in "${matrix_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${ADOPTION_MATRIX}"; then
    echo "[FAIL] adoption-matrix missing token: ${token}" >&2
    exit 2
  fi
done

echo "[PASS] docs and governance files are in sync"
