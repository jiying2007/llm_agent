# Observe Secondary Intake Packages - 2026-06-29

本报告记录 2026-06-29 两个长期观察参考源的 ADK 回灌包。目标是把外部实践压缩成 method-only ADK 资产，而不是启用外部 runtime、hook、MCP、插件或全局安装。

## Packages

| Source | Observe scope | ADK landing |
|---|---|---|
| `oh-my-codex` | goal / worktree / doctor / release evidence / state scope | `agent-dev-kit/docs/runbooks/codex-runtime-method-boundary.md`; `agent-dev-kit/skills/adk-runtime-router/SKILL.md`; `agent-dev-kit/skills/adk-worktree-governance/SKILL.md`; `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` |
| `planning-with-files` | active plan / findings / progress / attestation / excluded context | `agent-dev-kit/optional-skills/adk-planning-execution-loop/SKILL.md`; `agent-dev-kit/skills/adk-context-compress-handoff/SKILL.md`; `agent-dev-kit/templates/context/continuity-attestation.md` |

## Shared Agent / Workflow Evidence

- Agent evidence: `agent-dev-kit/agents/architecture-planner/AGENTS.md`
- Workflow evidence: `agent-dev-kit/docs/runbooks/codex-runtime-method-boundary.md`; `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
- Skill evidence: `agent-dev-kit/skills/adk-runtime-router/SKILL.md`; `agent-dev-kit/optional-skills/adk-planning-execution-loop/SKILL.md`

## Boundary

- No upstream runtime execution.
- No external hooks, daemon, MCP server, plugin install or global package install.
- No direct writes to user runtime directories.
- Existing ADK assets were extended before creating new assets.

## Verification Plan

- `rtk bash scripts/check-adk-target-evidence.sh .`
- `rtk bash scripts/check-observe-intake-depth.sh .`
- `rtk bash agent-dev-kit/scripts/validate-assets.sh --strict`
- `rtk bash agent-dev-kit/tests/run_all.sh`
