# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-009`
- Date: 2026-05-23
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Scope: remaining P0 candidates from `wechat-0241` through `wechat-0313`
- Mode: apply

## Batch Goals

- Finish the expanded P0 queue before moving to P1.
- Use subagents for read-only analysis and security review; keep main Codex as the only writer.
- Absorb only durable method gates, boundaries, templates and validation rules.
- Reject or keep report-only any external repo, install command, MCP/provider, bot/cloud setup, hook, marketplace, SDK/API, benchmark or platform-specific runtime claim.

## Parallel Governance

- Parallel Suitability: yes.
- Subagent split:
  - Memory/context: `wechat-0243`, `wechat-0244`, `wechat-0256`, `wechat-0268`, `wechat-0270`, `wechat-0281`, `wechat-0301`.
  - Skill/resource/development: `wechat-0241`, `wechat-0251`, `wechat-0252`, `wechat-0264`, `wechat-0265`, `wechat-0266`, `wechat-0272`, `wechat-0291`, `wechat-0309`.
  - Workflow/framework/AGENTS: `wechat-0249`, `wechat-0258`, `wechat-0262`, `wechat-0287`, `wechat-0299`, `wechat-0302`, `wechat-0303`, `wechat-0305`, `wechat-0311`, `wechat-0313`.
  - Security/supply-chain review: high-risk external-code candidates.
- Write model: subagents returned recommendations only; all file edits were performed by main Codex.
- Shared-write freeze: no subagent modified reports, ADK docs, templates, manifests, root configs or `~/.codex`.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0241 | Claude Code skill collection | external skill pack | REJECT | none | high | Install scripts, browser/screenshot/media-download capabilities and repo claims rejected. |
| wechat-0243 | Multi-database memory system | memory backend matrix | MERGE | `memory-governance.md`; `security-supply-chain.md` | high | Added backend capability matrix and report-only rule. |
| wechat-0244 | Hindsight + Hermes memory | resident/retrievable memory | MERGE | `memory-governance.md`; `security-supply-chain.md` | medium | Added external memory layer boundary, triggers, recall/pruning and backup/audit gates. |
| wechat-0249 | AI programming workflow intro | multi-agent workflow overview | REFERENCE_ONLY | `planning-execution-loop.md`; `skill-agent-runtime-model.md` | medium | Existing planning/runtime/worker contracts cover the method. |
| wechat-0251 | Codex Pet Skill deep dive | generated asset pipeline | MERGE | `skill-curation-delivery.md`; `worker-contract.md` | high | Added manifest/provenance, centralized truth commit, QA and minimal repair gates. |
| wechat-0252 | Five ADK Skill patterns | duplicate Skill pattern analysis | REFERENCE_ONLY | `skill-curation-delivery.md`; `skill-agent-runtime-model.md`; `adk-skill-lifecycle.md` | high | Existing pattern and progressive disclosure rules are stricter. |
| wechat-0256 | Codex context management | external memory escalation | MERGE | `token-context-governance.md`; `project-map.md`; `memory-governance.md` | high | Added continuity pack vs historical search, raw evidence and fallback rules. |
| wechat-0258 | Workflow article archive index | learning index | REFERENCE_ONLY | `planning-execution-loop.md` | medium | Index only, no durable gate. |
| wechat-0262 | Codex workflow percentage | workflow metric critique | REFERENCE_ONLY | `prompt-evolution-delivery.md`; `spec-chain-delivery.md` | medium | Existing task card and delivery-value rules cover it. |
| wechat-0264 | What are Agent Skills | generic Skill overview | REFERENCE_ONLY | `skill-curation-delivery.md`; `skill-agent-runtime-model.md` | medium | Concept duplicate. |
| wechat-0265 | skill-creator practice | Skill factory overview | REFERENCE_ONLY | `skill-curation-delivery.md` | medium | Existing Skill Factory boundary covers it. |
| wechat-0266 | Progressive disclosure | Skill loading overview | REFERENCE_ONLY | `skill-curation-delivery.md`; `skill-agent-runtime-model.md` | medium | Existing metadata/SKILL/references layering covers it. |
| wechat-0268 | Claude Opus 4.6 release | model/news claim | REFERENCE_ONLY | none | medium | Time-sensitive platform claims only. |
| wechat-0270 | Claude vs GPT-5.3 Codex | model comparison | REFERENCE_ONLY | none | medium | Trend context only. |
| wechat-0272 | Codex Skill for article writing | platform tutorial | REJECT | none | medium | Node/npm/API key/directory setup and platform operations rejected. |
| wechat-0273 | Skill management across tools | external skill manager | REJECT | none | high | SKM import/projection conflicts with source-to-live asset chain. |
| wechat-0281 | Hermes LLM wiki | project wiki layering | MERGE | `token-context-governance.md`; `project-map.md`; `security-supply-chain.md` | high | Added raw/generated/schema/index-log layering; VPS/bot/cloud setup rejected. |
| wechat-0287 | Workflow framework comparison | external framework comparison | REFERENCE_ONLY | `skill-curation-delivery.md`; `planning-execution-loop.md`; `security-supply-chain.md` | high | Existing ADK routes cover the method; star/install claims rejected. |
| wechat-0291 | Skill development from scratch | weather/API tutorial | REJECT | none | high | API key, external repo, install script and publishing flow rejected. |
| wechat-0299 | Bad Codex prompts | prompt task-card gates | MERGE | `prompt-evolution-delivery.md` | medium | Added primary action, action mode, checkpoints and stop-on-failure. |
| wechat-0301 | Session management | context branch decisions | MERGE | `token-context-governance.md`; `worker-contract.md` | medium | Added continue/rewind/fresh brief/compact/subtask decision rules. |
| wechat-0302 | Codex as a team | multi-agent layering | REFERENCE_ONLY | `skill-agent-runtime-model.md`; `planning-execution-loop.md`; `worker-contract.md` | medium | Already covered by runtime model, planning loop and worker contract. |
| wechat-0303 | Superpowers skill practice | duplicate process flow | REFERENCE_ONLY | `planning-execution-loop.md`; `skill-curation-delivery.md` | medium | Existing ADK planning/debug/verification routes cover it. |
| wechat-0304 | code-review-graph | dependency graph scope rule | MERGE | `token-context-governance.md` | medium | Added graph/index as `scope_read` candidate with freshness, coverage and raw fallback. |
| wechat-0305 | AGENTS.md template | experience rule maintenance | MERGE | `workspace-maintenance-guide.md`; `memory-governance.md` | medium | Added concrete rule, revise-not-duplicate and stale-rule audit guidance. |
| wechat-0309 | Recommended skills list | candidate discovery list | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | high | Popularity/install claims remain report-only. |
| wechat-0311 | OpenSpec/Superpowers/Agent Skills | enforcement level taxonomy | MERGE | `planning-execution-loop.md`; `security-supply-chain.md` | high | Added deterministic/approval/advisory gate strength taxonomy. |
| wechat-0313 | Automation/Workflow/Agent | abstraction distinction | REFERENCE_ONLY | `skill-agent-runtime-model.md` | medium | Already absorbed in runtime model. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar docs: `planning-execution-loop.md`, `skill-agent-runtime-model.md`, `skill-curation-delivery.md`, `token-context-governance.md`, `memory-governance.md`, `security-supply-chain.md`, `prompt-evolution-delivery.md`.
- Existing similar templates: `project-map.md`, `worker-contract.md`, `memory-candidate.md`.
- Result: framework comparisons, Skill lists, model news, generic Skill explanations and Superpowers/OpenSpec tutorials were mostly reference-only or rejected.

