# OSS Duplicate Check: gymaira1990-jpg/noah-gen3-type2

> Status: report-only
> Date: 2026-06-26
> Source: `scratch/oss-intake/noah-gen3-type2`

## Existing Local Assets Checked

| Local asset | Overlap |
|---|---|
| `agent-dev-kit/docs/runbooks/token-context-governance.md` | Layered context reading, raw evidence fallback, compression boundaries, context budget profiles. |
| `agent-dev-kit/docs/runbooks/memory-governance.md` | Memory candidate extraction, scope isolation, source evidence, promotion controls, mixed retrieval strategies. |
| `agent-dev-kit/docs/runbooks/knowledge-compile-model.md` | Raw source preservation, maintained synthesis pages, retrievable memory boundaries. |
| `agent-dev-kit/templates/context/` | Context budget, raw-evidence index, memory-search-result, low-token profile patterns. |
| `agent-dev-kit/templates/memory/` | After-action and memory-candidate structured outputs. |
| `adk-context-compress-handoff` skill | Stable/dynamic/evidence/excluded context handoff discipline. |
| `adk-memory-curator` skill | Memory candidate review and deduplication workflow. |

## Duplicate / Conflict Findings

| Candidate idea | Duplicate level | Decision |
|---|---:|---|
| Drawer cascade compression | Partial | Do not add new skill. Consider future fixture under token-context governance only. |
| Noise filtering before memory write | Partial | ADAPT later only if tests show missing deterministic filter coverage. |
| Protected decision/correction/progress records | Partial | ADAPT as examples; existing memory governance already owns write policy. |
| Hot/warm/cold memory tiers | High | Existing memory governance already distinguishes resident and retrievable memory; do not add parallel terminology as policy. |
| Model management UI and DeepSeek adapters | Low overlap, high runtime risk | REJECT for current absorption scope. |

## Conclusion

No new ADK skill, workflow, manifest, or global AGENTS rule should be created from this repository in the current pass. The safe absorption path is report-only plus possible future test fixtures for existing context and memory governance assets.
