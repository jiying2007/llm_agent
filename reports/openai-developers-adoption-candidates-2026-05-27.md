# OpenAI Developers Adoption Candidates - 2026-05-27

## Purpose

This report records the 2026-05-27 review of official OpenAI Developers content that can further improve `llm_agent` and `agent-dev-kit`. It is an adoption triage artifact, not a runtime enablement request.

## Scope

- Target: `llm_agent` governance records and `agent-dev-kit` reference manifests.
- Non-goals: no API runner migration, no hosted tool enablement, no external MCP write action, no `~/.codex` live asset apply.
- Verification expectation: official source freshness records, adoption matrix entries, and JSON manifest checks must pass before these candidates can become stronger rules.

## Source Set

| ID | Official source | Retrieved | Decision |
|---|---|---:|---|
| openai-latest-model-gpt-5-5 | https://developers.openai.com/api/docs/models | 2026-05-27 | Observe as a volatile model-selection and freshness-gate reference. |
| openai-prompt-caching | https://developers.openai.com/api/docs/guides/prompt-caching | 2026-05-27 | Adopt prompt layout and cache-observability guidance. |
| openai-agents-orchestration-handoffs | https://developers.openai.com/api/docs/guides/agents/orchestration | 2026-05-27 | Adopt ownership vocabulary for handoff vs manager-style specialist calls. |
| openai-graders | https://developers.openai.com/api/docs/guides/graders | 2026-05-27 | Adopt grader taxonomy for deterministic ADK eval gates. |
| openai-prompt-optimization-golden-examples | https://developers.openai.com/cookbook/examples/optimize_prompts#4-using-evaluations-to-arrive-at-these-agents | 2026-05-27 | Adopt golden examples for prompt and skill-routing regression suites. |
| openai-codex-iterative-repair-loop | https://developers.openai.com/cookbook/examples/codex/build_iterative_repair_loops_with_codex | 2026-05-27 | Adopt Review -> Repair -> Validate as a closed-loop repair contract. |

## Candidate Decisions

| Priority | Candidate | Landing target | Status | Notes |
|---|---|---|---|---|
| P0 | Prompt-cache-friendly context layout | `agent-dev-kit/docs/runbooks/token-context-governance.md`, future context contracts | initial landing done | Keep stable rules, schemas and examples before dynamic task evidence; log cached-token metrics only for API-backed runners. |
| P1 | Orchestration ownership taxonomy | `agent-dev-kit/manifests/subagent_contracts.json`, parallel governance skill | initial landing done | Distinguish delegated ownership from manager-owned specialist calls before spawning or handing off work. |
| P1 | Golden-case evals for routing and prompt upgrades | `agent-dev-kit/manifests/eval_suites.json` | initial landing done | Add positive and negative examples before promoting new `AGENTS.md` or skill guidance. |
| P1 | Iterative repair loop contract | `agent-dev-kit/manifests/agent_improvement_loop_contracts.json` | initial landing done | Separate read-only review, focused repair, and validation feedback; do not claim closure without validation evidence. |
| P2 | Current model catalog freshness gate | `agent-dev-kit/manifests/official_docs_freshness_gates.json` | initial landing done | Keep current model guidance short-lived and source-bound; avoid hardcoding "latest" model claims in durable adk rules. |

## Adoption Constraints

- Official docs can justify a candidate only when `url`, `retrieved_at`, `expires_at`, `review_status`, and `adoption_scope` are present.
- Model recommendations are volatile; record them as freshness-gated references, not permanent defaults.
- Prompt caching guidance affects layout and observability, not behavioral correctness.
- Grader and golden-example adoption must include negative cases; otherwise routing evals will overfit to happy paths.
- Iterative repair loops must preserve read-only review before edit and validation after edit.

## Evidence Index

| Command / Source | Result | Evidence path | Layer | Related artifact |
|---|---|---|---|---|
| OpenAI Docs MCP search/fetch and official-domain fallback | Located and verified source set above | current Codex session | Reference | this report |
| `rtk sed -n '1,220p' agent-dev-kit/docs/reference/openai-developers-reference.md` | Existing OpenAI Developers adoption already covers 2026-05-25/26 baseline | terminal output | Reference | delta scoping |
| `rtk sed -n '1,220p' agent-dev-kit/manifests/eval_suites.json` | Existing eval suites need additional golden/repair-loop fixtures | terminal output | Manifest | eval-suite candidate |

## Next Landing Steps

1. Add the new official sources to the freshness manifest with 2026-05-27 retrieval metadata.
2. Extend `eval_suites.json` with golden-case and repair-loop fixtures.
3. Promote the matrix rows to `done` for this initial governance landing after the freshness manifest, eval suite and report validate.
4. Track deeper runbook/contract hardening in a follow-up implementation batch rather than leaving adoption-matrix rows pending.
