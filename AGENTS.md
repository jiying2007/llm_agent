# llm_agent 工作区总览与 adk 迭代依据

## 1. 文档目标

`llm_agent` 的定位是长期跟踪 AI Coding 行业优秀开源实现，并把高价值实践转化为 `agent-dev-kit`（adk）可落地资产（`AGENTS`、`SKILLS`、`WORKFLOWS`）。

本文件用于：

1. 维护参考子仓全量清单与作用说明。
2. 记录可借鉴项、风险和优先级。
3. 固化持续迭代流程、门禁和执行脚本入口。

进入任一子仓后，若该子仓存在本地 `AGENTS.md`，则其规则优先于本文件。

---

## 1.1 意图路由表（AI 自动执行）

> 当用户表达以下意图时，AI 应自动执行对应流程，无需用户手动指定工具或脚本。

| 用户意图 | 触发关键词 | 执行动作 | 涉及脚本/技能 |
|----------|-----------|---------|--------------|
| 接入新仓库 | 接入、新增子仓、add repo、onboard、纳入治理 | 加载 `repo-onboarding` 技能，执行克隆→注册→深度分析→生成报告→更新治理文件 | `scripts/new-repo-onboard.sh` + AI 深度分析 |
| 全面检查 | 检查、check、验证、门禁、健康检查 | 运行一键检查，汇总所有门禁结果 | `scripts/check-all.sh` / `scripts/devkit.sh check` |
| 同步子仓 | 同步、sync、拉取更新、fetch | 拉取所有 enabled 子仓最新代码 | `scripts/sync-subrepos.sh` |
| 差异扫描 | 差异、diff、变更、最近变化 | 扫描子仓近 N 天变更 | `scripts/diff-scan.sh` |
| 深度分析 | 深度分析、拆解、analyze、prompt分析、skill拆解 | 加载 `adk-repo-prompt-analyzer` + `adk-skill-deep-analyzer` 技能，执行四阶段 Prompt 逆向 + 八阶段 Skill 深度拆解 | `scripts/analyze-repo.sh` |
| 生成周报 | 周报、weekly report、本周汇总 | 自动生成本周变更周报 | `scripts/generate-weekly-report.sh` |
| 清理报告 | 清理、归档、cleanup、prune | 归档过期报告 | `scripts/cleanup-reports.sh` |
| 版本发布 | 发布、release、tag、版本 | 执行发布流程 | `scripts/version-manager.sh` |
| 健康检查 | 健康、health、状态 | 检查工作区整体健康状态 | `scripts/health-check.sh` |
| 安装 hook | hook、pre-commit、提交检查 | 安装 git pre-commit hook | `scripts/install-pre-commit-hook.sh` |
| 一键流水线 | 流水线、pipeline、一键更新、全量更新 | 执行 8 步闭环: 同步→差异→分级→分析→采纳→模式检测→AI吸收→报告 | `scripts/pipeline-subrepo-update.sh` |
| 优化 adk | 优化、改进、升级 adk、enhance | 加载 `adk-release-versioning` 技能，执行优化→验证→发布 | `agent-dev-kit/scripts/devkit.sh` |
| 自动吸收 | 吸收、absorb、自动吸收、提取模式 | **禁止完全增量更新！** 必须先加载 `ai-auto-absorb` 技能，执行全盘比对→重复检查→冲突检查→冗余检查→架构评估→决策论证→质量补充→验证 | `scripts/auto-absorb.sh` + `docs/absorption-governance.md` |
| 备份回滚 | 备份、回滚、backup、rollback、恢复 | 创建安装备份、列出备份、恢复或回滚到指定版本 | `scripts/backup-rollback.sh` / `agent-dev-kit/scripts/backup-rollback.sh` |
| 冻结后周期 | 冻结后、post-freeze、冻结后检查、周期执行 | 冻结后执行周期性检查：文档同步→差异扫描→采纳矩阵状态→摘要生成 | `scripts/run-post-freeze-cycle.sh` |

**执行原则：**
1. 用户说意图，AI 自动选择工具和流程
2. 不需要用户记住脚本名称或参数
3. 执行后自动汇报结果
4. 失败时自动诊断并建议修复
5. **吸收必须全盘考量，禁止完全增量更新**（详见 `docs/absorption-governance.md`）

