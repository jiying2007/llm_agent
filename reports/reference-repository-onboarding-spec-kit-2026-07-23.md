# Reference Repository Onboarding Plan

> schema: reference-repository-onboarding/v1
> status: planned
> mode: dry-run
> candidate: epc-2ab9c988520526e1e0e0
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

- registry repository: `spec-kit`
- materialization: `local-submodule`
- reviewed source HEAD: `ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`
- ADK absorption: not performed by repository registration
- external discovery/runtime writes: disabled

## Rollback

- `rtk scripts/plan-reference-repository-removal.sh . --repo spec-kit --evidence-dependency-scan <report> --rollback-plan <report>`
- `rtk scripts/check-reference-repository-removal.sh .`

## Artifact Digests

- `analysis_report`: `05b0a71f398b3ce2325b16503d40cf203c586b21733b0646b9743f96f2794976` (`reports/reference-analysis-spec-kit-2026-07-23.md`)
- `candidate_ledger`: `6653e7fffd0769866dcd254c3f7ca191ade64b207a78114de6c24dfd680f6e7c` (`reports/external-practice-candidates-spec-kit-2026-07-23.jsonl`)
- `decision_ledger`: `4c747c50dc11fd3c98c9dfe330ba40a96875caaa9348adc4d51cab70e5b39a7e` (`reports/external-practice-decisions-spec-kit-2026-07-23.jsonl`)
- `duplicate_check`: `f92d1b892e5d9b44b25272302cdff836a9e02e5d6740abbae2d2135b45fdd6f1` (`reports/reference-duplicate-review-spec-kit-2026-07-23.md`)
- `security_review`: `1931b9eb90a4f2fc87fb191391aca4c6d7dc67e5859acb7f20c491c9933c98c4` (`reports/reference-security-review-spec-kit-2026-07-23.md`)
