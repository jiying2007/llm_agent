# Observe Secondary Intake Packages（2026-07-23）

## 目的与共同边界

本报告记录 MCP 2026-07-28 RC、OWASP Agentic Skills Top 10 与 VS Code/GitHub Copilot target 的 observe package。三项均已建立本地 staging/crosswalk/watch contract，但不启用 runtime、安装依赖、创建 direct target 或声明外部认证/兼容性。

共同边界：

- 外部来源只保存 metadata 与本地 method-only 映射，不保存受版权保护正文。
- `runtime_enabled=false`，不修改网络、凭证、MCP server、IDE 或用户级 runtime。
- 激活必须有独立 owner decision、固定版本/digest、正负 smoke、安全审查和 rollback。
- 当前回退均为删除 candidate/watch 字段并保留 active contract；无持久数据迁移。

## Package 1：MCP 2026-07-28 RC compatibility staging

- Source：`mcp-2026-07-28-rc`，状态 `observe-method-only`。
- Agent：`agent-dev-kit/agents/architecture-planner/AGENTS.md`，复核 protocol/capability/auth 架构变化。
- Skill：`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md`，冻结 active/candidate、compatibility test 与 rollback contract。
- Workflow：`agent-dev-kit/workflows/external-practice-absorption/WORKFLOW.md`，执行最终规范 freshness、重复、架构、安全和 owner gate。
- 当前落点：`agent-dev-kit/manifests/skill_mcp_dependencies.json` 与 `agent-dev-kit/fixtures/agent-ecosystem-standards/fail/mcp-rc-runtime-enabled.json`。
- 激活阻塞：最终规范实际发布、breaking-change diff、负 fixture、至少一个真实 client/server smoke 和 auth review。

## Package 2：OWASP Agentic Skills Top 10 crosswalk

- Source：`owasp-agentic-skills-top10`，状态 `observe-method-only`。
- Agent：`agent-dev-kit/agents/security-compliance-reviewer/AGENTS.md`，复核 AST01-AST10 与本地控制/剩余风险。
- Skill：`agent-dev-kit/skills/adk-skill-deep-analysis/SKILL.md`，检查 Skill provenance、permission、deny-path、sandbox、scan、drift 和 retire 证据。
- Workflow：`agent-dev-kit/workflows/external-practice-absorption/WORKFLOW.md`，保持 method-only 与不复制格式边界。
- 当前落点：`agent-dev-kit/manifests/skill_reproducibility_contracts.json` 与 `agent-dev-kit/fixtures/agent-ecosystem-standards/fail/agentic-skill-security-incomplete.json`。
- 激活阻塞：项目稳定版本、来源 freshness 和本地 gap review；本 crosswalk 不构成 OWASP 认证。

## Package 3：VS Code / GitHub Copilot target watch

- Source：`vscode-copilot-target-watch`，状态 `observe-method-only`。
- Agent：`agent-dev-kit/agents/architecture-planner/AGENTS.md`，判断是否出现独立 target 的真实业务需求。
- Skill：`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md`，定义 discovery、target-local binding 与 compatibility contract。
- Workflow：`agent-dev-kit/workflows/external-practice-absorption/WORKFLOW.md`，执行来源、供应链、安全、pilot 和退役复核。
- 当前落点：`agent-dev-kit/manifests/external_agent_pattern_contracts.json` 与 `agent-dev-kit/fixtures/agent-ecosystem-standards/fail/coding-agent-target-enabled.json`。
- 激活阻塞：真实 use case、固定 IDE/CLI 版本、安装 smoke、effect eval、安全/permission 复核和 rollback；未满足前 `direct_target_added=false`。

## 验证入口

- `rtk bash agent-dev-kit/tests/test_agent_ecosystem_standards.sh`
- `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict`
- `rtk scripts/check-observe-intake-depth.sh .`
