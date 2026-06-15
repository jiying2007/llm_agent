# Observe Secondary Intake Packages - 2026-05-22

## Scope

本报告记录外部上下文/记忆工具的二级 intake 结论。材料来源为用户在 2026-05-22 提供的工具说明，未做远端仓库最新状态核验，因此只进入 `observe`，不进入 `adopt`。

## Candidates

| candidate | capability | decision | reason |
|---|---|---|---|
| codex-agent-mem | Codex 项目连续性记忆、compact context pack、SQLite/MCP 本地治理 | observe | 方向契合上下文连续性，但引入运行时依赖、存储治理和召回污染风险，当前 adk 先用 Markdown 模板与门禁承接方法论 |
| code-session-memory | 跨工具会话索引、语义搜索、MCP/CLI/Web UI 查询 | observe | 适合多工具历史检索，但依赖 embedding/向量索引链路，当前只吸收“历史检索和噪音隔离”原则 |

## ASW Mapping

- Agent layer: `agent-dev-kit/agents/architecture-planner/AGENTS.md` 负责阶段计划、上下文边界和交接判断。
- Skill layer: `agent-dev-kit/skills/adk-token-context-governance/SKILL.md` 固化保真省 Token、上下文预算和原文回退。
- Workflow layer: `agent-dev-kit/docs/runbooks/token-context-governance.md` 给出预算模式、证据保留和高风险原文路径。

## Regression Evidence

- `rtk agent-dev-kit/scripts/check-token-budget.sh`
- `rtk agent-dev-kit/tests/test_token_context_governance.sh`
- `rtk scripts/check-adoption-matrix-status.sh .`
- `rtk scripts/check-adoption-matrix-structured.sh .`

## Non-Adoption Boundaries

- 不默认安装外部 MCP、SQLite、embedding 或向量检索组件。
- 不把完整聊天记录写入长期记忆。
- 不让召回结果覆盖项目级 `AGENTS.md`、runbook 和高风险原文证据。
- 后续若转为 adopt，必须补远端仓库核验、供应链审查、数据保留策略和回滚方案。