---

## 2. 参考子仓全量清单（已纳入治理）

### 2.1 方法论与流程内核

| 仓库 | 作用 | 主要优点 | 主要风险 | adk 借鉴点 |
|---|---|---|---|---|
| `superpowers` | 工程流程体系 | 生命周期完整，质量门禁强 | 流程偏重 | 轻重分流 + 可降级执行 |
| `superpowers-zh` | 中文化流程体系 | 中文可读性高 | 与上游漂移风险 | 中文表达与触发词设计 |
| `OpenSpec` | Spec 驱动工件体系 | 变更追溯清晰 | 与现有流程重叠 | 变更单元命名与状态映射 |
| `flow-kit` | 纯 Markdown 流程包 | 跨工具引用简单、无运行时依赖 | 手工复制模式难治理 | 轻量流程入口与模板组织 |
| `codex` | `.codex` 全局工程化管理 | 控制层结构化、profile 化 | 本地环境耦合 | `catalog + scripts + doctor` 结构借鉴 |

### 2.2 Agent / Skill 生态

| 仓库 | 作用 | 主要优点 | 主要风险 | adk 借鉴点 |
|---|---|---|---|---|
| `agency-agents-zh` | 中文角色型 agent 资产 | 角色覆盖广 | 角色过细导致维护重 | 角色矩阵与职责术语 |
| `agent-skills` | 全流程技能资产 | 生命周期映射清晰 | 平台差异较大 | 意图路由与技能分层 |
| `skills` | skills CLI 生态样例 | 安装/更新路径规范 | 质量不均 | 兼容 `skills` CLI 的目录约定 |
| `Migrationed_skills` | 迁移型技能资产池 | 历史沉淀丰富 | 模板化内容较多 | 候选池筛选机制 |
| `codex-skill-spec` | 轻量任务模板体系 | 上手快 | 深度不足 | 低门槛模板与最小闭环 |
| `mattpocock-skills` | 可组合工程技能 | 技能颗粒度细、组合性强 | 对特定协作方式有假设 | 小技能组合范式 |
| `hermes-collaboration-skill` | 团队协作技能实现 | 多平台协作与记忆隔离 | 运维与接入复杂 | 协作场景 runbook |
| `hermes-team-skill` | Hermes 升级包 | 部署路径直接 | 资产颗粒偏粗 | 快速接入模板与脚本交付 |
| `codex-cookbook` | Codex 协作手册 | "道法术器"方法论框架，军师技能分层设计 | 仅 Codex 平台 | 分层触发与三段式写法 |
| `Trellis` | 知识管理工具参考 | 结构化知识组织 | 领域专用 | 知识图谱与关联查询借鉴 |
| `superpowers-openspec-team-skills` | Superpowers + OpenSpec 团队技能包 | explicit opt-in、记忆闭环、团队工作流分层清晰 | 直接安装易绕过 adk 压实链路 | 显式触发、记忆模板、OpenSpec 协同边界 |
| `vibeflow` | SDD+Harness 交付编排层 | 36 skills 覆盖全流程（brainstorm→design→build→review→ship），中文文档完善 | 仅 Claude Code/Codex/OpenCode 平台 | 交付链路编排、阶段门禁、TDD 流程、复盘机制借鉴 |
| `agent-browser` | 浏览器自动化 CLI | Rust 原生高性能，Accessibility-tree 快照 + @eN ref 交互，Chrome CDP，无需 Playwright/Puppeteer | 仅浏览器操作场景 | 浏览器自动化 skill 设计、快照压缩策略、ref 交互范式 |

### 2.3 质量、交付与工程实践

| 仓库 | 作用 | 主要优点 | 主要风险 | adk 借鉴点 |
|---|---|---|---|---|
| `AUBB-Server` | 后端业务样本 | 业务闭环完整 | 领域专用 | 验证证据写法 |
| `hermes-agent` | 大型 Agent 工程 | 模块边界清晰 | 复杂度高 | 目录职责与测试入口 |
| `arthas` | 成熟开源工程实践 | 贡献规范严谨 | 目标域不同 | 贡献门槛与质量标准 |
| `autonomous-vehicle-dev` | 重构与迁移样本 | 阶段验收明确 | 领域约束强 | 迁移路线图模板 |
| `artifact-gated-agents` | Artifact/Gate 多角色协议 | 门禁与交接明确 | 过重时影响效率 | Artifact 标准与阻塞模板 |

