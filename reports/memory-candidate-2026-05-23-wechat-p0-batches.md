# Memory Candidate: WeChat P0 Absorption Batches

- Date: 2026-05-23
- Scope: `/home/leiwenjun/bin/llm_agent`
- Source session wrap: `reports/session-wrap-2026-05-23-wechat-p0-batches.md`
- Archive copy: `/home/leiwenjun/codex/docs/archive/session-wrap/20260523-085953-session-wrap-2026-05-23-wechat-p0-batches.md`
- Status: review candidate only; do not auto-promote without explicit approval.

## Candidate Entries

1. WeChat article absorption must use `reports/wechat-article-decisions.tsv` as the reviewed decision overlay. `reports/wechat-article-intake.jsonl` is generated output and should not be edited manually.
2. P0 WeChat article absorption is method-only by default. External repositories, MCP recommendations, install commands, marketplace claims, tutorial code, and visual/IP examples remain `report-only` until a separate security and supply-chain review passes.
3. New Skill creation requires reuse threshold, atomicity, pattern classification, dependency boundary, and written proof that existing skills cannot be enhanced instead.

## Recommended Promotion Target

- Project memory candidate: `~/.codex/memories/projects/llm_agent.md`
- Alternative: keep archive-only until the first three P0 batches complete and the rule repeats without correction.

## Do Not Promote

- Article titles, prose, tutorial snippets, GitHub popularity claims, marketplace rankings, installation commands, or one-off batch status.
- Current dirty worktree state. It is a handoff risk, not a durable memory rule.
