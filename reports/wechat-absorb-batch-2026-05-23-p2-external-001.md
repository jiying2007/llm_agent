# WeChat Article Absorption Batch

- Batch ID: `wechat-p2-external-001`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: all queued `P2-external-code-candidates`
- Mode: apply

## Batch Goals

- Triage high-risk external-code candidates without importing external repositories, install commands, plugins, provider configuration, SDK snippets, marketplaces, bots, mobile automation or cloud setup.
- Absorb only durable method gates already compatible with existing ADK assets.
- Keep source-specific tools, project names, rankings, prices, benchmarks and runtime claims out of core assets.

## Decision Summary

| Decision | Count | Meaning |
|---|---:|---|
| MERGE | 3 | Method-only durable gate absorbed into existing ADK assets. |
| REFERENCE_ONLY | 19 | Useful background or duplicate method, no new gate. |
| REJECT | 26 | External runtime, install, marketplace, provider, bot, mobile automation or unsafe permission content. |

## MERGE Items

| id | target | absorbed gate |
|---|---|---|
| wechat-0035 | `agent-dev-kit/docs/runbooks/security-supply-chain.md` | GUI/Computer Use/desktop/mobile automation requires low-privilege isolation, explicit application allowlist, sensitive-app denial and human approval for destructive, external-send or payment-like actions. |
| wechat-0077 | `agent-dev-kit/skills/adk-runtime-router/SKILL.md`, `agent-dev-kit/docs/skill-agent-runtime-model.md` | Router responsibility split: recall/reasoning/ranking/feedback are separate; LLM output is candidate understanding, while execution must be deterministic, structured or owner-approved. Routing changes require benchmark, negative-boundary and regression evidence. |
| wechat-0248 | `agent-dev-kit/skills/adk-systematic-debugging/SKILL.md` | AI tool/CLI behavior drift must be debugged with fixed reproduction, documentation/version comparison, source/config decision point and git timeline before root-cause claims. |

## Rejected Or Reference-Only Groups

- Runtime setup rejected: OpenCode, Hermes deployment, Codex proxy, provider relay, API keys, WSL, gateway, cloud, Docker, curl installers, VSCode/JetBrains/plugin installs and model configuration.
- Autonomous/control-plane risks rejected: message bots, Feishu/WeChat remote control, Termux/ADB/UiAutomator, CDP injection, yolo/full-power mode, webhook, cron, autostart and 24x7 agent teams.
- Marketplace and popularity content rejected or reference-only: star counts, ranking lists, must-install plugins, framework comparisons, pricing, benchmark and cost claims.
- Duplicate methodology kept reference-only: Spec/TDD/review/verification/worktree/state/resume/wave/context governance already exists in ADK.

## Full-Repository Comparison

### Duplicate Check

- Existing similar assets: `security-supply-chain.md`, `mcp-governance.md`, `planning-execution-loop.md`, `skill-agent-runtime-model.md`, `adk-runtime-router`, `adk-systematic-debugging`, `adk-worktree-governance`, `adk-verification-before-completion`.
- Result: no new Skill, plugin, MCP server, profile, hook, subrepo or runtime connector is justified.

### Conflict Check

- No manifest, routing metadata, profile, MCP declaration or dependency file was changed.
- MERGE items are written as stricter gates, not as permission to enable GUI automation, routing classifiers or external debugging tools.
- External runtime claims remain `report-only-until-security-review`.

### Architecture Boundary

- Fits ADK boundary only as governance, routing and debugging method.
- Does not alter the `agent-dev-kit -> ~/codex -> ~/.codex` source-to-live chain.
- Does not add external code to `subrepos/registry.csv` or `subrepos/adoption-matrix.md`.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p2-external-001.md`
  - `agent-dev-kit/docs/runbooks/security-supply-chain.md`
  - `agent-dev-kit/docs/skill-agent-runtime-model.md`
  - `agent-dev-kit/skills/adk-runtime-router/SKILL.md`
  - `agent-dev-kit/skills/adk-systematic-debugging/SKILL.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; generated ledger matches decisions overlay. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | Skill and doc budgets passed; `adk-systematic-debugging` remains below 140 lines. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflict introduced. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | Strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance files are in sync. |
| `rtk bash -lc "git diff --check"` | PASS | No root whitespace errors. |
| `rtk bash -lc "git -C agent-dev-kit diff --check"` | PASS | No ADK subrepo whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | `subrepo_state` fail: `dirty=21`, `known_dirty=20`, `unexpected_dirty=1`. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` due dirty subrepo state. |

## Residual Risk

- This batch did not perform network, license, SBOM, CVE, signature, dependency or package-manager verification for external repositories. Decisions are method-only and based on local archived articles plus ADK governance.
- External-code candidates remain unsafe to install or promote unless a separate supply-chain review is opened for a specific repository and version.
