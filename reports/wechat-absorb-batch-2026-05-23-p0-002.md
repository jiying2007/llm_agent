# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-002`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: second queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable Skill/SOP, context, MCP and project-rule governance methods.
- Do not copy article prose, tutorial code, install commands, tool lists or marketplace claims into ADK core.
- Keep external repositories, skill collections, MCP recommendations and automation commands report-only until supply-chain review.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0026 | skill-creator practice | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-lifecycle.md` | medium | Adds reuse threshold, examples-first and validation-after-creation guidance. |
| wechat-0027 | GSD context rot article | governance-rule-or-script | MERGE | `planning-execution-loop.md`, `token-context-governance.md` | high | External project remains report-only; absorb thin-orchestrator and stage-state method. |
| wechat-0037 | five Skill patterns | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-lifecycle.md` | medium | Existing pattern taxonomy enhanced rather than duplicated. |
| wechat-0038 | duplicate five-pattern article | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-composition-governance` | medium | Confirms pattern selection and hard-gate rule. |
| wechat-0040 | workflow automation | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Cron/heartbeat/webhook commands rejected; autonomous-trigger boundary absorbed. |
| wechat-0045 | `.cursorrules` project rules | skill-or-workflow-enhancement | MERGE | `workspace-maintenance-guide.md` | medium | Mapped to AGENTS/project-context governance; no tool-specific parallel policy. |
| wechat-0046 | external skill marketplace | skill-or-workflow-enhancement | REFERENCE_ONLY | `security-supply-chain.md`, `skill-curation-delivery.md` | high | Marketplace and install commands need per-skill review before adoption. |
| wechat-0051 | IP visual production Skill | skill-or-workflow-enhancement | REFERENCE_ONLY | `skill-curation-delivery.md` | high | Domain-specific visual pipeline is outside ADK core; generic Generator/Reviewer method already covered. |
| wechat-0052 | skill development practice | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md`, `adk-skill-lifecycle.md` | medium | Absorbs atomicity and no implicit skill-to-skill coupling. |
| wechat-0054 | MCP recommendations | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Tiered MCP enablement and least-privilege review; no server installed. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-skill-composition-governance`, `adk-context-engineering`, `adk-planning-execution-loop`, `adk-security-supply-chain`.
- Existing similar docs: `skill-curation-delivery.md`, `mcp-governance.md`, `workspace-maintenance-guide.md`, `planning-execution-loop.md`.
- Existing similar scripts: `check-skill-routing-conflicts.sh`, `check-token-budget.sh`, `check-runtime-routing.sh`, `validate-assets.sh`.
- Result: no new skill or MCP registry is justified; accepted items are MERGE into existing governance.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml` or trigger changes.
- Workflow conflicts: no change to `propose -> apply -> verify -> review -> archive`.
- Policy conflicts: external install commands remain report-only; autonomous triggers are classified as high-risk.
- Result: pass.

### Redundancy Check

- Merge opportunities: Skill patterns and Skill-as-SOP rules merge into curation/composition lifecycle docs.
- Stale or leftover assets: no temporary files or unused templates added.
- Result: no parallel `.cursorrules`, MCP recommendation list, skill marketplace mirror or IP-specific skill.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Accepted only as ADK runtime governance and skill lifecycle rules.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no new script behavior; decisions overlay continues to drive ledger.
- Result: controlled merge.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-002.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/optional-skills/adk-skill-composition-governance/references/adk-skill-lifecycle.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
- Rejected/reference-only items and reasons:
  - `wechat-0046`: external skill marketplace cannot be adopted without per-skill security and license review.
  - `wechat-0051`: IP visual production workflow is outside ADK embedded core and duplicates generic Generator/Reviewer method.
- External code candidates:
  - GSD, awesome skill collections, OpenClaw automation commands and MCP servers remain report-only.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; second-batch decisions regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | ADK docs remain within active line budgets. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance sync passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflicts introduced. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` is dirty as a strict subrepo until its changes are committed. |

## Residual Risk

- Several source articles cite external projects, MCP servers or command snippets. None were installed or promoted.
- Second-batch changes are policy/runbook additions only; actual runtime adoption still requires `agent-dev-kit -> ~/codex -> ~/.codex` handoff evidence.
