# OpenAI Developers Adoption Candidates - 2026-05-28

## Scope

This note records the 2026-05-28 official OpenAI Developers follow-up batch for `llm_agent` and `agent-dev-kit`. The batch focuses on API-backed runner governance only. It does not enable hosted tools, change production model defaults, or migrate ADK to the Responses API.

## Sources

| Source ID | Official URL | Retrieved | Decision |
|---|---|---:|---|
| `openai-data-controls-responses` | https://developers.openai.com/api/docs/guides/your-data#v1responses | 2026-05-28 | Adopt as P0 retention and ZDR governance input. |
| `openai-responses-migration-statefulness` | https://developers.openai.com/api/docs/guides/migrate-to-responses#4-decide-when-to-use-statefulness | 2026-05-28 | Adopt as P1 pilot-only statefulness contract input. |
| `openai-prompt-cache-retention` | https://developers.openai.com/api/docs/guides/prompt-caching#prompt-cache-retention | 2026-05-28 | Adopt as P1 prompt-cache retention and model-support freshness input. |

## Adopted Patterns

1. Data retention and ZDR must be explicit before API-backed runner pilots are promoted.
   - Evidence: `agent-dev-kit/manifests/data_retention_state_contracts.json`
   - Gate: `agent-dev-kit/scripts/check-openai-developers-governance.sh`

2. Responses statefulness is a choice set, not a default migration.
   - Evidence: `agent-dev-kit/manifests/context_state_contracts.json`
   - Required choices: `previous_response_id`, Conversation state, manual item replay, encrypted reasoning, `store=false`, `call_id` correlation.

3. Prompt cache retention is a privacy and compatibility policy.
   - Evidence: `agent-dev-kit/manifests/prompt_cache_policy_contracts.json`
   - Required choices: `in_memory`, `24h` or `model_default`, plus model-support freshness and cache-miss-safe behavior.

## Rejected Or Deferred

- Do not enable hosted tools or remote MCP just because they are described in official docs.
- Do not store raw reasoning, encrypted reasoning payloads or server-retained response state in ADK long-term memory.
- Do not treat cached-token counts as correctness evidence.
- Do not rewrite ADK around Responses API until a local API-backed runner pilot passes eval, retention and rollback gates.

## Validation Targets

```bash
rtk bash agent-dev-kit/scripts/check-openai-developers-governance.sh
rtk bash agent-dev-kit/tests/test_openai_developers_governance.sh
rtk bash agent-dev-kit/scripts/validate-assets.sh --strict
rtk bash scripts/check-adoption-evidence-integrity.sh
```
