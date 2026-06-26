# Harness / Loop Engineering Adoption Candidates: 2026-06-26 Batch 2

## Scope

This report extends ADK harness / loop engineering absorption with terminal task benchmarks, sandbox execution boundaries, reproducible pipeline systems and artifact lineage practices. It is method-only and keeps `runtime_enabled=false` for every external source.

This pass does not clone repositories, install packages, run benchmark containers, start services, enable Kubernetes controllers, register hooks, enable MCP servers or copy runtime assets.

## Source Inventory

| Priority | Source id | Source | URL | Decision | ADK target |
|---|---|---|---|---|---|
| P0 | inspect-evals | Inspect Evals | https://github.com/UKGovernmentBEIS/inspect_evals | adopt-method-only | agent-eval-ci-gate-v1, trace-eval-evidence-bundle-v1 |
| P0 | terminal-bench | Terminal-Bench | https://github.com/laude-institute/terminal-bench | adopt-method-only | sandbox-terminal-harness-v1 |
| P0 | mini-swe-agent | mini-swe-agent | https://github.com/SWE-agent/mini-swe-agent | adopt-method-only | coding-agent-loop-v1, coding-repair-loop-v1, sandbox-boundary-contract-v1 |
| P0 | swe-rex | SWE-ReX | https://github.com/SWE-bench/SWE-ReX | adopt-method-only | sandbox-boundary-contract-v1, sandbox-terminal-harness-v1 |
| P0 | dagger | Dagger | https://github.com/dagger/dagger | adopt-method-only | reproducible-execution-pipeline-v1, artifact-lineage-evidence-contract-v1 |
| P0 | argo-workflows | Argo Workflows | https://github.com/argoproj/argo-workflows | adopt-method-only | reproducible-execution-pipeline-v1, workflow-state-contract-v1 |
| P1 | tau-bench | tau-bench | https://github.com/sierra-research/tau-bench | observe-method-only | agent-eval-ci-gate-v1 |
| P1 | agentbench | AgentBench | https://github.com/THUDM/AgentBench | observe-method-only | repo-task-evaluation-harness-v1 |
| P1 | webarena | WebArena | https://github.com/web-arena-x/webarena | observe-method-only | sandbox-boundary-contract-v1 |
| P1 | osworld | OSWorld | https://github.com/xlang-ai/OSWorld | observe-method-only | sandbox-boundary-contract-v1 |
| P1 | openai-evals | OpenAI Evals | https://github.com/openai/evals | observe-method-only | model-eval-harness-v1, agent-eval-ci-gate-v1 |
| P2 | simple-evals | simple-evals | https://github.com/openai/simple-evals | historical-reference-only | model-eval-harness-v1 |
| P1 | prefect | Prefect | https://github.com/PrefectHQ/prefect | observe-method-only | durable-execution-contract-v1, workflow-state-contract-v1 |
| P1 | dagster | Dagster | https://github.com/dagster-io/dagster | observe-method-only | artifact-lineage-evidence-contract-v1, reproducible-execution-pipeline-v1 |

## Adoption Decisions

| Candidate | Decision | Reason | Rejected surface |
|---|---|---|---|
| Sandbox terminal harness | adopt | terminal-bench and SWE-ReX make terminal tasks reviewable through explicit instruction, setup, agent command, test script, oracle, timeout, resource budget and cleanup policy. | Running arbitrary benchmark containers, privileged shell, host path writes |
| Minimal coding loop | adopt | mini-swe-agent reinforces small, auditable coding loops with independent process actions, captured stdout/stderr, patch artifacts and bounded repair attempts. | Importing agent runtime, automatic commit, network-open execution |
| Reproducible execution pipeline | adopt | Dagger, Argo Workflows, Prefect and Dagster provide useful local/CI parity, DAG/step graph, artifact input/output, retry, schedule and archive vocabulary. | Container engine adoption, Kubernetes controller, daemon, cloud service |
| Artifact lineage evidence | adopt | Dagger and Dagster strengthen artifact provenance with producer step, consumer step, digest, metadata schema, quality check, retention and supersedes fields. | Hosted control plane, unversioned artifact stores |
| Tool-user / web / desktop agent benchmarks | observe | tau-bench, AgentBench, WebArena and OSWorld are valuable for future eval shapes but have domain/runtime complexity. | Browser/desktop automation runtime, synthetic service stack |
| General model eval baselines | observe | openai-evals and simple-evals remain useful as compact reference shapes for task registry, dataset version and result schema. | Replacing ADK eval registry or importing eval runtime |

## Implemented ADK Contracts

| Contract | Purpose | Source refs |
|---|---|---|
| `sandbox-terminal-harness-v1` | Require task instruction, sandbox backend, setup command, agent command, test script, oracle solution, timeout policy, resource budget, stdout/stderr capture, exit code policy, cleanup policy and dataset version before terminal task execution is claimed reproducible. | terminal-bench, swe-rex, mini-swe-agent |
| `reproducible-execution-pipeline-v1` | Require pipeline id, local_ci_parity, container/runtime spec, DAG or step graph, artifact inputs, artifact outputs, cache policy, trace export policy, schedule policy, retry policy, archive policy and rollback path. | dagger, argo-workflows, prefect, dagster |
| `artifact-lineage-evidence-contract-v1` | Require artifact id, source input, producer step, consumer step, version or digest, materialization time, metadata schema, quality check, retention policy, supersedes and evidence path. | dagger, dagster, argo-workflows, inspect-evals |

## Local Fixture Landing

The second landing pass adds `agent-dev-kit/fixtures/harness-loop-engineering/pass/local-fixture-bundle.json` as a clean-room local fixture. It covers `sandbox-terminal-harness-v1`, `reproducible-execution-pipeline-v1` and `artifact-lineage-evidence-contract-v1` without executing external benchmark, container, daemon, service, scheduler or GUI runtime.

The ADK contract gate now checks this fixture from `agent-dev-kit/manifests/harness_loop_engineering_contracts.json`; the fixture must keep `runtime_enabled=false`, `fixture_mode=method-only`, and all required fields for the three covered contracts.

The third landing pass adds three negative fixtures:

- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-oracle-solution.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-local-ci-parity.json`
- `agent-dev-kit/fixtures/harness-loop-engineering/fail/missing-version-or-digest.json`

The gate now reads `negative_fixtures` from the manifest and requires each fail fixture to be rejected with its expected failure reason. This proves the three contracts block missing `oracle_solution`, missing `local_ci_parity`, and missing `version_or_digest`.

## Guardrails

- Every source remains `method-only` with `runtime_enabled=false`.
- `sandbox` execution claims require a declared test script, `oracle`, timeout, resource budget, stdout/stderr capture, exit code policy and cleanup policy.
- Pipeline adoption requires `local_ci_parity`, artifact input/output declaration, trace export, retry, archive and rollback fields before any promotion.
- Artifact `lineage` requires digest or version, producer/consumer steps, metadata schema, quality check, retention and supersedes records.
- Trace, dataset, artifact and terminal outputs require `redaction` before long-term storage.

## Validation Targets

```bash
rtk bash agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh
rtk bash scripts/check-harness-loop-engineering.sh .
rtk scripts/check-adoption-matrix-structured.sh .
rtk scripts/check-adoption-evidence-integrity.sh .
rtk scripts/check-all.sh --quick
```
