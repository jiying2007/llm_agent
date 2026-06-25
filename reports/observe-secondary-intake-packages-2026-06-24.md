# Observe Secondary Intake Packages - 2026-06-24

## Scope

本报告记录 `hongmaple/scale-engine` 作为二级 observe intake 包进入持续跟踪的结论。来源为用户指定的 Gitee 仓库 `https://gitee.com/hongmaple/scale-engine`，本次只保留 root-local reference、治理登记和证据链，不启用其运行态组件。

## Candidates

| candidate | capability | decision | reason |
|---|---|---|---|
| scale-engine | gates、evidence、context、queue、hook/orchestrator 等 AI Agent 治理运行时机制 | observe | 治理概念有参考价值，适合持续 fetch/diff/review；但 hook、MCP、CLI、orchestrator、dashboard 属于外部运行态，必须先供应链审查和本地契约设计，不直接接入 |

## Absorbed Practice

| practice | local adaptation | validation |
|---|---|---|
| Runtime Evidence: source, command/result, unresolved failure and final-check evidence must be explicit | `root-local-reference` entries now require source URL, provider, branch, commit, retrieved date, runtime boundaries and linked analysis/absorption/security reports | `scripts/check-oss-intake-ledger.sh` validates metadata, report links and local HEAD commit |
| Deep assessment before long-lived active reference | Active root-local references now require a deep assessment report that separates adopt/adapt/reject/archive-only decisions | `scripts/check-oss-intake-ledger.sh` requires `oss-deep-assessment` evidence for `root-local-reference` entries |

## ASW Mapping

- Agent layer: `agent-dev-kit/agents/security-compliance-reviewer/AGENTS.md` 负责外部资产安全、供应链和运行态边界审查。
- Skill layer: `agent-dev-kit/skills/adk-intake-workflow/SKILL.md` 固化参考源 intake、候选归类和证据闭环。
- Workflow layer: `agent-dev-kit/docs/runbooks/upstream-intake.md` 定义参考仓更新到候选项的同步、diff、采纳矩阵和验证流程。

## Regression Evidence

- `rtk scripts/check-authorized-subrepos.sh .`
- `rtk scripts/check-subrepo-state.sh .`
- `rtk scripts/check-upstream-intake-readiness.sh .`
- `rtk scripts/check-observe-intake-depth.sh .`
- `rtk scripts/check-adoption-matrix-status.sh .`
- `rtk scripts/check-adoption-matrix-structured.sh .`

## Non-Adoption Boundaries

- 不运行 `scale-engine` 的 `npm`、`npx`、`scale`、setup、bootstrap、dashboard、MCP、hook 或 orchestrator。
- 不复制 `.scale/`、`.claude/`、hooks、CLI adapters、role skills 或 MCP 配置到 ADK 或 `~/.codex`。
- 不把 `scale-engine` 的权限模型、运行时写操作或自动编排机制作为默认本地行为。
- 后续若从 observe 转为 adopt，必须补接口契约、deny-path、secret scan、回滚方案和最小试点验证。
