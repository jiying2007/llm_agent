# OpenAI Developers Adoption Candidates - 2026-05-27 Batch 2

## Purpose

This batch converts additional official OpenAI Developers guidance into ADK governance candidates. It focuses on instruction hierarchy, model optimization discipline, guardrail regression data, stored-completion monitoring, and model-selection decision records.

## Scope

- Target: `agent-dev-kit` official-doc manifests, eval contracts, context contracts, trace contracts, and adoption matrix records.
- Non-goals: no API runner implementation, no production logging enablement, no hosted eval run, no fine-tuning, no external guardrail service activation.

## Source Set

| ID | Official source | Retrieved | Decision |
|---|---|---:|---|
| openai-model-optimization-workflow | https://developers.openai.com/api/docs/guides/model-optimization#model-optimization-workflow | 2026-05-27 | Adopt eval-baseline-first improvement loop. |
| openai-prompt-engineering-roles | https://developers.openai.com/api/docs/guides/prompt-engineering#message-roles-and-instruction-following | 2026-05-27 | Adopt developer/user/context/tool-output authority boundaries. |
| openai-prompt-engineering-formatting | https://developers.openai.com/api/docs/guides/prompt-engineering#message-formatting-with-markdown-and-xml | 2026-05-27 | Adopt structured prompt sections and explicit context boundaries. |
| openai-stored-completion-monitoring | https://developers.openai.com/cookbook/examples/evaluation/use-cases/completion-monitoring | 2026-05-27 | Adopt as a watch/reference pattern for sanitized session-derived regression monitoring. |
| openai-agentic-governance-test-dataset | https://developers.openai.com/cookbook/examples/partners/agentic_governance_guide/agentic_governance_cookbook#step-2-create-a-test-dataset | 2026-05-27 | Adopt positive/negative guardrail regression datasets. |
| openai-eval-driven-system-design | https://developers.openai.com/cookbook/examples/partners/eval_driven_system_design/receipt_inspection#further-improvements | 2026-05-27 | Adopt improvement ladder: model, prompt, examples/context, tools, accessory models, fine-tuning. |
| openai-model-selection-guide | https://developers.openai.com/cookbook/examples/partners/model_selection_guide/model_selection_guide | 2026-05-27 | Adopt KPI/SLO, cost, latency, version pinning, A/B and rollback records. |
| openai-ai-native-engineering-team-docs | https://developers.openai.com/codex/guides/build-ai-native-engineering-team#how-coding-agents-help-5 | 2026-05-27 | Adopt documentation freshness as a delivery pipeline artifact. |

## Candidate Decisions

| Priority | Candidate | Landing target | Status |
|---|---|---|---|
| P0 | Instruction hierarchy and context boundary contract | `context_state_contracts.json` | initial landing done |
| P0 | Eval-baseline-first optimization loop | `agent_improvement_loop_contracts.json`, `eval_suites.json` | initial landing done |
| P1 | Guardrail regression positive/negative dataset | `eval_suites.json` | initial landing done |
| P1 | Stored-completion/session monitoring contract | `trace_eval_contracts.json`, `eval_suites.json` | initial landing done |
| P1 | Model selection decision records | `model_selection_decision_records.json` | initial landing done |
| P1 | Documentation freshness in delivery pipeline | `openai-developers-reference.md` and adoption matrix | initial landing done |

## Adoption Constraints

- Instruction hierarchy must not demote higher-priority local policy into dynamic context.
- Stored-completion style monitoring is reference-only until data retention, redaction, and owner approval are explicit.
- Prompt/model optimization must begin with an eval baseline and representative data; fine-tuning remains out of scope unless separately approved.
- Guardrail datasets need positive and negative examples, adversarial cases, and borderline legitimate cases.
- Model selection decisions must record measurable KPI/SLO targets, cost/latency tradeoffs, version pinning, A/B criteria, and rollback path.

## Evidence Index

| Command / Source | Result | Evidence path | Layer | Related artifact |
|---|---|---|---|---|
| OpenAI Docs MCP search/fetch | Located official source set and exact sections where available | current Codex session | Reference | this report |
| `rtk sed -n '1,240p' agent-dev-kit/manifests/context_state_contracts.json` | Existing context contracts had no dedicated instruction hierarchy contract | terminal output | Manifest | context update |
| `rtk sed -n '1,280p' agent-dev-kit/manifests/eval_suites.json` | Existing eval suites had routing/completion/macro coverage but no guardrail or stored-session regression suites | terminal output | Manifest | eval update |

## Next Steps

1. Keep these entries as initial governance landing until real fixtures are added under `tests/fixtures/`.
2. For future API-backed pilots, wire stored-output monitoring only after retention and redaction policy is approved.
3. Promote model-selection decision records into release gates only after at least one local pilot produces comparable KPI/SLO evidence.
