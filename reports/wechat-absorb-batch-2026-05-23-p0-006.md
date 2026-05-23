# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-006`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: sixth queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable multi-agent workflow, long-running automation, production MCP, memory strategy and plugin packaging boundaries.
- Do not copy Hermes/OpenCode/Codex tutorial code, install commands, marketplace entries, framework claims, cloud deployment commands, bot tokens or sample MCP server implementations into ADK core.
- Keep external frameworks, plugin packages, MCP server snippets and Skill recommendation lists report-only until supply-chain review.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0123 | Hermes multi-agent workflow tutorial | skill-or-workflow-enhancement | MERGE | `planning-execution-loop.md` | medium | Planner/Worker/Critic loop and structured task graph discipline absorbed. |
| wechat-0127 | Hermes cloud deployment and scheduled automation | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Cron/systemd/bot autonomy gates absorbed; cloud commands and bot setup rejected. |
| wechat-0131 | production MCP Server guide | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | high | Health/ready, structured logs, error taxonomy, timeout, inspector and test gates absorbed. |
| wechat-0132 | OpenCode MCP guide | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | high | Transport/config selection and configuration trust-layer priority absorbed. |
| wechat-0135 | Agent memory strategy article | governance-rule-or-script | MERGE | `memory-governance.md` | medium | Memory strategy matrix absorbed; framework code and embedding snippets rejected. |
| wechat-0136 | MCP USB-C overview | skill-or-workflow-enhancement | REFERENCE_ONLY | `mcp-governance.md` | medium | Generic host/client/server and protocol overview already covered. |
| wechat-0137 | Hermes Skills overview | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-curation-delivery.md`, `skill-agent-runtime-model.md` | medium | Generic Skill/Tools/Memory boundary duplicates existing ADK guidance. |
| wechat-0138 | Codex Plugin packaging article | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Plugin promotion sequence and component review absorbed; platform fields remain mapping only. |
| wechat-0143 | Hermes hot Skill list | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-curation-delivery.md`, `security-supply-chain.md` | high | Popularity list remains candidate discovery only. |
| wechat-0144 | stable MCP tool-call guide | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | medium | Precise tool descriptions, error classes and timeout protection absorbed. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-planning-execution-loop`, `adk-parallel-agent-governance`, `adk-security-supply-chain`, `adk-skill-composition-governance`, `mcp-builder`.
- Existing similar docs: `mcp-governance.md`, `memory-governance.md`, `planning-execution-loop.md`, `skill-curation-delivery.md`, `security-supply-chain.md`, `skill-agent-runtime-model.md`.
- Existing similar scripts: `check-memory-governance.sh`, `check-token-budget.sh`, `validate-assets.sh`, `check-skill-routing-conflicts.sh`, `check-wechat-intake-ledger.sh`.
- Result: no new Skill, plugin, MCP server, marketplace, cron runner, memory backend or automation script is justified; accepted content is MERGE into existing governance.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml`, profile, plugin manifest, hook, MCP declaration or Skill metadata changes.
- Workflow conflicts: no change to `propose -> apply -> verify -> review -> archive`.
- Policy conflicts: Hermes/OpenCode/Codex implementation claims, SDK snippets, cloud deployment steps and install commands remain `report-only-until-security-review`.
- Result: pass.

### Redundancy Check

- Merge opportunities: Planner/Worker/Critic, production MCP readiness, plugin promotion, long-running automation and memory strategies all map to existing runbooks.
- Stale or leftover assets: no new script, generated code, dependency file, plugin manifest, MCP config, hook or bot config added.
- Result: no parallel multi-agent workflow, no plugin scaffold, no MCP sample server and no Skill marketplace mirror.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Accepted only as ADK runtime governance, planning loop, MCP production gate, memory governance and supply-chain boundary.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no new script behavior; decisions overlay continues to drive ledger.
- Result: controlled merge.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-006.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/memory-governance.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`
- Rejected/reference-only items and reasons:
  - `wechat-0136`: generic MCP overview duplicates existing protocol/runbook coverage.
  - `wechat-0137`: generic Hermes Skills overview duplicates existing Skill/Agent/MCP boundary guidance.
  - `wechat-0143`: hot Skill list is only candidate discovery; no adoption by popularity.
  - Tutorial code, install commands, bot setup, plugin manifests and cloud deployment commands were not imported.
- External code candidates:
  - Hermes Agent, OpenCode, Codex plugin examples, MCP server samples and Skill marketplace entries remain report-only.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; sixth-batch decisions regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | ADK docs remain within token budget. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance sync passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflicts introduced. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Evidence bundle points to `subrepo_state` fail: `unexpected_dirty=1`, `agent-dev-kit` dirty. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` remains dirty as strict subrepo until committed. |

## Residual Risk

- Several articles cite platform-specific framework behavior, MCP ecosystem statistics, cloud services, bot workflows and fast-moving SDK APIs. None were installed, cloned, promoted or added to manifest.
- This batch is method-only. Runtime adoption still requires `agent-dev-kit -> ~/codex -> ~/.codex` handoff evidence.
