# llm_agent 工作区总览与 gdk 迭代依据

## 1. 文档目标

`llm_agent` 的定位是长期跟踪 AI Coding 行业优秀开源实现，并把高价值实践转化为 `global-dev-kit`（gdk）可落地资产（`AGENTS`、`SKILLS`、`WORKFLOWS`）。

本文件用于：

1. 维护参考子仓全量清单与作用说明。
2. 记录可借鉴项、风险和优先级。
3. 固化持续迭代流程、门禁和执行脚本入口。

进入任一子仓后，若该子仓存在本地 `AGENTS.md`，则其规则优先于本文件。

---

## 2. 参考子仓全量清单（已纳入治理）

### 2.1 方法论与流程内核

| 仓库 | 作用 | 主要优点 | 主要风险 | gdk 借鉴点 |
|---|---|---|---|---|
| `superpowers` | 工程流程体系 | 生命周期完整，质量门禁强 | 流程偏重 | 轻重分流 + 可降级执行 |
| `superpowers-zh` | 中文化流程体系 | 中文可读性高 | 与上游漂移风险 | 中文表达与触发词设计 |
| `OpenSpec` | Spec 驱动工件体系 | 变更追溯清晰 | 与现有流程重叠 | 变更单元命名与状态映射 |
| `codex` | `.codex` 全局工程化管理 | 控制层结构化、profile 化 | 本地环境耦合 | `catalog + scripts + doctor` 结构借鉴 |

### 2.2 Agent / Skill 生态

| 仓库 | 作用 | 主要优点 | 主要风险 | gdk 借鉴点 |
|---|---|---|---|---|
| `agency-agents-zh` | 中文角色型 agent 资产 | 角色覆盖广 | 角色过细导致维护重 | 角色矩阵与职责术语 |
| `agent-skills` | 全流程技能资产 | 生命周期映射清晰 | 平台差异较大 | 意图路由与技能分层 |
| `skills` | skills CLI 生态样例 | 安装/更新路径规范 | 质量不均 | 兼容 `skills` CLI 的目录约定 |
| `Migrationed_skills` | 迁移型技能资产池 | 历史沉淀丰富 | 模板化内容较多 | 候选池筛选机制 |
| `codex-skill-spec` | 轻量任务模板体系 | 上手快 | 深度不足 | 低门槛模板与最小闭环 |
| `mattpocock-skills` | 可组合工程技能 | 技能颗粒度细、组合性强 | 对特定协作方式有假设 | 小技能组合范式 |
| `hermes-collaboration-skill` | 团队协作技能实现 | 多平台协作与记忆隔离 | 运维与接入复杂 | 协作场景 runbook |
| `hermes-team-skill` | Hermes 升级包 | 部署路径直接 | 资产颗粒偏粗 | 快速接入模板与脚本交付 |

### 2.3 质量、交付与工程实践

| 仓库 | 作用 | 主要优点 | 主要风险 | gdk 借鉴点 |
|---|---|---|---|---|
| `AUBB-Server` | 后端业务样本 | 业务闭环完整 | 领域专用 | 验证证据写法 |
| `hermes-agent` | 大型 Agent 工程 | 模块边界清晰 | 复杂度高 | 目录职责与测试入口 |
| `arthas` | 成熟开源工程实践 | 贡献规范严谨 | 目标域不同 | 贡献门槛与质量标准 |
| `autonomous-vehicle-dev` | 重构与迁移样本 | 阶段验收明确 | 领域约束强 | 迁移路线图模板 |
| `artifact-gated-agents` | Artifact/Gate 多角色协议 | 门禁与交接明确 | 过重时影响效率 | Artifact 标准与阻塞模板 |

### 2.4 文档、知识与配置治理

| 仓库 | 作用 | 主要优点 | 主要风险 | gdk 借鉴点 |
|---|---|---|---|---|
| `codex_doc_cn` | 文档镜像工程 | 结构一致性强 | 持续追更成本高 | 进度快照与一致性校验 |
| `ai-coding-guide` | AI 编程实践指南 | 场景导向清晰 | 偏知识而非规范 | 场景化工作流导览 |
| `prompts` | 提示词资产 | 实战性强 | 个体偏好强 | 轻量演进风格 |
| `vscode-codex-settings` | 配置治理样本 | 配置透明 | 环境耦合 | 配置摘要 + 验证命令 |
| `dotfiles` | 系统配置管理 | 模块化治理成熟 | 学习门槛高 | 最小变更与基线校验 |
| `auto-research` | 研究闭环样本 | 负结果留痕 | 适配面不一 | 复盘与归档机制 |