### 2.4 文档、知识与配置治理

| 仓库 | 作用 | 主要优点 | 主要风险 | adk 借鉴点 |
|---|---|---|---|---|
| `codex_doc_cn` | 文档镜像工程 | 结构一致性强 | 持续追更成本高 | 进度快照与一致性校验 |
| `ai-coding-guide` | AI 编程实践指南 | 场景导向清晰 | 偏知识而非规范 | 场景化工作流导览 |
| `prompts` | 提示词资产 | 实战性强 | 个体偏好强 | 轻量演进风格 |
| `vscode-codex-settings` | 配置治理样本 | 配置透明 | 环境耦合 | 配置摘要 + 验证命令 |
| `dotfiles` | 系统配置管理 | 模块化治理成熟 | 学习门槛高 | 最小变更与基线校验 |
| `auto-research` | 研究闭环样本 | 负结果留痕 | 适配面不一 | 复盘与归档机制 |

### 2.5 adk 基线定位

| 仓库 | 当前定位 | 优势 | 短板 | 主迭代方向 |
|---|---|---|---|---|
| `agent-dev-kit` | 嵌入式系统开发 Agent/Skill/Workflow 工程底座 | 结构清晰，routing 覆盖全 skill，97 测试全通过，已具备向 `~/codex` 交接再进入 `~/.codex` 的生产链路 | 运维脚本可发现性待加强 | 持续迭代运维脚本与真实项目验证 |

---

## 3. 面向 codex 项目的联动策略

`adk` 后续将实用化于本机 Codex 运行体系，执行“先在 `agent-dev-kit` 完成资产化与验证、再交接到 `~/codex`、由 `~/codex` apply 到 `~/.codex` 试跑、最后回灌 adk”的双向闭环：

1. `llm_agent`：拉取参考源，产生候选改进项。
2. `agent-dev-kit`：实现标准资产、门禁脚本和可交接导出物。
3. `~/codex`：作为声明式资产仓库吸收、注册、构建和审计 adk 资产。
4. `~/.codex`：只接收 `~/codex` apply 后的真实运行资产，并执行真实场景验证（功能开发 / 缺陷修复 / 重构）。
5. 结果回灌：把通过验证的做法升级为 adk 默认推荐。

### 3.1 执行顺序硬约束（新增）

1. 第一优先：沉淀当前参考子仓“可借鉴优点”，同时明确剔除“不可迁移缺点”。
2. 第二优先：在 `agent-dev-kit` 完成实装、验证、runbook 化（压实）。
3. 第三优先：仅在压实门禁通过后，才允许追踪参考子仓增量更新。
4. 门禁控制文件：`subrepos/phase-gate.env`。
   - 默认值：`allow_upstream_sync=no`（门禁关闭）
   - 当前状态：`allow_upstream_sync=yes`（门禁已打开，v2.0.0 发布后）
   - 打开条件：见 phase-gate.env 注释（5 项全部满足）
5. 门禁检查脚本：`scripts/check-adk-harden-readiness.sh`。

---

## 4. 14 天压缩落地计划（可重复执行）

> **实际执行记录**: 本计划在 2026-05-01/02 两日内压缩完成（10+ 轮迭代）。以下结构保留为后续迭代模板。

### D1-D2：优点/缺点提炼与压实准备

1. 更新 `subrepos/registry.csv`（子仓 SSOT）。
2. 在 `subrepos/adoption-matrix.md` 记录“优点采纳/缺点摒弃”。
3. 执行 `scripts/check-agents-coverage.sh` 校验治理覆盖。

### D3-D4：adk 压实实施

1. 在 `agent-dev-kit` 落地 P0 项（优先低风险高收益）。
2. 执行 `scripts/check-adk-harden-readiness.sh` 完成压实校验。

### D5-D7：codex 实战试跑与回灌

1. 在 `codex` 场景中验证已压实能力。
2. 回写 `reports/codex-pilot-report.md` 与 `subrepos/adoption-matrix.md`。

### D8-D10：开启增量追踪（满足门禁后）

