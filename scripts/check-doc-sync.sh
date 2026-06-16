#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${ROOT}/subrepos/registry.csv"
SCRIPTS_README="${ROOT}/scripts/README.md"
ADOPTION_MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${REGISTRY}" ]]; then
  echo "[FAIL] registry missing: ${REGISTRY}" >&2
  exit 1
fi

if [[ ! -f "${SCRIPTS_README}" ]]; then
  echo "[FAIL] scripts README missing: ${SCRIPTS_README}" >&2
  exit 1
fi

if [[ ! -f "${ADOPTION_MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${ADOPTION_MATRIX}" >&2
  exit 1
fi

expected_header="repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade"
actual_header="$(head -n 1 "${REGISTRY}")"
if [[ "${actual_header}" != "${expected_header}" ]]; then
  echo "[FAIL] registry header out of sync" >&2
  echo "[INFO] expected: ${expected_header}" >&2
  echo "[INFO] actual  : ${actual_header}" >&2
  exit 2
fi

required_tokens=(
  "check-skill-metadata.sh"
  "check-skill-routing-conflicts.sh"
  "check-adk-lock.sh"
  "check-subrepo-state.sh"
  "check-doc-sync.sh"
  "check-adoption-matrix-structured.sh"
  "check-adoption-matrix-status.sh"
  "check-observe-intake-depth.sh"
  "check-runtime-routing.sh"
  "check-codex-pilot-evidence.sh"
  "check-codex-pilot-coverage.sh"
  "check-workspace-entrypoints.sh"
  "generate-wechat-intake-ledger.sh"
  "check-wechat-intake-ledger.sh"
  "check-oss-intake-ledger.sh"
  "score-oss-candidates.sh"
  "check-oss-registration-plan.sh"
  "onboard-oss-candidate.sh"
  "check-oss-removal-plan.sh"
  "plan-oss-subrepo-removal.sh"
  "check-oss-continuous-operation.sh"
  "run-oss-intake-cycle.sh"
  "check-oss-approval-queue.sh"
  "generate-oss-intake-approval-queue.sh"
  "oss-intake.sh"
  "check-oss-intake-fixtures.sh"
  "check-stale-references.sh"
  "check-token-budget.sh"
  "check-file-modes.sh"
  "tests/test_oss_intake_ledger.sh"
  "tests/test_oss_registration_plan.sh"
  "tests/test_oss_removal_plan.sh"
  "tests/test_oss_continuous_operation.sh"
  "tests/test_oss_approval_queue.sh"
  "oss_discovery_sources.json"
  "oss_candidate_scoring_policy.json"
  "subrepo_lifecycle.json"
  "oss_registration_policy.json"
  "oss_removal_policy.json"
  "oss_continuous_operation.json"
  "oss_intake_approval_queue.json"
  "fixtures/oss-intake"
  "oss-discovery-candidates"
  "oss-score-report"
  "oss-onboarding-plan"
  "subrepo-removal-plan"
  "oss-intake-cycle"
  "oss-intake-approval-queue"
  "oss-intake-evidence-bundle"
  "check-upstream-intake-readiness.sh"
  "generate-adoption-matrix-summary.sh"
  "export-adoption-matrix-jsonl.sh"
  "run-post-freeze-cycle.sh"
  "wechat-article-absorption.md"
  "--summary-json"
  "--check-skill-metadata"
  "--check-routing-conflicts"
  "--check-doc-sync"
  "--check-observe-intake-depth"
  "--check-runtime-routing"
  "--check-pilot-coverage"
  "--check-upstream-intake"
)

for token in "${required_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${SCRIPTS_README}"; then
    echo "[FAIL] scripts/README.md missing token: ${token}" >&2
    exit 2
  fi
done

required_scripts=(
  "scripts/check-codex-pilot-evidence.sh"
  "scripts/check-codex-pilot-coverage.sh"
  "scripts/check-workspace-entrypoints.sh"
  "scripts/generate-wechat-intake-ledger.sh"
  "scripts/check-wechat-intake-ledger.sh"
  "scripts/check-oss-intake-ledger.sh"
  "scripts/score-oss-candidates.sh"
  "scripts/check-oss-registration-plan.sh"
  "scripts/onboard-oss-candidate.sh"
  "scripts/check-oss-removal-plan.sh"
  "scripts/plan-oss-subrepo-removal.sh"
  "scripts/check-oss-continuous-operation.sh"
  "scripts/run-oss-intake-cycle.sh"
  "scripts/check-oss-approval-queue.sh"
  "scripts/generate-oss-intake-approval-queue.sh"
  "scripts/oss-intake.sh"
  "scripts/check-oss-intake-fixtures.sh"
  "scripts/check-stale-references.sh"
  "scripts/check-token-budget.sh"
  "scripts/check-file-modes.sh"
  "tests/test_oss_intake_ledger.sh"
  "tests/test_oss_registration_plan.sh"
  "tests/test_oss_removal_plan.sh"
  "tests/test_oss_continuous_operation.sh"
  "tests/test_oss_approval_queue.sh"
)

for script in "${required_scripts[@]}"; do
  if [[ ! -x "${ROOT}/${script}" ]]; then
    echo "[FAIL] required script missing or not executable: ${script}" >&2
    exit 2
  fi
done

matrix_tokens=(
  "类别标签"
  "验收状态"
  "codex-cookbook"
)

for token in "${matrix_tokens[@]}"; do
  if ! rg -q --fixed-strings -- "${token}" "${ADOPTION_MATRIX}"; then
    echo "[FAIL] adoption-matrix missing token: ${token}" >&2
    exit 2
  fi
done

echo "[PASS] docs and governance files are in sync"
