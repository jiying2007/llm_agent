#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

required_paths=(
  "manifests/external_practice_sources.json"
  "manifests/external_practice_cycle.json"
  "manifests/reference_repository_registration_policy.json"
  "manifests/reference_repository_removal_policy.json"
  "schemas/external-practice-candidate.schema.json"
  "schemas/external-practice-decision.schema.json"
  "schemas/external-practice-cycle-plan.schema.json"
  "schemas/external-practice-cycle-evidence.schema.json"
  "scripts/practice-intake.sh"
  "scripts/onboard-reference-repository.sh"
  "scripts/check-reference-repository-registration.sh"
  "scripts/check-reference-repository-removal.sh"
  "scripts/plan-reference-repository-removal.sh"
  "tests/test_external_practice_intake.sh"
  "tests/test_reference_repository_registration.sh"
  "tests/test_reference_repository_removal.sh"
  "agent-dev-kit/optional-skills/adk-external-practice-absorption/SKILL.md"
  "agent-dev-kit/agents/external-practice-curator/AGENTS.md"
  "agent-dev-kit/workflows/external-practice-absorption/WORKFLOW.md"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "${ROOT}/${path}" ]]; then
    echo "[FAIL] required external-practice asset missing: ${path}" >&2
    exit 2
  fi
done

"${ROOT}/scripts/practice-intake.sh" check \
  --kind policy \
  --input manifests/external_practice_sources.json
"${ROOT}/scripts/practice-intake.sh" check \
  --kind plan \
  --input manifests/external_practice_cycle.json
"${ROOT}/tests/test_external_practice_intake.sh"
"${ROOT}/tests/test_reference_repository_registration.sh"
"${ROOT}/tests/test_reference_repository_removal.sh"

scan_paths=(
  "AGENTS.md"
  "README.md"
  "architecture"
  "docs"
  "scripts"
  "tests"
  "fixtures"
  "manifests"
  "schemas"
  "agent-dev-kit/manifest.json"
  "agent-dev-kit/manifest.yaml"
  "agent-dev-kit/agents"
  "agent-dev-kit/skills"
  "agent-dev-kit/optional-skills"
  "agent-dev-kit/workflows"
  "agent-dev-kit/docs"
)

legacy_tokens=(
  "scripts/oss-intake.sh"
  "discover-oss-repos.sh"
  "run-oss-intake-cycle.sh"
  "check-oss-intake-ledger.sh"
  "score-oss-candidates.sh"
  "generate-oss-intake-approval-queue.sh"
  "check-oss-approval-queue.sh"
  "check-oss-continuous-operation.sh"
  "generate-wechat-intake-ledger.sh"
  "check-wechat-intake-ledger.sh"
  "check-oss-intake-fixtures.sh"
  "onboard-oss-candidate.sh"
  "check-oss-registration-plan.sh"
  "check-oss-removal-plan.sh"
  "plan-oss-subrepo-removal.sh"
  "test_oss_removal_plan.sh"
  "oss_discovery_sources.json"
  "oss_candidate_scoring_policy.json"
  "oss_continuous_operation.json"
  "oss_intake_approval_queue.json"
  "oss_registration_policy.json"
  "oss_removal_policy.json"
  "adk-intake-workflow"
  "onboard-candidate"
)

for token in "${legacy_tokens[@]}"; do
  if rg -n --fixed-strings \
    --glob '!reports/**' \
    --glob '!archive/**' \
    --glob '!agent-dev-kit/docs/changes/**' \
    --glob '!scripts/check-practice-intake.sh' \
    -- "${token}" "${scan_paths[@]/#/${ROOT}/}"; then
    echo "[FAIL] retired external-practice token remains active: ${token}" >&2
    exit 2
  fi
done

echo "[PASS] external-practice intake is terminal and legacy-free"
