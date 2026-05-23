# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-003`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: third queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable Skill/SOP, AGENTS, task-card, staged-planning and registry-governance methods.
- Do not copy article prose, prompt packs, command snippets, marketplace links or external project claims into ADK core.
- Keep external code, install commands, model/provider claims and private registry products report-only until security and supply-chain review.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0055 | dual-model coding workflow | skill-or-workflow-enhancement | MERGE | `planning-execution-loop.md` | medium | Planner/executor split and staged stop-check discipline absorbed; named model and free-cost claims rejected. |
| wechat-0058 | SkillClaw collective Skill evolution | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-lifecycle.md` | high | Evidence grouping, success invariants, failure fixes and monotonic promotion absorbed; paper/code claims remain report-only. |
| wechat-0059 | private Skill registry article | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `security-supply-chain.md` | high | Private registry treated as distribution boundary, not trust proof. |
| wechat-0060 | enterprise AGENTS practice | skill-or-workflow-enhancement | MERGE | `workspace-maintenance-guide.md`, `project-map.md` | medium | Project rules map-page contract absorbed. |
| wechat-0062 | Codex real-project onboarding | skill-or-workflow-enhancement | MERGE | `workspace-maintenance-guide.md`, `planning-execution-loop.md` | medium | Low-risk pilot, command/env/review/CI discipline merged. |
| wechat-0063 | Codex engineering prompt templates | skill-or-workflow-enhancement | MERGE | `prompt-evolution-delivery.md` | medium | Engineering task-card fields absorbed. |
| wechat-0065 | Agent Skills overview | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-lifecycle.md` | high | Skill structure and description-quality guidance merged; external marketplace/install content rejected. |
| wechat-0069 | SDD Skill combination workflow | skill-or-workflow-enhancement | MERGE | `planning-execution-loop.md` | high | Spec-as-SSOT and staged review chain absorbed under adk-first. |
| wechat-0072 | private Skill repository article | skill-or-workflow-enhancement | REFERENCE_ONLY | `security-supply-chain.md`, `skill-curation-delivery.md` | high | Duplicate of private registry governance already absorbed from wechat-0059. |
| wechat-0074 | project AGENTS template | skill-or-workflow-enhancement | MERGE | `workspace-maintenance-guide.md`, `project-map.md` | medium | Compact AGENTS field set absorbed without copying template text. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-planning-execution-loop`, `adk-skill-composition-governance`, `adk-security-supply-chain`, `adk-requirements-triage`, `adk-task-breakdown`.
- Existing similar docs: `skill-curation-delivery.md`, `workspace-maintenance-guide.md`, `planning-execution-loop.md`, `prompt-evolution-delivery.md`, `security-supply-chain.md`, `templates/context/project-map.md`.
- Existing similar scripts: `validate-assets.sh`, `check-skill-routing-conflicts.sh`, `check-token-budget.sh`, `check-wechat-intake-ledger.sh`.
- Result: no new skill, MCP server, private registry integration, prompt-pack asset or AGENTS replacement is justified; accepted content is MERGE into existing governance.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml`, profile, trigger or skill metadata changes.
- Workflow conflicts: no change to `propose -> apply -> verify -> review -> archive`; staged-planning language reinforces existing gates.
- Policy conflicts: external model/provider claims, install commands, GitHub projects, private registry tooling and marketplace references remain `report-only-until-security-review`.
- Result: pass.

### Redundancy Check

- Merge opportunities: Skill evolution, private registry distribution, project rules, task-card prompt structure and SDD staged execution all map to existing runbooks.
- Stale or leftover assets: no new unreferenced script, Skill, MCP manifest, prompt pack or registry config added.
- Result: no parallel AGENTS template track, no SkillHub/OpenSkills/SkillClaw integration, no Superpowers/gstack default route.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Accepted only as ADK runtime governance, project-rule hygiene and Skill lifecycle rules.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no new script behavior; decisions overlay continues to drive ledger.
- Result: controlled merge.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-003.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/optional-skills/adk-skill-composition-governance/references/adk-skill-lifecycle.md`
  - `agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
  - `agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/templates/context/project-map.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`
- Rejected/reference-only items and reasons:
  - `wechat-0072`: duplicate private Skill registry article; durable governance already absorbed from `wechat-0059`.
  - Named model, platform, registry, marketplace and install-command claims: not durable ADK policy and not supply-chain reviewed.
- External code candidates:
  - SkillClaw, SkillHub, Superpowers/gstack and marketplace/install paths remain report-only.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; third-batch decisions regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | ADK active docs/templates remain within budget. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory/Skill evolution boundary regression passed. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance sync passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflicts introduced. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` remains dirty as strict subrepo until committed. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Evidence bundle points to `subrepo_state` fail: `unexpected_dirty=1`, `agent-dev-kit` dirty. |

## Residual Risk

- Several source articles cite external projects, model versions, private registry commands or marketplace ecosystems. None were installed, cloned, promoted or added to manifest.
- This batch is method-only. Runtime adoption still requires `agent-dev-kit -> ~/codex -> ~/.codex` handoff evidence.
