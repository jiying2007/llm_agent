# 子仓借鉴评估矩阵（SSOT）

## 使用说明

1. 每个候选项对应一行，不跨行合并多个能力点。
2. `决策` 仅允许：`adopt`、`observe`、`reject`。
3. `证据` 必须包含可复现命令或报告路径。
4. `回灌目标` 默认填写 `global-dev-kit`，如需试跑可追加 `codex`。

## 当前记录

| 日期 | 来源仓库 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|
| 2026-05-01 | artifact-gated-agents | 轻量 artifact 标签与门禁模板（ImplementationPlan/ReviewReport/TestReport） | 高 | 中 | 低 | adopt | global-dev-kit, codex | global-dev-kit/optional-skills/artifact-gated-lite/SKILL.md |
| 2026-05-01 | codex | 控制层脚本化治理（catalog/scripts/doctor）在 gdk 的映射策略 | 高 | 中 | 中 | observe | global-dev-kit | reports/weekly-change-report.md |
| 2026-05-01 | OpenSpec | 变更工件与状态流转硬约束 | 高 | 中 | 低 | adopt | global-dev-kit | global-dev-kit/docs/workflows.md |
| 2026-05-02 | codex | 控制层脚本化能力大规模更新（scripts/workflows/vendor skills）先在 codex 试跑验证再吸收 | 高 | 中 | 中 | observe | codex, global-dev-kit | reports/codex-pilot-report.md |
| 2026-05-02 | global-dev-kit | `artifact-gated-lite` profile + optional skill + runbook 已压实并通过门禁 | 高 | 低 | 低 | adopt | global-dev-kit, codex | global-dev-kit/optional-skills/artifact-gated-lite/SKILL.md |
| 2026-05-02 | hermes-agent | 多平台协作脚本更新，保留为中期参考，暂不直接并入 gdk 核心 | 中 | 中 | 中 | observe | global-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | hermes-collaboration-skill | CI 与协作说明更新，可借鉴文档结构，不直接引入实现 | 中 | 低 | 中 | observe | global-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | hermes-team-skill | 升级包粒度偏粗、与 gdk 核心边界重叠，当前轮次不采纳 | 低 | 中 | 中 | reject | global-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | mattpocock-skills | 小技能组合与弃用分层目录，可借鉴到 gdk optional 分类治理 | 中 | 中 | 低 | adopt | global-dev-kit | reports/weekly-change-report.md |

## 模板

| 日期 | 来源仓库 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|
| YYYY-MM-DD | superpowers | 示例：完成前验证门禁 | 高 | 中 | 低 | adopt | global-dev-kit, codex | reports/weekly-change-report.md |
