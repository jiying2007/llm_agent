# OSS Absorption Plan: gymaira1990-jpg/Mnemosyne-OS

> Status: report-only
> Date: 2026-06-26
> Decision: `ARCHIVE_ONLY`, with selective future `ADAPT`

## Decision Table

| Source idea | Decision | Reason | Target |
|---|---|---|---|
| Temporal memory tree | ADAPT later | Useful backend-evaluation dimension, but not required for default ADK memory policy. | Future backend capability checklist |
| Research -> engineering -> archive lifecycle | ADAPT later | Aligns with archive governance; may become examples or fixtures. | Existing archive/memory governance |
| Hybrid retrieval scoring | WATCH | Implementation choices must remain backend-specific. | Future retrieval evaluation only |
| Hash-purification/fossil nodes | WATCH | Needs legal/security review before any guidance. | Security research note only |
| Local/cloud sync | WATCH | High trust-boundary and credential impact. | MCP/backend review only |

## No-Change Justification

No ADK source asset was modified because:

1. Existing memory-governance and archive-governance assets already own the relevant policy.
2. The repository is a runtime product with external service dependencies, not a drop-in ADK asset.
3. Current evidence supports method-level observation, not live integration.

## Required Future Gate Before Any Asset Change

- Identify a concrete missing behavior in existing memory or archive governance.
- Write a clean-room fixture or checklist item.
- Run targeted ADK tests plus `rtk scripts/check-all.sh --quick`.
- Keep runtime service, database schema, model-provider config, and sync code out of ADK assets unless separately approved.
