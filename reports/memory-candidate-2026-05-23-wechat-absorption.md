# Memory Candidate: WeChat Article Absorption Governance

## Review Required

This file is a review draft only. Do not treat it as active memory until a human explicitly promotes it to project `AGENTS.md`, `~/.codex/memories`, or codex-agent-mem.

## Candidate Entries

### Candidate 1

- Scope: `llm_agent`
- Type: project workflow rule
- Confidence: high
- Source: `reports/session-wrap-2026-05-23-wechat-absorption.md`
- Proposed memory:
  - `wechat-articles/` absorption must be ledger-first and batch-gated. Generate and validate `reports/wechat-article-intake.jsonl` before modifying `agent-dev-kit` assets.
- Suggested target: project `AGENTS.md` or project memory after review.

### Candidate 2

- Scope: `llm_agent`
- Type: security and supply-chain boundary
- Confidence: high
- Source: `docs/runbooks/wechat-article-absorption.md`
- Proposed memory:
  - GitHub/source-code/install-command references found in `wechat-articles/` remain `report-only-until-security-review`; do not automatically onboard them as subrepos or execute install commands.
- Suggested target: project `AGENTS.md` or project memory after review.

### Candidate 3

- Scope: `agent-dev-kit`
- Type: anti-drift rule
- Confidence: high
- Source: `docs/absorption-governance.md`
- Proposed memory:
  - When article content overlaps existing ADK skills/workflows/scripts, default to `MERGE` or `ENHANCE`; require explicit evidence before creating a new parallel asset.
- Suggested target: `docs/absorption-governance.md` already contains this rule; memory promotion is optional.

## Not Promoted

- Full article summaries: keep in reports/archive only.
- External project names and marketing claims: keep out of durable memory unless separately verified.
- One-off validation logs: keep in session archive, not memory.
