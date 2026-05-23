# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-008`
- Date: 2026-05-23
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Scope: P0 Skill/Agent/SOP and context-memory-token candidates from `wechat-0190` through selected adjacent P0 items up to `wechat-0238`
- Mode: apply

## Batch Goals

- Process a larger P0 batch with read-only subagent analysis and single-writer integration.
- Absorb only durable ADK method gates, boundaries, templates, or verification rules.
- Keep external code, install flows, plugin manifests, MCP server implementations, hooks, marketplace rankings, cloud/bot setup, SDK snippets and platform-specific API semantics report-only.
- Prefer merge into existing ADK runbooks, runtime model and templates instead of adding parallel assets.

## Parallel Governance

- Parallel Suitability: yes.
- Subagent split:
  - Framework/Skill/external comparison group: `wechat-0190`, `wechat-0193`, `wechat-0194`, `wechat-0213`, `wechat-0215`, `wechat-0216`, `wechat-0219`, `wechat-0227`.
  - Workflow/automation/layering group: `wechat-0196`, `wechat-0197`, `wechat-0204`, `wechat-0206`, `wechat-0208`, `wechat-0231`, `wechat-0232`, `wechat-0233`, `wechat-0234`, `wechat-0235`.
  - Memory/context group: `wechat-0200`, `wechat-0210`, `wechat-0229`, `wechat-0230`, `wechat-0237`, `wechat-0238`.
