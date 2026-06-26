# OSS Absorption Plan: gymaira1990-jpg/noah-gen3-type2

> Status: report-only
> Date: 2026-06-26
> Decision: `ARCHIVE_ONLY`, with selective future `ADAPT`

## Decision Table

| Source idea | Decision | Reason | Target |
|---|---|---|---|
| Drawer-cascade compression | ADAPT later | Potentially useful as an eval fixture, but overlaps existing token-context governance. | Future tests/fixtures only |
| Deterministic noise filtering | ADAPT later | Good pre-LLM principle; should not become a new parallel workflow. | Existing memory/context governance |
| Protected correction/decision/progress keys | ADAPT later | Useful for memory conflict tests. | Existing memory governance fixtures |
| Model registry and UI | REJECT | Too much runtime and credential surface for current scope. | None |
| Historical Noah runtime | REJECT | Upstream marks it reference-only and local review found suspected secret/default-password risks. | None |

## No-Change Justification

No ADK source asset was modified because:

1. Existing ADK runbooks already own the relevant policy surface.
2. Direct source import is blocked by security and license-file concerns.
3. The user asked to absorb external projects, and the minimal safe absorption here is auditable report-only intake plus review queue.

## Required Future Gate Before Any Asset Change

- Define one concrete missing behavior in an existing ADK test or runbook.
- Use clean-room examples only.
- Run the relevant ADK test plus `rtk scripts/check-all.sh --quick`.
- Keep upstream runtime code, MCP scripts, and install commands out of ADK assets.
