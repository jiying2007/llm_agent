# OSS Onboarding Plan: example/runtime-policy-gates

> Status: dry-run
> Candidate: `example/runtime-policy-gates`

## Gates

| gate | result |
|---|---|
| candidate_score_gate | pass |
| hard_reject_gate | pass |
| analysis_report_gate | pass |
| duplicate_check_gate | pass |
| security_review_gate | pass |
| phase_gate | pass |
| registry_conflict_gate | pass |
| target_path_gate | pass |
| materialization_gate | pass |
| rollback_plan_gate | pass |

## Planned Changes

- registry: `subrepos/registry.csv` row for `runtime-policy-gates`
- submodule path: `runtime-policy-gates`
- materialization: `metadata-only`
- adoption matrix: `observe/pending` row with evidence `reports/oss-onboarding-plan-example-runtime-policy-gates-2026-06-16.md`
- ADK absorption: not performed in P2 registration

## Rollback

- `rtk git submodule deinit -f runtime-policy-gates`
- `rtk git rm -f runtime-policy-gates`
