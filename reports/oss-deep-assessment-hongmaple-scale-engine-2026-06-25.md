# OSS Deep Assessment: hongmaple/scale-engine

> Date: 2026-06-25
> Source: `https://gitee.com/hongmaple/scale-engine`
> Local path: `scale-engine/`
> Snapshot commit: `60f38279b76030056738cc9eac7bc8b9cc6173c2`
> Status: deep-evaluated, observe-first, runtime-disabled

## Read Inventory

| Source | Read status | Assessment use |
|---|---|---|
| `scale-engine/README.md` | direct local read | product scope, capability map, install/runtime surface |
| `scale-engine/package.json` | direct local read | executable commands, dependencies, release gates, Node runtime surface |
| `scale-engine/docs/00-OVERVIEW.md` | direct local read | layered architecture and problem framing |
| `scale-engine/docs/01-ARCHITECTURE.md` | direct local read | Shield, Orchestrator, Cortex boundaries |
| `scale-engine/docs/02-DATA-MODEL.md` | direct local read | Artifact/Event/FSM model |
| `scale-engine/docs/03-CORE-MODULES.md` | direct local read | EventBus, Artifact store, TaskEngine, FSM mechanics |
| `scale-engine/docs/CONTEXT_BUDGET.md` | direct local read | context budget and progressive governance comparison |
| `scale-engine/docs/RESOURCE_GOVERNANCE.md` | direct local read | resource type and Git policy model |
| `scale-engine/docs/UPGRADE_MANAGEMENT.md` | direct local read | check-plan-apply upgrade boundary |
| `scale-engine/docs/TOOL_ORCHESTRATION.md` | direct local read | required/recommended tool evidence and fallback model |
| `scale-engine/docs/WORKFLOW_EVAL.md` | direct local read | eval harness, failure replay and metrics |
| `scale-engine/docs/RUNTIME_EVIDENCE.md` | direct local read | runtime evidence discipline |
| `scale-engine/docs/SHIELD.md` | direct local read | hook protocol and destructive action blocking |
| `scale-engine/docs/ORCHESTRATOR.md` | direct local read | daemon, tracker, worktree isolation risks |
| `scale-engine/docs/CORTEX.md` | direct local read | evidence-driven learning and confidence ladder |
| `scale-engine/docs/RELEASE_READINESS.md` | direct local read | release gate and real-project validation model |
| `scale-engine/src/context/SessionStartSequence.ts` | direct local read | harness start context and preflight inputs |
| `scale-engine/src/workflow/DiagnosticLoop.ts` | direct local read | diagnostic loop contract |
| `scale-engine/src/workflow/AgentLoopReadiness.ts` | direct local read | loop readiness metrics |
| `scale-engine/src/workflow/TddLoop.ts` | direct local read | TDD slice loop shape |

## Capability Map

| Area | Scale-engine mechanism | Local overlap | Decision |
|---|---|---|---|
| Runtime evidence | Explicit command/tool/session evidence and final-check discipline | `final-ready`, `check-all`, evidence bundle, lifecycle evidence | adapt |
| Root reference provenance | Source URL, local clone, commit and boundary evidence | `subrepo_lifecycle.json`, `check-oss-intake-ledger.sh` | adopt |
| Workflow eval | Eval suite, failure replay, pass/fix metrics | Existing ADK eval manifests and llm_agent gates | archive-only for now |
| Context budget | Category-based context loading and compiler metadata | `adk-token-context-governance`, `check-token-budget.sh` | archive-only |
| Artifact/Event/FSM | Artifact graph, append-only event truth, status transitions | Adoption matrix and lifecycle states are simpler but sufficient | adapt conceptually |
| Shield hooks | Exit-code hook blocking and protected path policy | Local RTK and permission profile already provide command boundary | reject runtime |
| Orchestrator daemon | Tracker polling, worktree isolation, autonomous dispatch | Local multi-agent/worktree governance exists, but daemon writes are high-risk | reject runtime |
| Cortex learning | Failure pattern extraction, confidence ladder, session injection | Memory candidates and AAR already cover reviewed promotion | archive-only |
| Release readiness | One release gate plus demo and real-project validation | `check-all --quick`, source-to-live gates | adapt selectively |

