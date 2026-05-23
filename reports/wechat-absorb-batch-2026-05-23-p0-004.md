# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-004`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: fourth queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable E2E value, context-rot, MCP, Skill compatibility and high-risk security boundaries.
- Do not copy tutorial code, install commands, GitHub claims, platform-specific configuration packs, marketplace lists or reverse-engineering scripts into ADK core.
- Keep external repos, MCP implementations, JS reverse Skill code and Claude-specific API/frontmatter claims report-only until review.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0075 | AI engineering effectiveness retrospective | governance-rule-or-script | MERGE | `spec-chain-delivery.md`, `token-context-governance.md` | medium | E2E value, code-as-debt, left-shift spec/API/test checks and state discipline absorbed. |
| wechat-0085 | debate-style Skill development | skill-or-workflow-enhancement | MERGE | `lead-agent-convergence-delivery.md` | medium | Debate-first mode added for complex architecture decisions; no standalone debate Skill. |
| wechat-0086 | top development Skills list | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-curation-delivery.md` | medium | Recommendation list is candidate discovery only, not adoption evidence. |
| wechat-0087 | external Claude Code configuration suite | skill-or-workflow-enhancement | MERGE | `token-context-governance.md`, `mcp-governance.md` | high | Workflow/context/MCP cost reminders merged; config suite remains report-only. |
| wechat-0092 | GSD context engineering article | governance-rule-or-script | MERGE | `token-context-governance.md` | high | Context rot, thin orchestrator, file-as-memory and wave execution guidance absorbed. |
| wechat-0096 | MCP protocol overview | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | high | Protocol surface, transport and readiness gates absorbed. |
| wechat-0097 | local MCP server tutorial | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | medium | stdio/JSON-RPC smoke and local process boundary absorbed; sample code rejected. |
| wechat-0100 | JS reverse Skill experiment | skill-or-workflow-enhancement | MERGE | `security-supply-chain.md` | high | High-risk reverse/dynamic capture boundary absorbed; external Skill code rejected. |
| wechat-0101 | Claude Code Skills API article | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md` | medium | Platform-specific frontmatter compatibility mapping absorbed. |
| wechat-0102 | Claude Code Skills guide | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-curation-delivery.md` | medium | Generic lifecycle overview already covered by existing ADK assets. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-planning-execution-loop`, `adk-skill-composition-governance`, `adk-security-supply-chain`, `adk-runtime-router`, `adk-parallel-agent-governance`.
- Existing similar docs: `spec-chain-delivery.md`, `token-context-governance.md`, `mcp-governance.md`, `security-supply-chain.md`, `skill-curation-delivery.md`, `lead-agent-convergence-delivery.md`.
- Existing similar scripts: `check-token-budget.sh`, `check-skill-routing-conflicts.sh`, `validate-assets.sh`, `check-wechat-intake-ledger.sh`.
- Result: no new Skill, MCP server, config pack, JS reverse tool, marketplace mirror or workflow command is justified; accepted content is MERGE into existing governance.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml`, profile, trigger or Skill metadata changes.
- Workflow conflicts: no change to `propose -> apply -> verify -> review -> archive`.
- Policy conflicts: external MCP servers, JS reverse scripts, Claude-specific installation commands and config suite claims remain `report-only-until-security-review`.
- Result: pass.

### Redundancy Check

- Merge opportunities: E2E value metrics, context rot, MCP protocol surface, stdio smoke, debate-first review and platform compatibility all map to existing runbooks.
- Stale or leftover assets: no new script, Skill, MCP manifest, prompt pack, generated code or third-party config added.
- Result: no parallel Skill recommendation list, no GSD clone, no JS reverse Skill import, no Claude-only frontmatter schema.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Accepted only as ADK runtime governance, context management, MCP boundary, security review and spec-chain discipline.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no new script behavior; decisions overlay continues to drive ledger.
- Result: controlled merge.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-004.md`
  - `agent-dev-kit/docs/runbooks/spec-chain-delivery.md`
  - `agent-dev-kit/docs/runbooks/token-context-governance.md`
  - `agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`
- Rejected/reference-only items and reasons:
  - `wechat-0086`: hot Skill recommendation list is only candidate discovery, not adoption proof.
  - `wechat-0102`: generic Skills guide duplicates existing lifecycle/discovery guidance.
  - External MCP/JS reverse/config suite code: not security reviewed and outside current ADK core scope.
- External code candidates:
  - GSD, everything-claude-code, MCP sample servers, JS reverse Skill and Claude-specific install/API paths remain report-only.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; fourth-batch decisions regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | ADK docs remain within token budget. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory/context governance regression passed. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance sync passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflicts introduced. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` remains dirty as strict subrepo until committed. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Evidence bundle points to `subrepo_state` fail: `unexpected_dirty=1`, `agent-dev-kit` dirty. |

## Residual Risk

- Several source articles cite fast-moving external repositories, platform APIs, model/tool versions and security-sensitive workflows. None were installed, cloned, promoted or added to manifest.
- This batch is method-only. Runtime adoption still requires `agent-dev-kit -> ~/codex -> ~/.codex` handoff evidence.
