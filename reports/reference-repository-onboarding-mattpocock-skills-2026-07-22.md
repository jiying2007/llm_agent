# Reference Repository Onboarding Plan

> schema: reference-repository-onboarding/v1
> status: applied
> mode: apply
> candidate: epc-43e82b2e69e37e419c3f
> owner: llm-agent-governance-owner

## Gates

| gate | result |
|---|---|
| candidate_contract_gate | pass |
| owner_decision_gate | pass |
| repository_metadata_gate | pass |
| source_risk_gate | pass |
| analysis_report_gate | pass |
| duplicate_check_gate | pass |
| security_review_gate | pass |
| phase_gate | pass |
| registry_conflict_gate | pass |
| target_path_gate | pass |
| materialization_gate | pass |
| apply_workspace_gate | pass |
| rollback_plan_gate | pass |

## Planned Changes

- registry repository: `mattpocock-skills`
- materialization: `local-submodule`
- reviewed source HEAD: `ed37663cc5fbef691ddfecd080dff42f7e7e350d`
- ADK absorption: not performed by repository registration
- external discovery/runtime writes: disabled

## Rollback

- `rtk scripts/plan-reference-repository-removal.sh . --repo mattpocock-skills --evidence-dependency-scan <report> --rollback-plan <report>`
- `rtk scripts/check-reference-repository-removal.sh .`

## Artifact Digests

- `analysis_report`: `fe057d8bfb314dc704796e4329b6bc5a64bdc6be4c94a3ede55368969006f7ce` (`reports/reference-analysis-mattpocock-skills-2026-07-22.md`)
- `candidate_ledger`: `2db0611a4d1d1c5f4190074ce2cfe421f498caa3a3a00daee4b7072f4aa13484` (`reports/external-practice-candidates-mattpocock-skills-2026-07-22.jsonl`)
- `decision_ledger`: `fb9067fe9927c913a5e7808f932b5b013b1d24a960da53432ce53ec9d8e1d658` (`reports/external-practice-decisions-mattpocock-skills-2026-07-22.jsonl`)
- `duplicate_check`: `4953eab6e8e9bdf7b53b94599b1c243b38914de0b13b323e57c2ccaf80ed09bf` (`reports/reference-duplicate-review-mattpocock-skills-2026-07-22.md`)
- `security_review`: `3bd4473fc36cb5540224dc19b937d3680786cba3322854d42d400053a1eb6d2f` (`reports/reference-security-review-mattpocock-skills-2026-07-22.md`)
