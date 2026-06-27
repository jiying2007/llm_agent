# Harness / Loop Failure Recovery Fixtures

Date: 2026-06-27
Status: implemented
Mode: clean-room negative fixtures

## Source Mapping

| Source family | Prior absorbed contract | Implemented as |
|---|---|---|
| durable execution / workflow systems | `durable-agent-loop-v1`, `durable-execution-contract-v1` | failure-state negative fixtures |
| coding repair / artifact lineage loops | `coding-repair-loop-v1`, `artifact-lineage-evidence-contract-v1` | done-state artifact lineage guard |

Source reports:

- `reports/harness-loop-engineering-adoption-candidates-2026-06-26.md`
- `reports/harness-loop-engineering-adoption-candidates-2026-06-26-batch2.md`

## Decision

Promote the next harness/loop improvement as executable negative fixtures, not prose. The change stays method-only and clean-room: no external benchmark, container, daemon, scheduler, MCP server or runtime is enabled.

## Implemented Assets

- `agent-dev-kit/fixtures/harness-loop-engineering/fail/retry-budget-exhausted-done.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/stale-heartbeat-done.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-artifact-lineage-done.json`
- `agent-dev-kit/manifests/harness_loop_engineering_contracts.json`
- `agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh`

## Behavior Covered

The new negative fixtures prevent invalid completion claims:

- `retry_budget` exhausted cannot enter `done`.
- `heartbeat_status: stale` cannot enter `done`.
- `coding_repair_loop` completion with `artifact_lineage_required: true` cannot enter `done` without `artifact_lineage_evidence`.

## Validation

Planned and executed validation:

- `rtk bash agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh`
- `rtk bash scripts/check-harness-loop-engineering.sh`
- `rtk git -C agent-dev-kit diff --check`

## Boundary

This is a contract-fixture hardening change only. It does not add a new skill, enable a runtime, change CI execution, install dependencies or alter any external repository.
