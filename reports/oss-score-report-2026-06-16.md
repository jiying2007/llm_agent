# OSS Score Report

> Status: report-only
> Source ledger: `reports/oss-discovery-candidates-2026-06-16.jsonl`

## Summary

- candidates: 3
- scored: 2
- unscored: 1
- discovered: 1
- onboard-candidate: 1
- watch: 1

## Candidates

| repo | domain_fit | score | decision | hard_rejects | reason |
|---|---|---:|---|---|---|
| example/runtime-policy-gates | runtime-policy | 93 | onboard-candidate |  | high relevance and verifiable runtime-policy gate examples; pending onboarding gates |
| example/workflow-kit | workflow-core | 84 | watch |  | high quality candidate but not enough uniqueness for automatic registration |
| example/tooling-agent | tooling |  | discovered |  | candidate created from search |

## Report-Only Boundary

- This report does not register repositories.
- This report does not update `.gitmodules`, `subrepos/registry.csv`, or `subrepos/adoption-matrix.md`.
- `onboard-candidate` means eligible for later gated onboarding review, not automatic registration.
