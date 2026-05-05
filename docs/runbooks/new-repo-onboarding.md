# 新仓库接入 Runbook

> 当有新的参考仓库需要纳入 llm_agent 治理时，按此流程执行。

## AI 自动化模式（推荐）

直接告诉 AI：

```
接入 https://github.com/xxx/yyy 仓库
```

或

```
把 /path/to/repo 纳入治理
```

AI 会自动完成：克隆 → 注册 → 深度分析 → 生成报告 → 更新治理文件 → 给出决策建议。

对应技能：`repo-onboarding`（自动加载）。

## 手动模式（备用）

---

## 前置判断

收到新仓库候选后，先回答 3 个问题：

1. **它解决什么问题？** — 必须能用一句话说清对 gdk 的借鉴价值
2. **它的质量如何？** — 有活跃维护？有文档？有测试？
3. **它与现有子仓重叠吗？** — 查 registry.csv 确认无重复

如果答案不清晰，先放入 `subrepos/adoption-matrix.md` 的 observe 状态观察。

---

## 接入流程（6 步）

### Step 1: 克隆仓库

```bash
cd /home/aiot03/aiot/llm_agent
git clone <repo-url> <repo-name>
```

### Step 2: 注册到 registry.csv

在 `subrepos/registry.csv` 末尾添加一行：

```
<repo-name>,<group>,<priority>,pull,main,yes,<简要说明>,active,<owner>,<YYYY-MM-DD>,<intake_policy>
```

字段说明：
- group: gdk-core / reference / ecosystem
- priority: P0 / P1 / P2
- intake_policy: adopt-first / observe-first / selective-adopt / pilot-first

### Step 3: 深度分析仓库

对仓库做全量分析（AGENT|SKILL|PROFILE|WORKFLOW），产出：

1. 在仓库根目录写入 `AGENTS.md`（含深度分析报告章节）
2. 记录：功能、优缺点、可借鉴点、风险

### Step 4: 更新 adoption-matrix.md

在 `subrepos/adoption-matrix.md` 添加一行：

```
| <date> | <repo-name> | <category> | <capability> | <value> | <cost> | <risk> | <decision> | <status> | <target> | <evidence> |
```

decision: adopt / observe / reject
status: done / pending / blocked

### Step 5: 更新 AGENTS.md

在 `llm_agent/AGENTS.md` 对应章节添加仓库条目：

- 2.1 方法论与流程内核
- 2.2 Agent/Skill 生态
- 2.3 质量、交付与工程实践
- 2.4 文档、知识与配置治理

### Step 6: 验证接入

```bash
# 检查注册完整性
scripts/check-agents-coverage.sh .

# 检查上游接入就绪
scripts/check-upstream-intake-readiness.sh .

# 同步仓库
scripts/sync-subrepos.sh . fetch
```

---

## 接入后闭环

### 如果决定 adopt（采纳）

1. 在 global-dev-kit 中实装借鉴点
2. 运行 `scripts/check-gdk-harden-readiness.sh . --require-pilot`
3. 更新 adoption-matrix 状态为 done
4. 在 reports/ 记录采纳证据

### 如果决定 observe（观察）

1. 更新 adoption-matrix 状态为 pending
2. 设置复审日期（last_reviewed_on）
3. 定期 `scripts/sync-subrepos.sh . fetch` 拉取更新
4. `scripts/diff-scan.sh . 14 reports/weekly-change-report.md` 扫描变化

### 如果决定 reject（拒绝）

1. 更新 adoption-matrix 状态为 done + decision 为 reject
2. 记录拒绝理由

---

## 常见问题

**Q: 新仓库没有 AGENTS.md 怎么办？**
A: Step 3 中会自动生成。如果仓库自身有，保留原内容，追加分析报告。

**Q: intake_policy 怎么选？**
A:
- adopt-first: 高价值、低风险、可直接吸收（如成熟开源工程实践）
- observe-first: 需要观察一段时间（如新项目、活跃开发中）
- selective-adopt: 只采纳部分内容（如领域专用但有通用组件）
- pilot-first: 需要先试跑验证（如 Agent 框架、工作流系统）

**Q: 接入后发现仓库质量差怎么办？**
A: 在 adoption-matrix 中标记 reject，记录理由，保留仓库目录但设 enabled=no。
