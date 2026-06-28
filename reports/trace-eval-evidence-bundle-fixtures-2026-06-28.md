# Trace / Eval Evidence Bundle Fixtures

Date: 2026-06-28
Status: implemented
Mode: clean-room negative fixtures

## Source Mapping

| Source family | Prior absorbed contract | Implemented as |
|---|---|---|
| trace / eval observability systems | `trace-eval-evidence-bundle-v1` | promotion evidence negative fixtures |
| eval regression and prompt governance | `trace-eval-evidence-bundle-v1` | dataset, prompt version and regression link guards |

Source reports:

- `reports/harness-loop-engineering-adoption-candidates-2026-06-26.md`
- `reports/harness-loop-engineering-adoption-candidates-2026-06-26-batch2.md`

## Decision

Promote the trace/eval improvement as executable negative fixtures, not prose. The change stays method-only and clean-room: no external eval service, trace store, benchmark, daemon, scheduler, MCP server or runtime is enabled.

## Implemented Assets

- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-trace-eval-dataset-id.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-trace-eval-prompt-version.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-trace-eval-regression-link.json`
- `agent-dev-kit/manifests/harness_loop_engineering_contracts.json`
- `agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh`

## Behavior Covered

The new negative fixtures prevent incomplete promotion evidence:

- A trace/eval bundle without `dataset_id` cannot satisfy the contract.
- A trace/eval bundle without `prompt_version` cannot satisfy the contract.
- A trace/eval bundle without `regression_link` cannot satisfy the contract.
- Promotion-shaped fixtures (`promotion_candidate: true` or `decision.status: promote`) are explicitly checked for dataset, prompt version and regression link evidence.

## Validation

Planned validation:

- `rtk bash agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh`
- `rtk bash scripts/check-harness-loop-engineering.sh .`
- `rtk git -C agent-dev-kit diff --check`
- `rtk bash scripts/check-adoption-matrix-structured.sh .`
- `rtk bash scripts/check-adoption-evidence-integrity.sh .`

## Boundary

This is a contract-fixture hardening change only. It does not add a new skill, enable a runtime, change CI execution, install dependencies, store production traces or alter any external repository.
