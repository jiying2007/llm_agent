# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-001`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: first queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb only reusable rules, workflows, gates, templates, or test cases.
- Do not copy article prose into core ADK assets.
- Keep external code, named tools, install commands, and project claims report-only until supply-chain review is complete.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0001 | Codex CLI Skills experience summary | skill-or-workflow-enhancement | MERGE | `skill-agent-runtime-model.md`, `skill-curation-delivery.md` | medium | Existing ADK already treats Skill as SOP; enhance boundary language only. |
| wechat-0002 | context continuity tool article | governance-rule-or-script | MERGE | `memory-governance.md`, `token-context-governance.md` | high | External tool/install claims not adopted; keep method-only. |
| wechat-0004 | Codex+Skill+MCP domain pipeline | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `skill-curation-delivery.md` | medium | Domain-specific book-source rules rejected; retain evidence-loop pattern. |
| wechat-0005 | Agent product taxonomy | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-agent-runtime-model.md` | medium | Existing model covers Agent/Workflow/MCP boundaries; no new gate. |
| wechat-0012 | multi-agent review story | workflow-enhancement | DEFER | future `P1-multi-agent-review` batch | high | P1 item included by earlier next-batch ordering; left unmodified in ledger. |
| wechat-0013 | GitHub trend/news roundup | governance-rule-or-script | REFERENCE_ONLY | `token-context-governance.md` | medium | Trend claims and project names are not durable ADK policy. |
| wechat-0015 | MCP Spring Boot tutorial | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Tutorial code and network install paths rejected; validation-chain idea retained. |
| wechat-0016 | project context document article | skill-or-workflow-enhancement | MERGE | `skill-agent-runtime-model.md`, `workspace-maintenance-guide.md` | medium | Mapped to AGENTS/project-context governance; no CLAUDE.md parallel track. |
| wechat-0020 | memory-system taxonomy article | governance-rule-or-script | MERGE | `memory-governance.md`, `token-context-governance.md` | high | Named external memory projects remain report-only. |
| wechat-0021 | context management article | governance-rule-or-script | MERGE | `token-context-governance.md`, `memory-governance.md` | medium | Absorb transform-layer, raw-evidence and fallback rules. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-token-context-governance`, `adk-context-engineering`, `adk-after-action-review`, `adk-runtime-router`.
- Existing similar docs: `docs/runbooks/token-context-governance.md`, `docs/runbooks/memory-governance.md`, `docs/skill-agent-runtime-model.md`, `docs/runbooks/mcp-governance.md`.
- Existing similar scripts: `check-token-budget.sh`, `check-memory-governance.sh`, `check-skill-routing-conflicts.sh`.
- Result: no new skill or workflow is justified; all accepted items are MERGE/ENHANCE into existing assets.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml` routing change.
- Workflow conflicts: no change to `propose -> apply -> verify -> archive`.
- Policy conflicts: external code and install commands remain `report-only-until-security-review`.
- Result: pass.

### Redundancy Check

- Merge opportunities: context continuity, memory extraction, Skill SOP and MCP evidence-loop rules merge into existing runbooks.
- Stale or leftover assets: none intentionally created outside `reports/` and targeted docs.
- Result: no parallel asset path added.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Generic AI-coding methods are accepted only as ADK runtime governance, not product-domain policy.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: yes, generator/checker now support reviewed decision overlay.
- Result: controlled merge.

## Implementation

- Files changed:
  - `scripts/generate-wechat-intake-ledger.sh`
  - `scripts/check-wechat-intake-ledger.sh`
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `docs/runbooks/wechat-article-absorption.md`
  - `agent-dev-kit/docs/runbooks/token-context-governance.md`
  - `agent-dev-kit/docs/runbooks/memory-governance.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/skill-agent-runtime-model.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
- Rejected items and reasons:
  - Product taxonomy and trend/news material: existing runtime model covers the durable part.
  - Domain-specific book-source and Spring Boot tutorial code: outside ADK core domain and not supply-chain reviewed.
- External code candidates:
  - Named tools, install commands and GitHub trend claims are retained only in report evidence.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; decisions overlay regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Context governance assets remain within budget. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance gate passed. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Docs and governance sync passed. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` is dirty as a strict subrepo until its changes are committed. |

## Residual Risk

- Several source articles are summaries or tutorial prose, not primary technical specs. Decisions therefore remain method-only and do not import factual project claims.
- The P1 item `wechat-0012` was present in the old next-batch report but is intentionally deferred to the multi-agent review batch.