- Write model: subagents returned read-only recommendations; main Codex performed all file edits.
- Shared-write freeze: no subagent modified reports, ADK runbooks, manifests, root configs, generated ledger or `~/.codex`.
- Integration rule: subtask completion was not treated as final completion; this report records unified ledger regeneration and targeted gates.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0190 | Hermes Agent team collaboration Skill | collaboration runtime gates | MERGE | `skill-agent-runtime-model.md`; `security-supply-chain.md` | high | Added memory scope, access control, adapter parity and rollback/audit gates. |
| wechat-0193 | AI Agent framework comparison | framework comparison | REFERENCE_ONLY | `skill-curation-delivery.md`; `planning-execution-loop.md` | high | External repo/version/community claims are unstable and covered by existing ADK lifecycle gates. |
| wechat-0194 | Agent Skills vs Superpowers comparison | framework/install comparison | REFERENCE_ONLY | `skill-curation-delivery.md` | high | Duplicates existing reuse threshold, lifecycle and composition boundaries. |
| wechat-0196 | Five automation scenarios | scenario list | REFERENCE_ONLY | `planning-execution-loop.md` | medium | Efficiency claims and examples lack new stable state/recovery/approval gates. |
| wechat-0197 | MCP/CLI/Skill/Agent/Workflow relationship | layer boundary | MERGE | `skill-agent-runtime-model.md` | medium | Added CLI/script and Automation distinctions. |
| wechat-0200 | Agent memory design | memory evolution gate | MERGE | `memory-governance.md` | high | Added fact extraction plus ADD/UPDATE/DELETE/NONE decision boundary. |
| wechat-0204 | Hermes hidden features | platform feature set | REFERENCE_ONLY | `skill-curation-delivery.md`; `memory-governance.md`; `mcp-governance.md` | medium | Skill Factory, memory and autonomous trigger governance already cover durable method. |
| wechat-0206 | Hermes workflow orchestration | workflow examples | REFERENCE_ONLY | `planning-execution-loop.md` | medium | YAML/status/parallel examples duplicate existing state machine and resume guidance. |
| wechat-0208 | Hermes Skill zero-to-deploy tutorial | platform implementation tutorial | REJECT | none | high | Install, Hub, CLI, tool registration, API and GitHub content conflict with method-only boundary. |
| wechat-0210 | Hermes self-evolving skills and memory | memory/profile isolation | MERGE | `memory-governance.md`; `token-context-governance.md`; `skill-agent-runtime-model.md`; `security-supply-chain.md` | medium | Added resident-memory, on-demand session search and profile isolation boundaries. |
| wechat-0213 | Antigravity Skills recommendations | candidate discovery | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | high | External links and install paths remain discovery-only. |
| wechat-0215 | Superpowers flow/TDD/debugging | process overlap | REFERENCE_ONLY | `planning-execution-loop.md`; `skill-curation-delivery.md` | medium | Existing ADK planning, debugging and verification routes cover stable method. |
| wechat-0216 | Cross-platform Skill runtime | runtime compatibility gate | MERGE | `skill-curation-delivery.md`; `skill-agent-runtime-model.md` | medium | Added discovery timing, rule precedence, memory/context injection, subagent and sandbox/approval/hook checks. |
| wechat-0219 | Codex advanced tutorial | platform config tutorial | REJECT | none | high | Unverified config fields, commands, CI/CD snippets, marketplace and efficiency claims rejected from ADK core. |
| wechat-0227 | Skills resource list | candidate discovery | REFERENCE_ONLY | `skill-curation-delivery.md`; `security-supply-chain.md` | high | Repos, package managers, marketplace and popularity claims remain report-only. |
| wechat-0229 | Long-term memory practice | memory candidate inbox | MERGE | `memory-governance.md`; `memory-candidate.md`; `security-supply-chain.md` | high | Added scoring, sensitive blocking, conflict_review and project/global scope boundaries. |
| wechat-0230 | Cognee graph+vector memory | tool promotion | REFERENCE_ONLY | `memory-governance.md` | medium | Existing memory governance treats graph/vector as implementation options. |
| wechat-0231 | Skill development archive | learning index | REFERENCE_ONLY | `skill-curation-delivery.md` | low | Reference-only learning path; no new durable ADK gate. |
| wechat-0232 | Skill development/packaging summary | generic Skill guidance | REFERENCE_ONLY | `skill-curation-delivery.md` | low | Duplicates ownership, scope, dependency and verification gates. |
| wechat-0233 | Agent autonomy and scheduled tasks | autonomous trigger boundary | MERGE | `skill-agent-runtime-model.md`; `mcp-governance.md` | medium | Added capability versus autonomous operation boundary. |
| wechat-0234 | Automation/Workflow/Agent distinction | abstraction selection | MERGE | `skill-agent-runtime-model.md` | medium | Added lowest-sufficient-abstraction rule. |
| wechat-0235 | Dify/n8n workflow setup | low-code platform setup | REJECT | none | high | Platform setup and workflow templates are prohibited install/config semantics. |
| wechat-0237 | Context engineering | context packet/project map | MERGE | `token-context-governance.md`; `project-map.md`; `skill-agent-runtime-model.md` | medium | Added short self-contained context packets and context rot stop/rebuild rule. |
| wechat-0238 | Memory recall and forgetting | recall ranking/forgetting | MERGE | `memory-governance.md` | medium | Added multi-factor recall ranking and auditable demotion/deletion thresholds. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-skill-composition-governance`, `adk-planning-execution-loop`, `adk-security-supply-chain`, `adk-runtime-router`.
- Existing similar docs: `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`, `agent-dev-kit/docs/skill-agent-runtime-model.md`, `agent-dev-kit/docs/runbooks/memory-governance.md`, `agent-dev-kit/docs/runbooks/token-context-governance.md`, `agent-dev-kit/docs/runbooks/mcp-governance.md`, `agent-dev-kit/docs/runbooks/security-supply-chain.md`.
- Existing similar templates: `agent-dev-kit/templates/memory/memory-candidate.md`, `agent-dev-kit/templates/context/project-map.md`.
- Result: duplicate framework comparisons, generic Skill summaries, resource lists and tool promotions were kept reference-only; only missing durable gates were merged.

### Conflict Check

- Routing or trigger conflicts: none; no new Skill, Workflow, manifest route or trigger was added.
- Workflow conflicts: none; added rules clarify abstraction level, autonomous trigger ownership and context handoff boundaries.
- Memory conflicts: none; candidate/inbox scoring and isolation rules strengthen existing memory write governance.
- Policy conflicts: none; external code, install commands, cloud/bot setup, platform runtime fields and marketplace claims stayed report-only or were rejected.
- Result: pass pending final validation.

### Redundancy Check

- Merge opportunities: collaboration runtime gates, CLI/script layer boundary, memory fact/event gate, resident-memory/session-search boundary, cross-host runtime compatibility, candidate memory scoring, autonomous trigger boundary, context packet/project map discipline, recall/forgetting audit.
- Stale or leftover assets: none added.
- Result: pass pending final validation.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Generic AI-agent platform material remains reference-only; reusable governance gates fit ADK asset/runtime delivery.
- Affects manifest or routing: no.
- Affects generated assets: yes, ledger and next-batch report regenerated from decisions TSV.
- Affects `~/.codex`: no.
- Result: pass pending final validation.

## Implementation

- Files changed:
  - `agent-dev-kit/docs/runbooks/memory-governance.md`
  - `agent-dev-kit/docs/runbooks/token-context-governance.md`
  - `agent-dev-kit/docs/skill-agent-runtime-model.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/templates/memory/memory-candidate.md`
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-008.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - root routing manifests
  - `~/.codex` runtime config
  - external repos, MCP servers, plugin manifests, hooks, install scripts, CI workflows and SDK snippets
- Rejected/reference-only items and reasons:
  - Framework comparisons and generic Skill summaries: existing ADK lifecycle and planning gates are stricter.
  - Resource lists and marketplace articles: discovery-only, not adoption evidence.
  - Platform tutorials: install/config/API semantics are not imported into ADK core.
  - Low-code workflow setups: outside method-only absorption boundary.
- External code candidates:
  - `wechat-0190`, `wechat-0193`, `wechat-0194`, `wechat-0208`, `wechat-0213`, `wechat-0219`, `wechat-0227`, `wechat-0229`, `wechat-0235`, `wechat-0238` remain `report-only-until-security-review` where ledger marks external code.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/generate-wechat-intake-ledger.sh` | PASS | Regenerated ledger and next-batch report; `articles=313`, `external_code_mentions=99`. |
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; generated ledger is fresh. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance checks pass after new write/candidate/recall rules. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill/doc budget limits pass. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No new routing conflicts. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk bash -lc "git -C agent-dev-kit diff --check"` | PASS | No whitespace errors inside the ADK subrepo after cleaning `project-map.md`. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Bundle generated with `status=needs-fix`; `subrepo_state` has `known_dirty=20`, `unexpected_dirty=1`. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 pass; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh`. |
| `rtk bash /home/leiwenjun/codex/scripts/final-ready.sh` | PASS_WITH_HOT | Command record passed; Session Coach remains `HOT` due dirty worktree/archive and declarative delivery changes. |

## Residual Risk

- Existing broad worktree dirtiness remains from previous batches and reference subrepos; this batch does not clean or commit it.
- `check-all --quick` may still fail strict subrepo state because `agent-dev-kit` has intentional uncommitted changes from the absorption batches.
- External code, install commands, MCP server examples, platform-specific fields, marketplace claims and low-code platform setup remain report-only or rejected and were not executed.