## Absorption Decisions

| Candidate | Decision | Reason | Local landing |
|---|---|---|---|
| Root-local reference evidence card | adopt | Root-level local clones are not represented by `.gitmodules`, so provenance must be structured and checked | `manifests/subrepo_lifecycle.json`; `scripts/check-oss-intake-ledger.sh` |
| Deep assessment evidence requirement | adopt | A long-lived reference repo should not remain active with only shallow discovery/security reports | `scripts/check-oss-intake-ledger.sh`; this report |
| Runtime Evidence final-check model | adapt | Local completion already has `final-ready` and `check-all`; useful addition is stronger source/evidence metadata, not a new runtime store | lifecycle source/runtime boundaries |
| Workflow Eval failure replay | archive-only | Valuable, but adding a local eval runner would duplicate ADK eval manifests without a concrete local suite | future candidate after repeated failures |
| Harness/loop readiness contract | adapt | DiagnosticLoop and AgentLoopReadiness improve local evidence discipline without requiring upstream runtime execution | `reports/oss-loop-readiness-hongmaple-scale-engine-2026-06-25.md`; `manifests/loop_readiness_contracts.json`; `scripts/check-loop-readiness.sh` |
| Progressive governance/resource lifecycle contract | adapt | Risk-mode escalation and resource Git policy improve local governance without `.scale/` runtime state | `reports/oss-governance-contracts-hongmaple-scale-engine-2026-06-25.md`; `manifests/scale_engine_governance_contracts.json`; `scripts/check-scale-engine-governance.sh` |
| Context compiler metadata | archive-only | Already covered by token context governance; no extra manifest needed now | no change |
| Shield hook installation | reject | Hooks modify tool runtime and can block commands; needs separate security review and user opt-in | keep disabled |
| Orchestrator daemon | reject | Polling trackers, creating worktrees and dispatching agents are external write operations | keep disabled |
| Cortex session injection | reject for runtime, archive-only for method | Automatic memory injection can pollute context if not reviewed | no runtime injection |

## Implemented Absorption

This deep assessment promotes one narrow practice: active root-local references must have structured provenance and deep-evaluation evidence.

Required evidence for `materialization: root-local-reference`:

- `source.url`
- `source.provider`
- `source.branch`
- `source.commit`
- `source.retrieved_at`
- `runtime_boundaries`
- analysis report
- absorption plan
- security review
- deep assessment report
- local Git `HEAD` matching `source.commit`

## Rejected Runtime Surfaces

The following remain explicitly disabled:

- `npm`, `npx`, `scale`, setup, bootstrap, dashboard, MCP, hooks and orchestrator commands from `scale-engine`.
- Copying `.scale/`, `.claude/`, hooks, CLI adapters, role skills or MCP configuration into ADK or `~/.codex`.
- Running a daemon, installing package dependencies, opening local ports or writing external tracker/worktree state from `scale-engine`.

## Follow-Up Candidates

| Candidate | Entry condition |
|---|---|
| Failure replay schema for llm_agent intake | At least two real intake mistakes recur and current reports cannot explain prevention; current loop readiness contract keeps only report-only fields |
| Eval suite for OSS absorption quality | Adoption decisions start changing based on repeated false positives or missed risk |
| Release-readiness style demo gate | A local tool is promoted from report-only to actual runtime entry |

## Validation Plan

Minimum gates for this assessment:

```bash
rtk scripts/check-oss-intake-ledger.sh . --summary-json
rtk scripts/check-authorized-subrepos.sh .
rtk scripts/check-subrepo-state.sh .
rtk scripts/check-doc-sync.sh .
rtk scripts/check-all.sh --quick
rtk git diff --check
```
