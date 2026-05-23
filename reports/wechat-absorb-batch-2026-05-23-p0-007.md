# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-007`
- Date: 2026-05-23
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Scope: P0 Skill/Agent/SOP candidates from `wechat-0147` through selected adjacent P0 items up to `wechat-0189`
- Mode: apply

## Batch Goals

- Absorb only reusable rules, workflows, gates, templates, or test cases.
- Do not copy article prose into core ADK assets.
- Keep external code, plugin, MCP, hook, marketplace and install content report-only until supply-chain review is complete.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0147 | ADK Agent Skill design patterns | duplicate Skill pattern guidance | REFERENCE_ONLY | `skill-curation-delivery.md`; `adk-skill-lifecycle.md` | medium | Existing Tool Wrapper/Generator/Reviewer/Inversion/Pipeline guidance is stricter. |
| wechat-0151 | Codex Skills usage and development guide | Skill script admission boundary | MERGE | `skill-curation-delivery.md`; `skill-agent-runtime-model.md`; `security-supply-chain.md` | high | Script/install examples remain report-only. |
| wechat-0155 | Scientific Agent Skill design | deterministic source-of-truth gate | MERGE | `skill-curation-delivery.md` | medium | Added deterministic source rule for scoring, validation, formatting and status decisions. |
| wechat-0158 | Claude/Codex AGENTS and config share | external config-share layering | MERGE | `skill-agent-runtime-model.md`; `security-supply-chain.md` | high | MCP/API/hook/provider details remain report-only. |
| wechat-0161 | Automation Skill engineering practice | vertical business automation boundary | MERGE | `skill-curation-delivery.md`; `planning-execution-loop.md`; `security-supply-chain.md` | medium | OCR/API/business code remains report-only. |
| wechat-0162 | Skills deep analysis | generic Skill/cache overview | REFERENCE_ONLY | `skill-agent-runtime-model.md`; `token-context-governance.md` | medium | Platform and cost claims are unstable. |
| wechat-0163 | Agent Skill five design patterns | duplicate Skill pattern guidance | REFERENCE_ONLY | `skill-curation-delivery.md`; `adk-skill-lifecycle.md` | medium | Duplicate of existing pattern guidance. |
| wechat-0164 | Agent Skill five design patterns short variant | duplicate Skill pattern guidance | REFERENCE_ONLY | `skill-curation-delivery.md`; `adk-skill-lifecycle.md` | medium | Duplicate short variant. |
| wechat-0167 | Awesome Codex Skills marketplace article | market list | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | high | Popularity and clone commands are not adoption evidence. |
| wechat-0169 | MCP protocol overview | generic MCP overview | REFERENCE_ONLY | `mcp-governance.md`; `security-supply-chain.md` | medium | Existing MCP governance already covers protocol and permission gates. |
| wechat-0176 | Google Antigravity Skills guide | platform field mapping | MERGE | `skill-curation-delivery.md`; `security-supply-chain.md` | medium | Platform paths, scripts and semantics remain report-only. |
| wechat-0184 | SkillHub vs SkillSMP comparison | market comparison | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | medium | Marketplace ranking and mirror claims are reference-only. |
| wechat-0187 | Top Claude Code Skills list | market/recommendation list | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | high | Install commands, repo links and popularity claims rejected from core. |
| wechat-0189 | AI development framework comparison | framework comparison | REFERENCE_ONLY | `planning-execution-loop.md`; `skill-curation-delivery.md`; `security-supply-chain.md` | high | External repos and framework claims require separate review. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-skill-composition-governance`, `adk-planning-execution-loop`, `adk-security-supply-chain`.
- Existing similar docs: `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`, `agent-dev-kit/docs/skill-agent-runtime-model.md`, `agent-dev-kit/docs/runbooks/mcp-governance.md`, `agent-dev-kit/docs/runbooks/planning-execution-loop.md`.
- Existing similar scripts: ADK strict validation, token budget, memory governance and ledger checks.
- Result: most Skill pattern, MCP overview and marketplace content is already covered; only stable gates were merged.

### Conflict Check

- Routing or trigger conflicts: none; no new Skill, Workflow, manifest route or trigger was added.
- Workflow conflicts: none; merged rules strengthen existing method-only and supply-chain boundaries.
- Policy conflicts: none; external code and platform runtime content stayed report-only.
- Result: pass.

### Redundancy Check

- Merge opportunities: deterministic source-of-truth, Skill script admission, external config-share layering, vertical automation layering, platform field mapping.
- Stale or leftover assets: none added.
- Result: pass.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Generic platform and marketplace content remains reference-only; reusable governance gates fit ADK.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no script behavior change; ledger regenerated from decisions TSV.
- Result: pass.

## Implementation

- Files changed:
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/skill-agent-runtime-model.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-007.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `~/.codex` runtime config
  - external repos, MCP servers, plugin manifests, hooks and install scripts
- Rejected/reference-only items and reasons:
  - Duplicate Skill pattern articles: covered by existing lifecycle and curation guidance.
  - Generic MCP overview: covered by existing MCP governance.
  - Marketplace and ranking articles: discovery only, not adoption evidence.
  - Framework comparison articles: external claims require separate security review.
- External code candidates:
  - `wechat-0151`, `wechat-0158`, `wechat-0167`, `wechat-0187`, `wechat-0189` remain `report-only-until-security-review`.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/generate-wechat-intake-ledger.sh` | PASS | Regenerated ledger and next-batch report; `articles=313`, `external_code_mentions=99`. |
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance unchanged and valid. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill/doc budget limits pass. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No new routing conflicts. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Aggregates subrepo-state failure: 20 known-dirty observe repos and `agent-dev-kit` strict dirty. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 pass; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh`. |
| `rtk scripts/check-subrepo-state.sh .` | NEEDS-FIX | `known_dirty=20`, `unexpected_dirty=1`; strict dirty repo is `agent-dev-kit` with current ADK doc changes. |

## Residual Risk

- Existing broad worktree dirtiness remains from previous batches and reference subrepos; this batch does not clean or commit it.
- `check-all --quick` may still fail strict subrepo state because `agent-dev-kit` has intentional uncommitted changes.
- External code, install commands, MCP server examples, platform-specific fields and marketplace claims remain report-only and were not executed.
