# OpenAI Developers Runtime Capability Candidates - 2026-06-15

## Scope

This report records official OpenAI Developers content that can be converted into stronger ADK runtime capability. The goal is not to copy product behavior into ADK, but to turn stable Codex runtime concepts into platform-neutral governance contracts, manifests and deterministic checks.

## Official Sources

| Source ID | URL | Runtime Capability |
|---|---|---|
| openai-codex-config-reference | https://developers.openai.com/codex/config-reference#configtoml | Project-local config boundary, non-overridable runtime keys, MCP runtime options and subagent limits |
| openai-codex-permissions | https://developers.openai.com/codex/permissions | Permission profile, approval behavior and least-privilege runtime boundary |
| openai-codex-memories | https://developers.openai.com/codex/memories | Opt-in memory runtime, external-context review and raw-evidence fallback |
| openai-codex-subagents-runtime | https://developers.openai.com/codex/subagents | Delegated-agent depth, thread and runtime-limit governance |
| openai-codex-glossary | https://developers.openai.com/codex/glossary | Runtime surface terminology mapping and drift control |

## Adopted Runtime Capabilities

### P0: Runtime Config Boundary

- Convert project-local config limitations into `manifests/adk_runtime_policy_gates.json`.
- Deny repo-level override for provider, auth, base URL, profile, notification, realtime and telemetry keys.
- Add deterministic checks in `agent-dev-kit/scripts/check-openai-developers-governance.sh`.

### P0: Permission Profile Governance

- Treat permission profiles as least-privilege runtime policy, not a convenience preset.
- Require filesystem roots, deny-read paths, network/domain policy, Unix socket policy and approval behavior before promotion.
- Keep `danger-full-access` as an explicit high-risk state that cannot be inherited as a safe baseline.

### P1: Memory Runtime Boundary

- Keep memory runtime opt-in.
- Require source classification and owner review when external context contributes to a memory candidate.
- Preserve raw evidence fallback and redaction decision before any durable memory promotion.

### P1: Subagent Runtime Limits

- Record maximum threads, maximum depth, fallback runtime limit and nested-subagent default before delegated multi-stage work.
- Require delegated-agent evidence fields so subagent completion cannot be treated as project completion.

### P1: Surface Terminology Drift Control

- Add `manifests/codex_surface_terms.json` as the Codex glossary to ADK terminology mapping.
- Gate future docs, skills and manifests that use agent, skill, plugin, automation, worktree, MCP server or permission profile terms.

## Landed Artifacts

| Artifact | Change |
|---|---|
| `agent-dev-kit/manifests/adk_runtime_policy_gates.json` | Added config key boundaries, granular approval policy, permission profile policy and memory runtime policy. |
| `agent-dev-kit/manifests/skill_mcp_dependencies.json` | Added MCP runtime config policy fields and checks. |
| `agent-dev-kit/manifests/subagent_contracts.json` | Added runtime limits and nested-subagent policy. |
| `agent-dev-kit/manifests/codex_surface_terms.json` | Added official Codex glossary to ADK terminology mapping. |
| `agent-dev-kit/manifests/official_docs_freshness_gates.json` | Added 2026-06-15 source freshness records. |
| `agent-dev-kit/scripts/check-openai-developers-governance.sh` | Added deterministic checks for runtime config, permission, memory, subagent and surface-term governance. |
| `agent-dev-kit/scripts/check-openai-runtime-capabilities.sh` | Added executable runtime capability gate for permission profile lint, MCP runtime contract lint, subagent evidence schema and terminology lint. |
| `agent-dev-kit/tests/test_openai_runtime_capabilities.sh` | Added regression coverage for the new runtime capability gate and `devkit.sh` command surface. |
| `scripts/check-adk-openai-runtime-capabilities.sh` | Added llm_agent top-level wrapper so `scripts/check-all.sh` discovers the new gate. |
| `agent-dev-kit/docs/reference/openai-developers-reference.md` | Added 2026-06-15 source inventory and Delta Landing. |
| `agent-dev-kit/docs/runbooks/openai-developers-governance.md` | Added promotion and control-plane gates for the new runtime capabilities. |

## Non-Adopted Boundaries

- Do not make OpenAI product-specific config a platform-neutral default without ADK-owned wording and checks.
- Do not enable broader filesystem, network, MCP, memory or subagent permissions because a feature exists in the official docs.
- Do not treat auto-review, remembered approval or model-generated feedback as human owner approval.
- Do not copy external context into long-term memory without explicit source review and redaction.

## Verification Plan

```bash
agent-dev-kit/scripts/check-openai-developers-governance.sh --summary-json
agent-dev-kit/scripts/check-openai-runtime-capabilities.sh --summary-json
agent-dev-kit/tests/test_openai_developers_governance.sh
agent-dev-kit/tests/test_openai_runtime_capabilities.sh
agent-dev-kit/scripts/validate-assets.sh --strict
scripts/check-adoption-matrix-structured.sh
scripts/check-adoption-evidence-integrity.sh
```
