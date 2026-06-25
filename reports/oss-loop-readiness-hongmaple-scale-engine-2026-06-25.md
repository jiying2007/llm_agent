# OSS Loop Readiness Absorption: hongmaple/scale-engine

> Date: 2026-06-25
> Source: `https://gitee.com/hongmaple/scale-engine`
> Local path: `scale-engine/`
> Snapshot commit: `60f38279b76030056738cc9eac7bc8b9cc6173c2`
> Status: adapted, report-only, runtime-disabled

## Scope

This report turns useful harness and loop ideas from `scale-engine` into local, auditable `llm_agent` controls. It does not enable or run the upstream runtime.

## Source Inventory

| Source | Read status | Absorption use |
|---|---|---|
| `scale-engine/src/context/SessionStartSequence.ts` | direct local read | session preflight inputs: git state, recent commits, unfinished tasks, recommendations |
| `scale-engine/src/workflow/DiagnosticLoop.ts` | direct local read | debugging loop contract: reproduction, expected failure, falsifiable hypotheses, instrumentation cleanup, verification |
| `scale-engine/src/workflow/AgentLoopReadiness.ts` | direct local read | loop readiness metrics: tool evidence, recovery, guardrails, budget, handoff, termination |
| `scale-engine/src/workflow/TddLoop.ts` | direct local read | TDD slice shape: behavior, failing test, green evidence, refactor boundary |
| `scale-engine/docs/WORKFLOW_EVAL.md` | direct local read | failure replay and workflow effectiveness metrics |
| `scale-engine/docs/ORCHESTRATOR.md` | direct local read | reconciliation loop vocabulary and runtime risk boundary |
| `scale-engine/docs/CORTEX.md` | direct local read | cross-harness adapter concept and confidence ladder boundary |

## Absorption Decisions

| Candidate | Decision | Local landing | Boundary |
|---|---|---|---|
| Session start harness context | adapt | use as checklist input for session/final readiness, not as automatic context injection | no upstream hook or SessionStart injection |
| Diagnostic loop contract | adopt | `manifests/loop_readiness_contracts.json` requires reproduction, expected failure, 3+ falsifiable hypotheses, cleanup, verification | no upstream TypeScript runner |
| TDD loop slice shape | adapt | keep as optional loop dimension for future ADK test strategy mapping | no new TDD runner |
| Agent loop readiness metrics | adopt | local readiness dimensions: tool execution, recovery, guardrails, budget, handoff, termination | local evidence only |
| Workflow eval failure replay | adapt | report-only future metric; failures may become reviewed incident candidates after repeated local misses | no eval daemon or memory auto-promotion |
| Reconciliation loop vocabulary | adapt | `poll/filter/isolate/dispatch/reconcile/notify` may describe future runbooks | no daemon, tracker polling, worktree dispatch |
| Cortex adapter schema | archive-only | retain for future multi-harness adapter contract review | no hook adapter, no automatic memory injection |
| Shield/hook policy compiler | reject | runtime patching of harness settings is outside current trust boundary | keep disabled |

## Local Loop Readiness Contract

The local contract keeps six measurable signals from `AgentLoopReadiness` and maps them to existing `llm_agent` evidence:

| Metric | Local question | Current evidence class |
|---|---|---|
| `tool_execution_evidence` | Did the loop record real command/tool evidence instead of a narrative-only claim? | check scripts, reports, command evidence |
| `loop_recovery_evidence` | If a step failed or was blocked, is there a repair/retry/escalation record? | diagnostic report, closeout, adoption matrix state |
| `guardrail_coverage` | Are destructive, runtime, supply-chain, and completion gates explicit? | lifecycle runtime boundaries, security review, final-ready/check-all |
| `budget_control_evidence` | Is context/token/runtime scope bounded before execution? | context governance, report-only mode, no external runtime execution |
| `handoff_or_delegation_evidence` | Is responsibility visible when work crosses agent, subrepo, or review boundary? | owner/review window, approval queue, subagent contracts |
| `termination_evidence` | Is there a clear stop condition and validation before declaring done? | verification commands, check results, blocked conditions |

## Concrete Local Assets

| Asset | Purpose |
|---|---|
| `manifests/loop_readiness_contracts.json` | Report-only loop readiness contract and scale-engine mapping |
| `scripts/check-loop-readiness.sh` | Offline validation that the contract, report, lifecycle evidence, and adoption matrix stay linked |
| `subrepos/adoption-matrix.md` | Records the scale-engine harness/loop readiness model as an adopted, done item |
| `manifests/subrepo_lifecycle.json` | Links this report to the root-local reference evidence chain |

## Runtime Boundaries

The following remain explicitly disabled:

- Running `npm`, `npx`, `scale`, setup, bootstrap, dashboard, MCP, hook, shield, cortex, eval, or orchestrator commands from `scale-engine`.
- Copying `.scale/`, `.claude/`, hook settings, role skills, MCP config, CLI adapters, or upstream runtime state into ADK or `~/.codex`.
- Starting daemon loops, polling trackers, creating upstream-managed worktrees, or auto-promoting failure replay into memory or standards.

## Validation

Minimum validation for this absorption:

```bash
rtk scripts/check-loop-readiness.sh .
rtk scripts/check-doc-sync.sh .
rtk scripts/check-oss-intake-ledger.sh . --summary-json
rtk scripts/check-all.sh --quick
rtk git diff --check
```
