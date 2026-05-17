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
| 2026-05-02 | agency-agents-zh | agent-ecosystem | 角色职责矩阵与术语体系（角色覆盖丰富，保留为术语与职责参考，不直接并入核心） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-02 | agent-skills | agent-ecosystem | 技能触发路由与生命周期映射（流程完备，保留方法论参考） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/agent-skill-catalog.md |
| 2026-05-02 | skills | agent-ecosystem | skills CLI 目录约定与安装入口（安装机制已吸收为兼容性约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/feature-delivery.md |
| 2026-05-02 | mattpocock-skills | agent-ecosystem | 小技能组合范式与 deprecated 分层治理 | 中 | 中 | 低 | adopt | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | hermes-collaboration-skill | agent-ecosystem | 多人协作文档模板与 runbook 化结构（文档范式已吸收，以 runbook 方式落地） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/optional-skills/cross-team-handoff/SKILL.md |
| 2026-05-02 | Migrationed_skills | skill-pool | 历史技能池候选筛选机制（资产池价值高，保留为按需提取来源） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/skill-curation-delivery.md |
| 2026-05-02 | hermes-agent | delivery | 大型 Agent 工程目录职责与发布脚本治理（已吸收为大仓交付触点模板与收口约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/large-platform-delivery.md |
| 2026-05-02 | AUBB-Server | delivery | 业务闭环中的验证证据写法（已吸收为命令级 Evidence Index 交付标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/evidence-index-delivery.md |
| 2026-05-02 | arthas | delivery | 贡献规范与发布质量门槛模板（已吸收为评审分级与发布门禁标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/release-hardening.md |
| 2026-05-02 | ai-coding-guide | knowledge | 场景化工作流导览与风险提示清单（方法论导览价值高，已纳入 adopt） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/bugfix-delivery.md |
| 2026-05-02 | prompts | knowledge | 提示词资产的轻量演进机制（保留参考，不进入强约束） | 低 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md |
| 2026-05-02 | auto-research | knowledge | 负结果留痕与复盘机制（研究/工程双场景留痕机制可复用） | 中 | 低 | 低 | adopt | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | dotfiles | config | 最小变更 + 基线校验策略（配置基线思想已吸收为治理约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/config-baseline-governance.md |
| 2026-05-02 | codex | runtime-target | control/scripts/catalog/doctor 真实运行闭环验证 | 高 | 中 | 中 | adopt | done | codex, agent-dev-kit | reports/codex-pilot-report.md |
| 2026-05-02 | agent-dev-kit | adk-core | 压实总门禁编排（metadata/routing/doc-sync/full-suite/pilot）与发布级回归基线 | 高 | 中 | 低 | adopt | done | agent-dev-kit, codex | reports/adk-production-landing-implementation-2026-05-02.md |
| 2026-05-02 | codex-cookbook | knowledge | Codex 实战模板与 cookbook 任务样例（经验模板已吸收，不并入 core 流程强约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-08 | workspace | knowledge | 维护指南（日常健康检查、adk 压实检查、生产级放行检查） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md |
| 2026-05-08 | workspace | delivery | GitLab Runner 安装配置（Debian/RHEL/Docker 三种方式） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/gitlab-runner-setup.md |
| 2026-05-08 | workspace | knowledge | Pilot 试跑完整证据链（六类试跑场景 artifact 记录） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/codex-pilot-evidence.md |
| 2026-05-08 | workspace | knowledge | 27 条候选能力完整评估矩阵（含决策、验收状态、证据） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference-adoption-matrix.md |
| 2026-05-08 | workspace | knowledge | "道法术器"四层方法论框架（哲学→组织→战术→工具） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/best-practices-cookbook.md |
| 2026-05-08 | workspace | knowledge | 9 款工具速查表（30 秒决策矩阵 + 能力对比表） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/tool-cheatsheet.md |
| 2026-05-08 | workspace | delivery | 子仓治理脚本完整使用手册（24+ 脚本用法） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-scripts-guide.md |
| 2026-05-08 | workspace | adk-core | 意图路由表 + 子仓清单 + 优先级门禁治理全景 | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workspace-governance.md |
| 2026-05-08 | superpowers | workflow-core | 贡献规范（94% PR 拒绝率策略） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/superpowers-agents.md |
| 2026-05-08 | workspace | workflow-core | Artifact 门禁协议模式（统一标签+状态+交接） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-artifact-gating/SKILL.md |
| 2026-05-08 | workspace | workflow-core | Pilot 试跑框架模式（场景+证据+门禁） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-pilot-framework/SKILL.md |
| 2026-05-08 | workspace | workflow-core | 子仓接入工作流模式（扫描+分析+决策） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-intake-workflow/SKILL.md |
| 2026-05-12 | vibeflow | workflow-core | 8 阶段生命周期框架（Spark→Design→Tasks→Build→Review→Test→Ship→Reflect） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md |
| 2026-05-12 | vibeflow | workflow-core | 状态机与恢复点（.vibeflow/state.json 持久化） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md#statejson-规范 |
| 2026-05-12 | vibeflow | workflow-core | Gate 机制设计原则（4 问选择标准） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/AGENTS.md |
| 2026-05-12 | vibeflow | workflow-core | 合同化 Tasks（输入/输出/验收标准） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/templates/artifacts/tasks-template.md |
| 2026-05-12 | vibeflow | workflow-core | 三维评审机制（价值/工程/设计） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/templates/artifacts/review-template.md |
| 2026-05-12 | vibeflow | workflow-core | TDD 集成（红-绿-重构流程） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md |
| 2026-05-12 | vibeflow | workflow-core | Rules 分层目录结构（避免全局污染） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/rules/README.md |
| 2026-05-12 | vibeflow | workflow-core | Router 自动阶段检测（不采纳独立 Router persona，改用内置路由） | 中 | 高 | 中 | reject | done | agent-dev-kit | agent-dev-kit/references/orchestration-patterns.md; agent-dev-kit/scripts/skill-match.sh |
| 2026-05-12 | vibeflow | workflow-core | 复盘机制（Reflect skill） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/templates/LESSONS.md |

## 模板

| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|


## agent-browser（浏览器自动化 CLI）

**来源**: https://github.com/vercel-labs/agent-browser
**版本**: v0.27.0
**语言**: Rust
**Stars**: 33k+
**评估日期**: 2026-05-15
**策略**: observe-first

### 优点

1. **Rust 原生高性能** — 浏览器操作延迟极低
2. **Accessibility-tree 快照** — 用 @eN ref 交互，200-400 tokens 即可描述页面
3. **CDP 直连** — 不依赖 Playwright/Puppeteer，更轻量
4. **CLI 原生** — 一行命令完成 open/snapshot/click/fill/screenshot
5. **Skills 系统** — 内置 core/slack/electron/dogfood 等技能
6. **Chrome for Testing** — 自动下载管理浏览器版本

### adk 借鉴点

1. 浏览器自动化 skill 设计模式
2. 快照压缩策略（Accessibility-tree vs raw HTML）
3. @eN ref 交互范式
4. CLI-first 的工具设计哲学

### 当前状态

- 已安装全局命令 `agent-browser`
- 已下载 Chrome 148.0.7778.167
- 测试通过：open/snapshot/screenshot/close