### 2.5 gdk 基线定位

| 仓库 | 当前定位 | 优势 | 短板 | 主迭代方向 |
|---|---|---|---|---|
| `global-dev-kit` | 全局 Agent/Skill/Workflow 工程底座 | 结构清晰，命令统一，routing 覆盖全 skill，97 测试全通过，~/.codex 真实安装验证 | 运维脚本可发现性待加强 | 持续迭代运维脚本与真实项目验证 |

---

## 3. 面向 codex 项目的联动策略

`gdk` 后续将实用化于全局 `~/.codex` 运行目录，执行“先落地 gdk、再在 `~/.codex` 试跑、再回灌 gdk”的双向闭环：

1. `llm_agent`：拉取参考源，产生候选改进项。
2. `global-dev-kit`：实现标准资产与门禁脚本。
3. `~/.codex`：真实场景验证（功能开发 / 缺陷修复 / 重构）。
4. 结果回灌：把通过验证的做法升级为 gdk 默认推荐。

### 3.1 执行顺序硬约束（新增）

1. 第一优先：沉淀当前参考子仓“可借鉴优点”，同时明确剔除“不可迁移缺点”。
2. 第二优先：在 `global-dev-kit` 完成实装、验证、runbook 化（压实）。
3. 第三优先：仅在压实门禁通过后，才允许追踪参考子仓增量更新。
4. 门禁控制文件：`subrepos/phase-gate.env`，默认 `allow_upstream_sync=no`。
5. 门禁检查脚本：`scripts/check-gdk-harden-readiness.sh`。

---

## 4. 14 天压缩落地计划（可重复执行）

### D1-D2：优点/缺点提炼与压实准备

1. 更新 `subrepos/registry.csv`（子仓 SSOT）。
2. 在 `subrepos/adoption-matrix.md` 记录“优点采纳/缺点摒弃”。
3. 执行 `scripts/check-agents-coverage.sh` 校验治理覆盖。

### D3-D4：gdk 压实实施

1. 在 `global-dev-kit` 落地 P0 项（优先低风险高收益）。
2. 执行 `scripts/check-gdk-harden-readiness.sh` 完成压实校验。

### D5-D7：codex 实战试跑与回灌

1. 在 `codex` 场景中验证已压实能力。
2. 回写 `reports/codex-pilot-report.md` 与 `subrepos/adoption-matrix.md`。

### D8-D10：开启增量追踪（满足门禁后）

1. 开门后执行 `scripts/sync-subrepos.sh` 与 `scripts/diff-scan.sh`。
2. 对新增候选继续走“采纳优点 + 摒弃缺点 + gdk 压实”闭环。

### D11-D14：回灌与收口

1. 将有效做法纳入 gdk 基线。
2. 模板化、低收益项降级或淘汰。

---

## 5. 优先级准入门禁（P0/P1/P2）

### P0（立即落地）

1. 统一变更单元命名与状态映射（OpenSpec + gdk）。
2. 默认要求验证证据（`verify-report` / `review-report`）。
3. 文档最小标准化（用途/命令/验证）。

### P1（中期）

1. OpenSpec 与 gdk 桥接脚本化。
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
- 压实校验：`scripts/check-gdk-harden-readiness.sh`
- 周报模板：`reports/weekly-change-report.template.md`
- codex 实战模板：`reports/codex-pilot-report.template.md`

---

## 7. 维护机制

### 7.1 触发条件

1. 新增或移除任一参考子仓。
2. 子仓出现关键流程/目录/门禁变化。
3. gdk 或 codex 试跑结果显示“文档与行为不一致”。

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