1. 开门后执行 `scripts/sync-subrepos.sh` 与 `scripts/diff-scan.sh`。
2. 对新增候选继续走“采纳优点 + 摒弃缺点 + adk 压实”闭环。

### D11-D14：回灌与收口

1. 将有效做法纳入 adk 基线。
2. 模板化、低收益项降级或淘汰。

---

## 5. 优先级准入门禁（P0/P1/P2）

### P0（立即落地）

1. 统一变更单元命名与状态映射（OpenSpec + adk）。
2. 默认要求验证证据（`verify-report` / `review-report`）。
3. 文档最小标准化（用途/命令/验证）。

### P1（中期）

1. OpenSpec 与 adk 桥接脚本化。
2. 场景化 runbook 扩展（开发/修复/重构/发布）。
3. 角色与技能触发矩阵精炼。

### P2（长期）

1. 多工具兼容层扩展（控制复杂度）。
2. 研究与工程一体化归档机制。

---

## 6. 持续迭代落地资产（本仓固定入口）

- 子仓清单：`subrepos/registry.csv`
- 候选评估：`subrepos/adoption-matrix.md`
- 同步脚本：`scripts/sync-subrepos.sh`
- 差异扫描：`scripts/diff-scan.sh`
- 覆盖校验：`scripts/check-agents-coverage.sh`
- 压实校验：`scripts/check-adk-harden-readiness.sh`
- 一键门禁：`scripts/check-all.sh`（`--quick` 跳过耗时项，`--verbose` 显示详细输出）
- 统一入口：`scripts/devkit.sh`（`check`/`onboard`/`sync`/`diff`/`health`/`weekly-report`/`cleanup`）
- 周报模板：`reports/weekly-change-report.template.md`
- codex 实战模板：`reports/codex-pilot-report.template.md`
- 新仓库接入脚本：`scripts/new-repo-onboard.sh`
- 新仓库接入 Runbook：`docs/runbooks/new-repo-onboarding.md`
- CI/CD 配置：`.gitlab-ci.yml`
- Runner 设置：`docs/setup-gitlab-runner.md`
- AI 自动吸收脚本：`scripts/auto-absorb.sh`（`--dry-run` 只分析 / `--auto` 全自动 / `--apply` 逐项审核）
- 吸收治理规则：`docs/absorption-governance.md`（**必读**：禁止完全增量更新，要求全盘深入考量）
- 备份回滚脚本：`agent-dev-kit/scripts/backup-rollback.sh`（`backup`/`restore`/`list`/`rollback`/`verify`）
- 采纳矩阵摘要：`scripts/generate-adoption-matrix-summary.sh`（解析 `adoption-matrix.md` 生成状态汇总 + blocked 明细）
- 冻结后周期脚本：`scripts/run-post-freeze-cycle.sh`（串联 `check-doc-sync` → `diff-scan` → `check-adoption-matrix-status` → `generate-adoption-matrix-summary`）

---

## 7. 维护机制

### 7.1 触发条件

1. 新增或移除任一参考子仓。
2. 子仓出现关键流程/目录/门禁变化。
3. adk 或 codex 试跑结果显示“文档与行为不一致”。

### 7.2 维护动作

1. 更新本文件仓库条目与优先级。
2. 更新 `subrepos/registry.csv` 与 `subrepos/adoption-matrix.md`。
3. 执行三类脚本并记录验证结果。

### 7.3 维护记录模板

```md
## 维护记录

### YYYY-MM-DD
- 变更范围：
- 触发原因：
- 更新条目：
- 验证命令：
- 验证结果：
```

---

## 8. 工作区执行要求

1. 默认中文输出，技术标识保留英文。
2. 修改前先确认目标子仓本地 `AGENTS.md` 约束。
3. 尽量单次只改一个子仓，避免混合提交。
4. 无验证证据不得宣称“完成/可提交/可合并”。

---

## 维护记录

### 版本里程碑

| 版本 | 日期 | 主要变更 |
|------|------|----------|
| v2.0.0 | 2026-05-05 | adk 全面优化，97/100 分，97 测试全通过 |
| v1.0.0 | 2026-05-02 | 生产级落地，`~/codex -> ~/.codex` 安装验证 |
| v0.3.0 | 2026-05-01 | 初始版本，26 子仓治理骨架 |

详细历史记录参见 `reports/` 目录。
