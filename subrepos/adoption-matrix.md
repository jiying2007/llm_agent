# 子仓借鉴评估矩阵（SSOT）

## 使用说明

1. 每个候选项对应一行，不跨行合并多个能力点。
2. `决策` 仅允许：`adopt`、`observe`、`reject`。
3. `验收状态` 仅允许：`done`、`pending`、`blocked`。
4. `证据` 必须包含可复现命令或报告路径。
5. `回灌目标` 默认填写 `agent-dev-kit`，如需试跑可追加 `codex`。

## 当前记录（全量治理）

| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-05-02 | superpowers | workflow-core | 生命周期流程主干（brainstorm/plan/verify/review） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows.md |
| 2026-05-02 | superpowers-zh | workflow-core | 中文触发词与流程表达标准化 | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/AGENTS.md |
| 2026-05-02 | OpenSpec | workflow-core | 变更工件命名和状态流转硬约束 | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows.md |
| 2026-05-02 | artifact-gated-agents | workflow-core | 轻量 artifact 门禁模板（ImplementationPlan/ReviewReport/TestReport） | 高 | 中 | 低 | adopt | done | agent-dev-kit, codex | agent-dev-kit/optional-skills/artifact-gated-lite/SKILL.md |
| 2026-05-02 | agency-agents-zh | agent-ecosystem | 角色职责矩阵与术语体系（角色覆盖丰富，保留为术语与职责参考，不直接并入核心） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-02 | agent-skills | agent-ecosystem | 技能触发路由与生命周期映射（流程完备，保留方法论参考） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/agent-skill-catalog.md |
| 2026-05-02 | skills | agent-ecosystem | skills CLI 目录约定与安装入口（安装机制已吸收为兼容性约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/feature-delivery.md |
| 2026-05-02 | mattpocock-skills | agent-ecosystem | 小技能组合范式与 deprecated 分层治理 | 中 | 中 | 低 | adopt | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | hermes-collaboration-skill | agent-ecosystem | 多人协作文档模板与 runbook 化结构（文档范式已吸收，以 runbook 方式落地） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/optional-skills/cross-team-handoff/SKILL.md |
| 2026-05-02 | hermes-team-skill | agent-ecosystem | 团队技能升级包直接引入 | 低 | 中 | 中 | reject | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | codex-skill-spec | skill-pool | 轻量技能模板与最小闭环脚手架（文档化模板已吸收，不直接合并实现） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/spec-chain-delivery.md |
| 2026-05-02 | Migrationed_skills | skill-pool | 历史技能池候选筛选机制（资产池价值高，保留为按需提取来源） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/skill-curation-delivery.md |
| 2026-05-02 | hermes-agent | delivery | 大型 Agent 工程目录职责与发布脚本治理（已吸收为大仓交付触点模板与收口约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/large-platform-delivery.md |
| 2026-05-02 | AUBB-Server | delivery | 业务闭环中的验证证据写法（已吸收为命令级 Evidence Index 交付标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/evidence-index-delivery.md |
| 2026-05-02 | arthas | delivery | 贡献规范与发布质量门槛模板（已吸收为评审分级与发布门禁标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/release-hardening.md |
| 2026-05-02 | autonomous-vehicle-dev | delivery | 阶段式迁移验收与里程碑拆分（已吸收为阶段迁移 runbook 模板） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/migration-stage-delivery.md |
| 2026-05-02 | ai-coding-guide | knowledge | 场景化工作流导览与风险提示清单（方法论导览价值高，已纳入 adopt） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/bugfix-delivery.md |
| 2026-05-02 | prompts | knowledge | 提示词资产的轻量演进机制（保留参考，不进入强约束） | 低 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md |
| 2026-05-02 | auto-research | knowledge | 负结果留痕与复盘机制（研究/工程双场景留痕机制可复用） | 中 | 低 | 低 | adopt | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | dotfiles | config | 最小变更 + 基线校验策略（配置基线思想已吸收为治理约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/config-baseline-governance.md |
| 2026-05-02 | vscode-codex-settings | config | 配置摘要与可追溯验证命令格式（配置可审计思路可复用） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/codex-settings-audit.md |
| 2026-05-02 | codex | runtime-target | control/scripts/catalog/doctor 真实运行闭环验证 | 高 | 中 | 中 | adopt | done | codex, agent-dev-kit | reports/codex-pilot-report.md |
| 2026-05-02 | agent-dev-kit | adk-core | 压实总门禁编排（metadata/routing/doc-sync/full-suite/pilot）与发布级回归基线 | 高 | 中 | 低 | adopt | done | agent-dev-kit, codex | reports/adk-production-landing-implementation-2026-05-02.md |
| 2026-05-02 | codex-cookbook | knowledge | Codex 实战模板与 cookbook 任务样例（经验模板已吸收，不并入 core 流程强约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-02 | codex_doc_cn | knowledge | 文档镜像同步机制（远端不可达，暂不吸收；解除条件：仓库恢复可访问或提供可用替代镜像） | 低 | 中 | 中 | reject | blocked | agent-dev-kit | subrepos/registry.csv |
| 2026-05-08 | workspace | knowledge | 维护指南（日常健康检查、adk 压实检查、生产级放行检查） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md |
| 2026-05-08 | workspace | delivery | GitLab Runner 安装配置（Debian/RHEL/Docker 三种方式） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/gitlab-runner-setup.md |
| 2026-05-08 | workspace | knowledge | Pilot 试跑完整证据链（六类试跑场景 artifact 记录） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/codex-pilot-evidence.md |
| 2026-05-08 | workspace | knowledge | 27 条候选能力完整评估矩阵（含决策、验收状态、证据） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference-adoption-matrix.md |
| 2026-05-08 | workspace | knowledge | "道法术器"四层方法论框架（哲学→组织→战术→工具） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/best-practices-cookbook.md |
| 2026-05-08 | workspace | knowledge | 9 款工具速查表（30 秒决策矩阵 + 能力对比表） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/tool-cheatsheet.md |
| 2026-05-08 | workspace | delivery | 子仓治理脚本完整使用手册（24+ 脚本用法） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-scripts-guide.md |
| 2026-05-08 | workspace | workflow-core | 完整 Artifact 门禁协议（21 类标签、12 角色矩阵） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/artifact-gated-protocol-full.md |
| 2026-05-08 | workspace | adk-core | 意图路由表 + 子仓清单 + 优先级门禁治理全景 | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workspace-governance.md |
| 2026-05-08 | superpowers | workflow-core | 贡献规范（94% PR 拒绝率策略） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/superpowers-agents.md |
| 2026-05-08 | workspace | workflow-core | Artifact 门禁协议模式（统一标签+状态+交接） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-artifact-gating/SKILL.md |
| 2026-05-08 | workspace | workflow-core | Pilot 试跑框架模式（场景+证据+门禁） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-pilot-framework/SKILL.md |
| 2026-05-08 | workspace | workflow-core | 子仓接入工作流模式（扫描+分析+决策） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-intake-workflow/SKILL.md |

## 模板

| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|

