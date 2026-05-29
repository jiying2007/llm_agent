# ADK Capability Uplift Implementation - 2026-05-29

## Scope

This report records the implementation step after the external agent pattern governance contracts were accepted. The work keeps the previous method-only boundary: no external plugin, hook, worker, MCP server, package-manager install, vector service, local port, or runtime configuration is enabled.

## Implemented Capabilities

| Source Pattern | ADK Capability | Landing Assets | Gate |
|---|---|---|---|
| Karpathy-style LLM Wiki | Knowledge compile model with immutable raw sources, maintained wiki synthesis and schema lint boundaries | `agent-dev-kit/docs/runbooks/knowledge-compile-model.md`, `agent-dev-kit/templates/memory/knowledge-compile-note.md`, `agent-dev-kit/skills/adk-token-context-governance/SKILL.md` | `rtk bash agent-dev-kit/scripts/check-knowledge-compile-model.sh` |
| Compound Engineering | Codify after delivery, including reusable pattern, do-not-promote reason, owner review, rollback and evidence fields | `agent-dev-kit/templates/governance/codify-decision.md`, `agent-dev-kit/skills/adk-after-action-review/SKILL.md`, `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` | `rtk bash agent-dev-kit/scripts/check-codify-governance.sh` |
| claude-mem | Read-only progressive memory search: `search_index -> timeline_context -> observation_details` | `agent-dev-kit/docs/runbooks/token-context-governance.md`, `agent-dev-kit/templates/context/memory-search-result.md` | `rtk bash agent-dev-kit/scripts/check-context-experience-patterns.sh` |
| caveman | Explicit low-token communication profile with safety exceptions and restore conditions | `agent-dev-kit/templates/context/low-token-profile.md`, `agent-dev-kit/docs/runbooks/token-context-governance.md` | `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json` |

## Entry Points

- `agent-dev-kit/scripts/devkit.sh codify-governance`
- `agent-dev-kit/scripts/devkit.sh knowledge-compile`
- `agent-dev-kit/scripts/devkit.sh context-experience`
- `scripts/check-adk-codify-governance.sh`
- `scripts/check-adk-knowledge-compile-model.sh`
- `scripts/check-adk-context-experience-patterns.sh`

The top-level wrappers are discoverable by `scripts/check-all.sh` because they follow the existing `check-*.sh` convention.

## Regression Coverage

- `agent-dev-kit/tests/test_capability_uplift.sh` runs the three new capability gates.
- `agent-dev-kit/tests/run_all.sh` includes `test_capability_uplift.sh`.
- `agent-dev-kit/tests/test_scripts_smoke.sh` smoke-tests the new `devkit.sh` subcommands.
- `agent-dev-kit/tests/test_token_context_governance.sh` now expects 8 context governance assets, including the new memory search and low-token templates.

## Boundaries

- Knowledge compile pages are retrievable archive synthesis, not resident memory.
- Memory search is read-only by default; persistent memory still requires owner approval and redaction status.
- Low-token profile is explicit or context-pressure driven; safety exceptions restore full clarity.
- Codify decisions can explicitly reject promotion to avoid turning one-off session noise into durable rules.

## Validation Targets

```bash
rtk bash agent-dev-kit/scripts/check-codify-governance.sh
rtk bash agent-dev-kit/scripts/check-knowledge-compile-model.sh
rtk bash agent-dev-kit/scripts/check-context-experience-patterns.sh
rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json
rtk bash agent-dev-kit/tests/test_capability_uplift.sh
rtk bash agent-dev-kit/tests/test_token_context_governance.sh
rtk bash agent-dev-kit/scripts/validate-assets.sh --strict
rtk bash agent-dev-kit/scripts/devkit.sh test
rtk bash scripts/check-all.sh --quick
```
