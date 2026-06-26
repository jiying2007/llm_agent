# OSS Duplicate Check: gymaira1990-jpg/Mnemosyne-OS

> Status: report-only
> Date: 2026-06-26
> Source: `scratch/oss-intake/Mnemosyne-OS`

## Existing Local Assets Checked

| Local asset | Overlap |
|---|---|
| `agent-dev-kit/docs/runbooks/memory-governance.md` | Memory scope, evidence, promotion, retrieval, backend admission, provider review. |
| `agent-dev-kit/docs/runbooks/knowledge-compile-model.md` | Raw sources, maintained synthesis, retrievable memory, evidence fallback. |
| `agent-dev-kit/docs/runbooks/token-context-governance.md` | Progressive memory search, raw evidence fallback, long-context summary boundaries. |
| `agent-dev-kit/docs/runbooks/mcp-governance.md` | External memory/context server and MCP admission boundaries. |
| `adk-memory-curator` skill | Memory candidate review and cleanup. |
| `adk-knowledge-archive` skill | Durable archive creation. |
| `adk-archive-governance` skill | Archive metadata and governance repair. |

## Duplicate / Conflict Findings

| Candidate idea | Duplicate level | Decision |
|---|---:|---|
| Five-level temporal memory tree | Partial | ADAPT later as optional backend capability dimension, not global policy. |
| Research/engineering/archive halls | Partial | Already aligned with archive governance; add examples only if needed. |
| Hybrid retrieval score | Partial | Existing governance says semantic retrieval is candidate-only; keep implementation optional. |
| Hash-purification deletion | New but high-risk | WATCH/ARCHIVE_ONLY pending security/legal review. |
| Offline cache to cloud sync | New but high-risk | WATCH only; requires credential, consistency, rollback, and audit design. |

## Conclusion

Do not add a new memory skill or memory server integration. The useful material should remain as report-only reference until a concrete gap appears in ADK memory-governance tests or backend admission checklists.
