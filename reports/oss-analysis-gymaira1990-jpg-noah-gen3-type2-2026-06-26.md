# OSS Analysis: gymaira1990-jpg/noah-gen3-type2

> Status: analyzed, report-only
> Date: 2026-06-26
> Source URL: https://github.com/gymaira1990-jpg/noah-gen3-type2
> Local quarantine path: `scratch/oss-intake/noah-gen3-type2`
> Local commit: `f05f130c73f75980bc3a50757c5974a4f1656dad`
> Read status: cloned for read-only analysis; no dependencies installed; no code executed

## Source Summary

`noah-gen3-type2` is a Chinese AI-agent practice repository centered on context management, long-term memory, tool routing, and a model-management panel. The top-level README presents six subprojects:

- `01-上下文管理组装系统`: drawer-style cascade context compression, noise filtering, protected memory, deduplication, and context assembly.
- `02-Mnemosyne-记忆宫殿`: now split out to `Mnemosyne-OS`.
- `03-认知AI底座`: architecture proposal stage.
- `04-原铸诺亚-二代一型`: historical production instance, explicitly marked as reference-only by upstream.
- `05-工具集`: browser/CDP and tool CLI ideas.
- `06-诺亚核心-模型管理与对话面板`: model registry, OpenAI-compatible chat, FastAPI panel, DeepSeek-specific adapters.

Observed local scale: 201 files.

## Reusable Claims

| Claim | Local applicability | Evidence strength | Notes |
|---|---|---|---|
| Drawer-style incremental summarization avoids cliff-style whole-context compression. | Medium | Medium | Relevant to `adk-token-context-governance` and context handoff, but ADK already has raw evidence fallback and layered reading rules. |
| Noise filtering and protected-entry detection should be deterministic before any LLM summarization. | High | Medium | Compatible with current memory governance; should be considered only as a future fixture or eval case, not a new resident memory rule. |
| Unique keys for plans, progress, decisions, corrections, and execution logs reduce duplicate memory injection. | High | Medium | Similar to ADK's memory candidate `ADD/UPDATE/DELETE/NONE` decision model; potential future improvement is test fixtures for key collision and correction retention. |
| Context assembly should combine goal, active summaries, hot memories, project state, retrieval results, and execution logs under a budget. | High | Medium | Already substantially covered by `agent-dev-kit/docs/runbooks/token-context-governance.md`. |
| Unified model management panel is useful for agent runtime operations. | Low | Low | Outside current llm_agent absorption target; security and runtime surface are too broad for direct adoption. |

## Risks

- No standalone `LICENSE` file was found in the clone, although README text claims MIT.
- Historical runtime code includes suspected hardcoded API keys and default admin passwords. These were not copied into this report.
- Several subprojects require remote model providers, local servers, service setup, or installation steps. None were executed.
- The repo mixes current reusable ideas with a historical "already exploded" instance. Direct source import would create architecture drift.
- Existing ADK assets already cover most context/memory governance concepts at the policy level.

## Fit Assessment

| Dimension | Assessment |
|---|---|
| Domain fit | Knowledge and runtime-policy reference, not embedded-fullstack core. |
| Maintenance | Recent commit observed on 2026-06-25 from local clone metadata. |
| Engineering quality | Mixed: useful docs and some tests in the context module, but historical runtime includes unsafe examples. |
| Security / supply chain | Report-only only; no install, no execution, no code copy. |
| Uniqueness | Medium for drawer-cascade terminology and deterministic protection signals; low for broader memory governance already present in ADK. |

## Decision

Decision: `ARCHIVE_ONLY` with selective future `ADAPT` candidates.

Rationale:

- The best material is conceptual and overlaps existing ADK context and memory governance.
- Direct onboarding or ADK core absorption is blocked by license-file absence, suspected secrets in historical code, and broad runtime surface.
- Useful ideas should be converted later into small fixtures or eval cases only if they improve an existing ADK gate.

## Candidate Follow-ups

1. Add fixture cases for context compression collision handling: correction, decision, progress, and execution-log entries with stable keys.
2. Extend memory governance examples with deterministic pre-LLM filtering signals, if current tests miss that behavior.
3. Keep model-management panel as reference-only unless a separate runtime security review is requested.