### 2026-05-03（使用指南补齐）
- 变更范围：补齐 `llm_agent` 根使用指南、持续维护指南、gdk 最新 README/usage/commands/production deployment，并新增 `~/.codex/AGENTS.md` 与 gdk 配合指南。
- 触发原因：需要让后续维护者无需依赖历史会话即可执行参考仓吸收、gdk 压实、生产部署、pilot 验证和 `~/.codex` 策略配合。
- 更新条目：`README.md`、`docs/llm-agent-maintenance-guide.md`、`global-dev-kit/README.md`、`global-dev-kit/docs/usage.md`、`global-dev-kit/docs/commands.md`、`global-dev-kit/docs/runbooks/production-deployment.md`、`global-dev-kit/docs/codex-agents-integration.md`、`scripts/README.md`。
- 验证命令：
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-runtime-routing.sh .`
  - `rtk bash -lc "cd global-dev-kit && bash scripts/devkit.sh validate --strict"`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；文档同步、runtime routing、gdk strict validate、gdk full regression suite、codex pilot evidence/coverage 与全局 `~/.codex` health 均通过。

### 2026-05-02（去冗余与顺序压实）
- 变更范围：清理 `global-dev-kit` profile 继承重复声明；统一 Evidence Index 模板字段；新增 profile coherence 机校门禁并接入 runtime routing 与全量回归。
- 触发原因：多轮增量补丁后需要防止 Agent/Skill/Workflow 资产出现冗余、重复和主辅技能顺序歧义。
- 更新条目：`global-dev-kit/manifest.yaml`、`global-dev-kit/scripts/check_profile_coherence.sh`、`global-dev-kit/tests/test_profile_coherence.sh`、`global-dev-kit/scripts/workflow.sh`、`global-dev-kit/scripts/check_change_governance.sh`、`global-dev-kit/docs/*`、`scripts/check-runtime-routing.sh`、`reports/gdk-production-landing-implementation-2026-05-02.md`。
- 验证命令：
  - `rtk global-dev-kit/tests/test_profile_coherence.sh`
  - `rtk global-dev-kit/tests/test_change_governance.sh`
  - `rtk global-dev-kit/tests/test_workflow.sh`
  - `rtk global-dev-kit/tests/test_evidence_index.sh`
  - `rtk global-dev-kit/tests/run_all.sh`
  - `rtk scripts/check-runtime-routing.sh .`
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；profile coherence 已进入 runtime routing 与 gdk 全量回归，主压实门禁含 pilot 与全局 `~/.codex` 健康检查通过。

### 2026-05-02
- 变更范围：执行 `--open-gate` 开门动作；完成开门后正式增量同步与差异扫描；回填本轮 `adoption-matrix` 决策。
- 触发原因：执行“先压实 gdk，再追踪子仓更新与借鉴”的新硬约束。
- 更新条目：`subrepos/phase-gate.env`、`reports/weekly-change-report.md`、`subrepos/adoption-matrix.md`、`reports/codex-pilot-report.md`。
- 验证命令：
  - `rtk scripts/check-gdk-harden-readiness.sh . --open-gate`
  - `rtk scripts/sync-subrepos.sh . fetch`
  - `rtk scripts/diff-scan.sh . 7 reports/weekly-change-report.md`
  - `rtk scripts/check-agents-coverage.sh .`
- 验证结果：通过；门禁生效，且开门后正式评估链路可用。

### 2026-05-02（追加）
- 变更范围：新增 codex 试跑证据门禁脚本并接入压实检查；完成 1 个 codex 高风险场景试跑并补齐 artifact 证据。
- 触发原因：将“先压实再追踪”从文本约束升级为机器可判定门禁。
- 更新条目：`scripts/check-codex-pilot-evidence.sh`、`scripts/check-gdk-harden-readiness.sh`、`scripts/README.md`、`reports/codex-pilot-report.md`、`subrepos/adoption-matrix.md`。
- 验证命令：
  - `rtk scripts/check-codex-pilot-evidence.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --open-gate`
  - `rtk bash ~/.codex/control/scripts/doctor.sh ~/.codex minimal`
- 验证结果：通过；严格门禁链路（含 codex 试跑证据）可复现可通过。

### 2026-05-02（再追加）
- 变更范围：新增全局 `~/.codex` 健康门禁并接入压实默认检查，彻底去除“依赖当前仓库本地 codex 目录”路径。
- 触发原因：统一改为全局 `~/.codex` 运行目标后，需要硬校验全局目录健康状态。
- 更新条目：`scripts/check-global-codex-health.sh`、`scripts/check-gdk-harden-readiness.sh`、`scripts/README.md`、`subrepos/phase-gate.env`。
- 验证命令：
  - `rtk scripts/check-global-codex-health.sh ~/.codex minimal`
  - `rtk scripts/check-gdk-harden-readiness.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；默认压实链路已包含全局 `~/.codex` 健康检查。

### 2026-05-02（终态压实）
- 变更范围：新增“全局 codex 目标策略”门禁，禁止本地 `codex/` 目录回流；并入压实主链路。
- 触发原因：确保“后续直接使用 `~/.codex`”不被后续改动破坏。
- 更新条目：`scripts/check-global-codex-target-policy.sh`、`scripts/check-gdk-harden-readiness.sh`、`scripts/README.md`。
- 验证命令：
  - `rtk scripts/check-global-codex-target-policy.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
  - `rtk scripts/check-agents-coverage.sh .`
- 验证结果：通过；压实主链路 now 同时校验 `~/.codex` 健康与“无本地 codex 回流”策略。

### 2026-05-02（策略调整）
- 变更范围：按最新要求移除“本地 `codex/` 回流”主链路校验；继续强化 gdk 压实为“默认跑全量回归”。
- 触发原因：明确无需校验本地 `codex/` 回流，压实重心转到 gdk 质量回归。
- 更新条目：`scripts/check-gdk-harden-readiness.sh`、`scripts/README.md`。
- 验证命令：
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --open-gate`
- 验证结果：通过；压实主链路 now 默认包含 `global-dev-kit/tests/run_all.sh`。

### 2026-05-02（Wave8 二次吸收）
- 变更范围：把 observe 证据从“可引用”升级为“命令级字段可机校”；同步 Agent/Skill/Workflow 三层规则并回填矩阵证据。
- 触发原因：继续推进“质量优先”的压实目标，避免 Evidence Index 仅停留在文本描述层。
- 更新条目：`global-dev-kit/scripts/workflow.sh`、`global-dev-kit/scripts/check_change_governance.sh`、`global-dev-kit/tests/test_workflow.sh`、`global-dev-kit/agents/test-validation-engineer/AGENTS.md`、`global-dev-kit/agents/code-review-governor/AGENTS.md`、`global-dev-kit/skills/verification-before-completion/SKILL.md`、`global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`、`global-dev-kit/docs/runbooks/evidence-index-delivery.md`、`global-dev-kit/docs/runbooks/config-baseline-governance.md`、`global-dev-kit/docs/runbooks/prompt-evolution-delivery.md`、`reports/observe-secondary-intake-packages-wave8-2026-05-02.md`、`subrepos/adoption-matrix.md`。
- 验证命令：
  - `rtk global-dev-kit/tests/test_workflow.sh`
  - `rtk global-dev-kit/tests/test_change_governance.sh`
  - `rtk global-dev-kit/tests/run_all.sh`
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-adoption-matrix-status.sh .`
  - `rtk scripts/check-observe-intake-depth.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite`
- 验证结果：通过；命令级 Evidence Index 字段与负结果证据门禁已进入持续校验链路。

### 2026-05-02（Wave9 delivery 升级）
- 变更范围：将 `delivery` 类稳定项从 `observe` 分批升级为 `adopt`，并新增 `delivery adopt` 深度门禁脚本纳入主链路。
- 触发原因：执行“Wave9 先升级 delivery 类”的压实目标，确保采纳决策具备机器可判定质量门禁。
- 更新条目：`subrepos/adoption-matrix.md`、`scripts/check-delivery-adopt-depth.sh`、`scripts/check-gdk-harden-readiness.sh`、`scripts/README.md`、`reports/wave9-delivery-observe-to-adopt-2026-05-02.md`、`reports/post-freeze-kickoff-2026-05-02.md`。
- 验证命令：
  - `rtk scripts/check-delivery-adopt-depth.sh .`
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-adoption-matrix-status.sh .`
  - `rtk scripts/check-observe-intake-depth.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite`
- 验证结果：通过；delivery 采纳深度检查已进入默认主门禁。

### 2026-05-02（Wave10 全量 observe 收口）
- 变更范围：将剩余全部稳定 `observe + done` 条目升级为 `adopt + done`，并把 observe 深度脚本调整为“无 observe 行即通过”语义。
- 触发原因：执行“全部稳定 observe 项升级为 adopt”要求，完成本阶段 observe 队列清零。
- 更新条目：`subrepos/adoption-matrix.md`、`scripts/check-observe-intake-depth.sh`、`scripts/README.md`、`reports/wave10-all-stable-observe-to-adopt-2026-05-02.md`、`reports/post-freeze-kickoff-2026-05-02.md`。
- 验证命令：
  - `rtk scripts/check-observe-intake-depth.sh .`
  - `rtk scripts/check-delivery-adopt-depth.sh .`
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-adoption-matrix-status.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite`
- 验证结果：通过；`observe+done` 已清零并保持主门禁通过。

### 2026-05-02（生产级落地补齐）
- 变更范围：补齐 gdk 生产级运行入口、profile 分层、runtime routing、Evidence Index 自动化、pilot coverage 字段门禁、上游吸收准入和生产安装备份/报告能力。
- 触发原因：执行“完成 gdk 生产级落地”的补齐计划，确保 `~/.codex` 以 gdk 作为统一生产分发层。
- 更新条目：`global-dev-kit/manifest.yaml`、`global-dev-kit/scripts/install_assets.sh`、`global-dev-kit/scripts/evidence_index.sh`、`global-dev-kit/scripts/devkit.sh`、`global-dev-kit/optional-skills/*`、`global-dev-kit/docs/runbooks/*`、`scripts/check-runtime-routing.sh`、`scripts/check-codex-pilot-coverage.sh`、`scripts/check-upstream-intake-readiness.sh`、`scripts/check-gdk-harden-readiness.sh`、`reports/codex-pilot-report.md`、`reports/gdk-production-landing-implementation-2026-05-02.md`。
- 验证命令：
  - `rtk global-dev-kit/tests/test_install.sh`
  - `rtk global-dev-kit/tests/test_evidence_index.sh`
  - `rtk scripts/check-runtime-routing.sh .`
  - `rtk scripts/check-codex-pilot-coverage.sh .`
  - `rtk scripts/check-upstream-intake-readiness.sh .`
  - `rtk global-dev-kit/tests/run_all.sh`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；生产级基础设施已接入主门禁，六类 pilot 后续由 full coverage 门禁继续压实。

### 2026-05-02（生产安装试跑）
- 变更范围：执行真实 `~/.codex` 生产安装，使用 `personal-core + release-hardening`，叠加生产级 optional skills，并生成安装报告与回滚备份。
- 触发原因：继续推动 gdk 从“可发布”进入全局 `~/.codex` 生产试跑。
- 更新条目：`reports/gdk-install-report-2026-05-02.md`、`reports/codex-pilot-report.md`、`reports/gdk-production-landing-implementation-2026-05-02.md`、`subrepos/adoption-matrix.md`。
- 验证命令：
  - `rtk bash -lc 'cd global-dev-kit && bash scripts/devkit.sh validate --strict'`
  - `rtk bash -lc 'cd global-dev-kit && bash scripts/devkit.sh install --tool codex --target ~/.codex --mode copy --profile personal-core --extra-profile release-hardening --with-optional-skill planning-execution-loop --with-optional-skill skill-composition-governance --with-optional-skill security-supply-chain --with-optional-skill cross-team-handoff --with-optional-skill artifact-gated-lite --backup --install-report ../reports/gdk-install-report-2026-05-02.md --lock-version 0.3.0'`
  - `rtk scripts/check-global-codex-health.sh ~/.codex minimal`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；安装报告生成，回滚点为 `/home/aiot03/.codex/.gdk-backups/20260502T104514Z`。

### 2026-05-02（六类 Pilot 全覆盖）
- 变更范围：将 codex pilot 从字段级检查升级为 full coverage 检查；补齐新功能、缺陷修复、重构、发布收口、团队交接、上游吸收六类 gdk 自举试跑证据。
- 触发原因：继续推动 gdk 从生产安装进入可机校的场景覆盖，避免仅凭字段声明完成。
- 更新条目：`scripts/check-codex-pilot-coverage.sh`、`scripts/README.md`、`reports/codex-pilot-report.md`、`reports/gdk-production-landing-implementation-2026-05-02.md`、`subrepos/adoption-matrix.md`。
- 验证命令：
  - `rtk scripts/check-codex-pilot-evidence.sh .`
  - `rtk scripts/check-codex-pilot-coverage.sh .`
  - `rtk scripts/check-doc-sync.sh .`
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 验证结果：通过；`pilot_full_coverage_ready=yes` 已由六类场景 artifact 与命令级 Evidence Index 支撑。

### 2026-05-01
- 变更范围：新增 `codex` 子仓纳入治理；补齐全量子仓覆盖；落地 `subrepos/`、`scripts/`、`reports/` 治理骨架；在 `global-dev-kit` 落地 `artifact-gated-lite`（profile + optional skill + runbook）。
- 触发原因：需要压缩迭代周期并建立可持续增量吸收机制。
- 更新条目：`AGENTS.md`、`subrepos/registry.csv`、`subrepos/adoption-matrix.md`、`scripts/*`、`reports/*`、`global-dev-kit/manifest.yaml`、`global-dev-kit/optional-skills/artifact-gated-lite/SKILL.md`。
- 验证命令：
  - `scripts/check-agents-coverage.sh .`
  - `scripts/sync-subrepos.sh . fetch`
  - `scripts/diff-scan.sh . 14 reports/weekly-change-report.md`
  - `bash global-dev-kit/scripts/validate_assets.sh --strict`
  - `bash global-dev-kit/tests/test_optional_skills.sh`
  - `bash global-dev-kit/tests/test_no_external_repo_refs.sh`
- 验证结果：全部通过（`codex_doc_cn` 因远端仓库不可达已在 `registry.csv` 标记为 disabled）。