### Conflict Check

- Routing or trigger conflicts: none; no new Skill, Workflow, manifest route or trigger was added.
- Runtime conflicts: none; external memory, browser, bot, hook, cloud, skill-manager and API-key content stayed report-only or rejected.
- Policy conflicts: none; changes strengthen method-only boundaries and source-to-live asset-chain protection.

### Redundancy Check

- New durable gates absorbed: backend capability matrix, resident/retrievable memory boundary, external memory escalation threshold, generated asset pipeline QA/provenance, dependency graph scope rule, prompt action-mode checkpoints, AGENTS experience-rule maintenance, gate enforcement taxonomy and session branch decisions.
- Stale or leftover assets: none added.

### Architecture Boundary

- Fits ADK: yes, as governance/runbook/template method rules.
- Affects manifests or routing: no.
- Affects `~/.codex`: no.
- Affects generated reports: yes, ledger and next batch regenerated from TSV.

## Implementation

- Files changed:
  - `agent-dev-kit/docs/runbooks/memory-governance.md`
  - `agent-dev-kit/docs/runbooks/token-context-governance.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
  - `agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md`
  - `agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/templates/planning/worker-contract.md`
  - `agent-dev-kit/templates/context/project-map.md`
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-009.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - root routing manifests
  - `~/.codex`
  - external repos, MCP servers, plugin manifests, hooks, install scripts, cloud/bot configs, SDK snippets and CI workflows
- External code candidates:
  - External-code and platform-tutorial items remain `report-only-until-security-review` in the ledger or are explicitly rejected in the decision TSV.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/generate-wechat-intake-ledger.sh` | PASS | Regenerated ledger and next-batch report; `articles=313`, `external_code_mentions=99`. |
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; generated ledger is fresh. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance checks pass after backend and external-memory additions. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill/doc budget limits pass. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No new routing conflicts. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk bash -lc "git -C agent-dev-kit diff --check"` | PASS | No whitespace errors inside the ADK subrepo. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Bundle generated with `status=needs-fix`; `subrepo_state` has `known_dirty=20`, `unexpected_dirty=1`. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 pass; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh`. |
| `rtk bash /home/leiwenjun/codex/scripts/final-ready.sh` | PASS_WITH_HOT | Command record passed; Session Coach remains `HOT` due CTX pressure, large delta, dirty worktree/archive and declarative delivery changes. |

## Residual Risk

- Existing broad worktree dirtiness remains from previous batches and reference subrepos; this batch does not clean or commit it.
- `check-all --quick` may still fail strict subrepo state because `agent-dev-kit` has intentional uncommitted ADK doc/template changes.
- External code, install commands, MCP/provider setup, API keys, browser automation, skill managers, cloud/bot setup, hooks and marketplace claims were not executed or imported.
