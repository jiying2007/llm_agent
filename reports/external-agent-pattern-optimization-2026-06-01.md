# External Agent Pattern Optimization - 2026-06-01

## Scope

This note records the method-only optimization pass for `compound-engineering`, Karpathy-style LLM Wiki, and sampled `karpathy-skills` material. No external plugin, hook, worker, MCP server, package-manager install, local port or runtime configuration was enabled.

## Decisions

| Source | Decision | Landing |
|---|---|---|
| EveryInc compound engineering | adapt | Strengthen Codify Decision with next-task friction evidence. |
| Karpathy-style LLM Wiki | adapt | Add source freshness and duplicate concept checks to knowledge compile governance. |
| `karpathy-skills` topic / Newton sample | adapt-method-only | Add reuse-before-rebuild gate before new skills, scripts, workflows or runbooks. |

## Implemented Gates

- Codify Decision now records `next_task_friction_reduced`, `reduced_by` and `reduction_evidence`.
- Knowledge Compile now records `retrieved_at`, `review_status`, `expires_at` and `duplicate_concept_check`.
- Reuse Before Rebuild adds a structured decision template and gate requiring `existing_asset_search`, candidate assets and a `use-as-is` / `adapt-existing` / `build-fresh` / `reference-only` decision.

## Boundaries

- `compound-engineering-plugin` remains method-only; its skill and agent inventory is not imported.
- `karpathy-skills` topic membership is not treated as trust evidence.
- New runtime assets still require separate supply-chain review.

## Validation Targets

```bash
rtk bash agent-dev-kit/scripts/check-external-agent-patterns.sh
rtk bash agent-dev-kit/scripts/check-codify-governance.sh
rtk bash agent-dev-kit/scripts/check-knowledge-compile-model.sh
rtk bash agent-dev-kit/scripts/check-reuse-before-rebuild.sh
rtk bash agent-dev-kit/tests/test_capability_uplift.sh
```

