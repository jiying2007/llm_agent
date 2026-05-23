# WeChat Article Absorption Batch

- Batch ID: `wechat-p1-001`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: all queued P1 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable multi-agent, review, testing, quality and release governance methods into existing ADK assets.
- Keep method-only boundaries: no external repos, Docker, install commands, plugin configuration, model API snippets, marketplace claims or platform-specific semantics.
- Prefer MERGE into existing ADK runbooks, skills and templates; use REFERENCE_ONLY for duplicate overviews and REJECT for runtime or supply-chain unsafe items.

## Candidates

| id | theme | decision | target | evidence |
|---|---|---|---|---|
| wechat-0012 | external multi-agent runtime | REJECT | `none` | OpenClaw/Gateway/Docker/install/server runtime rejected; overlapping dispatch method covered by safer items. |
| wechat-0025 | Agent identity | MERGE | `skill-agent-runtime-model.md`, `worker-contract.md` | Explicit Agent/runtime identity and split-new-agent threshold absorbed. |
| wechat-0047 | test quality | MERGE | `adk-test-strategy`, `security-supply-chain.md` | Real-world test boundaries and least-privilege AI execution environment absorbed. |
| wechat-0061 | code review | MERGE | `adk-code-review-loop`, `adk-commit-pr-quality-gate` | Review risk checklist and high-risk owner confirmation absorbed. |
| wechat-0070 | AI output ownership | MERGE | `adk-commit-pr-quality-gate`, `adk-worktree-governance` | Human owner, protected-branch and plan-schema/worktree gates absorbed. |
| wechat-0084 | multi-agent overview | REFERENCE_ONLY | runtime/parallel docs | Duplicate overview; no new durable gate. |
| wechat-0094 | planner schema | MERGE | `planning-execution-loop.md`, `worker-contract.md`, `adk-worktree-governance` | Required fields, `dependsOn`, DAG, context budget and retry budget gates absorbed. |
| wechat-0113 | subagent dispatch | MERGE | `skill-agent-runtime-model.md`, `adk-parallel-agent-governance` | High-risk subagent explicit dispatch contract absorbed. |
| wechat-0130 | tool guard | MERGE | `security-supply-chain.md`, `planning-execution-loop.md`, `adk-commit-pr-quality-gate` | Deterministic allow/deny or approval gate for risky actions absorbed. |
| wechat-0150 | external React Doctor | REFERENCE_ONLY | quality/verification gates | External `npx` path rejected; static-quality idea remains covered by deterministic gates. |
| wechat-0156 | JetBrains plugin | REJECT | `none` | Plugin, LLM/API/proxy and issue integration exceed method-only boundary. |
| wechat-0182 | review/security overview | REFERENCE_ONLY | review/security gates | Duplicate guidance; no new stable rule. |
| wechat-0245 | test/quality overview | REFERENCE_ONLY | test/verification gates | Existing ADK gates cover durable method. |
| wechat-0253 | report schema | MERGE | `worker-contract.md`, `adk-parallel-agent-governance`, runtime model | Verified facts, inferences, evidence and risks separation absorbed. |
| wechat-0277 | quality overview | REFERENCE_ONLY | `none` | No new durable ADK gate. |
| wechat-0278 | quality overview | REFERENCE_ONLY | `none` | No new durable ADK gate. |
| wechat-0280 | quality overview | REFERENCE_ONLY | `none` | No new durable ADK gate. |
| wechat-0282 | model switch | MERGE | `token-context-governance.md`, `security-supply-chain.md`, `adk-verification-before-completion` | Model-switch local regression and no gate relaxation rule absorbed. |
| wechat-0289 | multi-agent overview | REFERENCE_ONLY | runtime/parallel docs | Duplicate runtime guidance. |
| wechat-0306 | process strength | MERGE | `planning-execution-loop.md` | Lightweight/standard/strict gate selection absorbed. |
| wechat-0310 | resume and migration | MERGE | `token-context-governance.md`, `planning-execution-loop.md`, `adk-commit-pr-quality-gate` | Failed-path carryover, repeated-attempt delta, DB migration and API deletion gates absorbed. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-parallel-agent-governance`, `adk-code-review-loop`, `adk-commit-pr-quality-gate`, `adk-test-strategy`, `adk-verification-before-completion`, `adk-worktree-governance`.
- Existing similar docs/templates: `planning-execution-loop.md`, `security-supply-chain.md`, `token-context-governance.md`, `skill-agent-runtime-model.md`, `templates/planning/worker-contract.md`.
- Result: no new Skill, Agent, plugin, MCP server, subrepo, install path or runtime connector is justified.

### Conflict Check

- Routing conflicts: none introduced; no frontmatter trigger changes, manifest changes, profile changes or MCP declarations.
- Runtime conflicts: external Docker, JetBrains plugin, `npx`, OpenClaw/Gateway, API/proxy and issue integration paths were rejected or reference-only.
- Method conflicts: child/parent agent boundaries were written as worker contract and explicit dispatch gates, not as autonomous runtime permissions.

### Redundancy Check

- Duplicate multi-agent and quality overviews remain `REFERENCE_ONLY`.
- New durable deltas are limited to gates: plan schema, report schema, owner/review responsibility, model-switch regression, context-resume failure paths and risky tool approval.
- No generated code, dependency file, lockfile, plugin manifest, marketplace entry or cloud/bot setup was added.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p1-001.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/docs/runbooks/token-context-governance.md`
  - `agent-dev-kit/docs/skill-agent-runtime-model.md`
  - `agent-dev-kit/templates/planning/worker-contract.md`
  - `agent-dev-kit/skills/adk-parallel-agent-governance/SKILL.md`
  - `agent-dev-kit/skills/adk-code-review-loop/SKILL.md`
  - `agent-dev-kit/skills/adk-commit-pr-quality-gate/SKILL.md`
  - `agent-dev-kit/skills/adk-worktree-governance/SKILL.md`
  - `agent-dev-kit/skills/adk-test-strategy/SKILL.md`
  - `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; generated ledger matches decisions overlay. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill line budget remains below 140; docs remain within configured limits. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflict introduced. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No root whitespace errors. |
| `rtk bash -lc "git -C agent-dev-kit diff --check"` | PASS | No ADK subrepo whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | `subrepo_state` fail: `dirty=21`, `known_dirty=20`, `unexpected_dirty=1`. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` due dirty subrepo state. |

## Residual Risk

- This batch includes high-risk external-code mentions; all external runtime content remains rejected or reference-only unless separately reviewed through supply-chain governance.
- Runtime adoption still requires the `agent-dev-kit -> ~/codex -> ~/.codex` source-to-live chain and live profile validation.
