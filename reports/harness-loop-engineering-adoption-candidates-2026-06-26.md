# Harness / Loop Engineering Adoption Candidates: 2026-06-26

## Scope

This report extends the existing ADK harness / loop engineering absorption with current open-source repositories that fit ADK's method-only positioning. It does not onboard local subrepos, install dependencies, run external CLIs, start services, enable MCP servers, register hooks or adopt any external runtime.

Existing absorbed sources remain the baseline: Google ADK, LangGraph, SWE-bench, Inspect AI, promptfoo, OpenAI Agents SDK, OpenHands, SWE-agent, smolagents, DeepEval, Phoenix and lm-evaluation-harness.

## Source Inventory

| Priority | Source | URL | Read status | Decision | ADK target |
|---|---|---|---|---|---|
| P0 | Temporal | https://github.com/temporalio/temporal | browser-verified repository summary | adopt-method-only | durable execution contract |
| P0 | PydanticAI | https://github.com/pydantic/pydantic-ai | browser-verified repository summary | adopt-method-only | typed HITL graph contract |
| P0 | Langfuse | https://github.com/langfuse/langfuse | browser-verified repository summary | adopt-method-only | trace/eval evidence bundle |
| P0 | Aider | https://github.com/Aider-AI/aider | browser-verified repository summary | adopt-method-only | coding repair loop contract |
| P0 | Mastra | https://github.com/mastra-ai/mastra | browser-verified repository summary | adopt-method-only | workflow graph and HITL resume boundary |
| P1 | Semantic Kernel | https://github.com/microsoft/semantic-kernel | browser-verified repository summary | observe-method-only | process/plugin vocabulary |
| P1 | Haystack | https://github.com/deepset-ai/haystack | browser-verified repository summary | observe-method-only | context pipeline boundary |
| P1 | Ragas | https://github.com/vibrantlabsai/ragas | browser-verified repository summary | observe-method-only | evaluation metric vocabulary |
| P1 | CrewAI | https://github.com/crewAIInc/crewAI | browser-verified repository summary | observe-method-only | crews/flows boundary vocabulary |
| P2 | Continue | https://github.com/continuedev/continue | browser-verified repository summary | historical-reference-only | coding context and IDE boundary only |

## Adoption Decisions

| Candidate | Decision | Reason | Rejected surface |
|---|---|---|---|
| Durable execution semantics | adopt | Temporal-style replay, activity boundary, retry, timeout, cancellation and idempotency make ADK loop claims more testable. | Temporal server, worker process, workflow SDK runtime |
| Typed HITL graph | adopt | PydanticAI and Mastra reinforce typed inputs/outputs, approval records, state storage and resume points for human-gated agent flows. | Python/TypeScript runtime, graph executor, studio UI |
| Trace/eval evidence bundle | adopt | Langfuse-style traces, datasets, prompt versions, scores and regression links strengthen ADK completion and routing gates. | Langfuse service, database, telemetry, hosted UI |
| Coding repair loop | adopt | Aider-style repo map, scoped patch, lint/test observation and retry budget improve coding-agent-loop evidence. | Auto-commit defaults, model runtime, voice/web inputs |
| Context pipeline boundary | adapt | Haystack's explicit retrieval/routing/memory/generation pipeline is useful vocabulary for context harnesses. | RAG framework import, serving wrappers |
| Crews/flows separation | adapt | CrewAI's autonomy-vs-control split maps to ADK worker/flow ownership. | Cloud control plane, project scaffolding, package install |
| Legacy or maintenance-mode frameworks | archive-only | AutoGen and Continue remain useful historically but should not become new active ADK dependencies. | Long-term local tracking |

## Implemented ADK Contracts

| Contract | Purpose | Source refs |
|---|---|---|
| `durable-execution-contract-v1` | Require replay, activity boundary, retry/timeout/cancel and idempotency evidence before claiming durable loops. | Temporal, PydanticAI, LangGraph |
| `typed-hitl-graph-contract-v1` | Require typed node I/O, dependency context, approval request, decision record and resume point. | PydanticAI, Mastra, LangGraph |
| `coding-repair-loop-v1` | Require repo-map evidence, scoped edit, lint/test commands, failure observation, retry budget, git diff review and rollback path. | Aider, SWE-agent, OpenHands, SWE-bench |
| `trace-eval-evidence-bundle-v1` | Require trace, dataset, prompt version, eval run, score schema, threshold, redaction and regression link. | Langfuse, Phoenix, promptfoo, DeepEval, Ragas |

## Guardrails

- All new sources are `runtime_enabled=false`.
- External code requires supply-chain review before any execution.
- Container, daemon, service, UI, hook, MCP server and package install surfaces remain rejected by default.
- This pass only extends contracts and validation. It does not add local reference subrepos.

## Validation Targets

```bash
rtk agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh
rtk agent-dev-kit/scripts/devkit.sh harness-loop-engineering
rtk scripts/check-harness-loop-engineering.sh .
rtk scripts/check-adoption-matrix-structured.sh .
```
