# WeChat Article Absorption Batch

- Batch ID: `wechat-p2-reference-001`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: all queued `P2-reference-only`
- Mode: apply

## Batch Goals

- Close the remaining P2 reference-only backlog without importing platform setup, provider configuration, model rankings, plugin markets, remote-control tutorials, news claims or article prose into ADK.
- Default to `REFERENCE_ONLY` where existing ADK assets already cover the method.
- Use `REJECT` for installation/configuration/news/market/product/remote-control content with no reusable gate.
- Absorb only durable method gates that strengthen existing ADK assets.

## Decision Summary

| Decision | Count | Meaning |
|---|---:|---|
| MERGE | 2 | Method-only MCP/tool-call gates absorbed into existing assets. |
| REFERENCE_ONLY | 69 | Useful background or duplicate method, no new gate. |
| REJECT | 48 | Tool setup, product news, market ranking, model dynamics, remote-control or non-ADK content. |

## MERGE Items

| id | target | absorbed gate |
|---|---|---|
| wechat-0093 | `agent-dev-kit/docs/runbooks/mcp-governance.md`, `agent-dev-kit/templates/security/tool-call-policy.md` | Write tools must not accept unbounded selectors; bulk writes require dry-run with `affected_count`, scope summary, max limit, rollback/audit fields and explicit approval. |
| wechat-0141 | `agent-dev-kit/docs/runbooks/mcp-governance.md`, `agent-dev-kit/templates/security/tool-call-policy.md` | High-risk programmatic tool/API execution must return structured `approval_required`; file write/patch success requires postcondition evidence such as diff/hash/summary and deny-path tests. |

## Rejected Or Reference-Only Groups

- Product and model news: Claude/Gemini/DeepSeek/Codex releases, prices, rankings, benchmarks and capability claims.
- Installation/configuration tutorials: Codex, Claude Code, Hermes, DeepSeek, GLM, provider relay, API key, base URL, Windows/WSL/Node/editor setup.
- Remote/control-plane tutorials: mobile remote control, SSH, cron, bots, gateway, GUI/computer-use and scheduled message automation.
- Tool rankings and personal recommendations: terminal tools, Cursor/Windsurf, Agent frameworks, plugin lists and Vibe Coding roadmaps.
- Duplicate methodology: AGENTS/Skill/MCP layering, spec-first, planning, context governance, memory governance, harness, review and verification were already absorbed in earlier batches or existing ADK assets.

## Full-Repository Comparison

### Duplicate Check

- Existing similar assets: `mcp-governance.md`, `templates/security/tool-call-policy.md`, `security-supply-chain.md`, `planning-execution-loop.md`, `token-context-governance.md`, `memory-governance.md`, `skill-agent-runtime-model.md`, `spec-chain-delivery.md`.
- Result: no new Skill, workflow, plugin, MCP server, subrepo, profile or runtime connector is justified.

### Conflict Check

- No manifest, routing metadata, profile, dependency, MCP declaration or external connector was changed.
- New MERGE rules strengthen existing tool-call gates and do not permit new write tools.
- REJECT and REFERENCE_ONLY items do not alter ADK architecture or source-to-live delivery.

### Redundancy Check

- Most P2 reference-only items duplicate earlier P0/P1/P2-external method absorption.
- External product names, marketing claims and platform-specific setup were not promoted to core docs.
- Result: backlog closed without parallel assets.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p2-reference-001.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/templates/security/tool-call-policy.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; all pending intake decisions are closed. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill and doc budgets passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflict introduced. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No root whitespace errors. |
| `rtk bash -lc "git -C agent-dev-kit diff --check"` | PASS | No ADK subrepo whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | `subrepo_state` fail: `dirty=21`, `known_dirty=20`, `unexpected_dirty=1`. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` due dirty subrepo state. |

## Residual Risk

- The review used local archived articles and did not verify time-sensitive model, pricing, release, benchmark or repository claims online.
- `REJECT` means “not suitable for ADK absorption”, not deletion from the article archive.
- Runtime adoption remains blocked unless a separate supply-chain review targets a specific external asset and version.
