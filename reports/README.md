# 报告目录说明

本目录用于沉淀持续迭代证据，避免“只有结论没有验证”。

## 文件约定

- `weekly-change-report.md`：由 `scripts/diff-scan.sh` 生成的最新周报
- `weekly-change-report.template.md`：周报模板
- `codex-pilot-report.md`：`codex` 实战试跑报告
- `codex-pilot-report.template.md`：`codex` 试跑模板
- `current-status.md`：当前健康状态索引，用于区分最新门禁结论与历史报告快照
- `governance-review-YYYY-MM-DD.md`：由 `scripts/governance-review.sh` 生成的治理复核报告
- `architecture/`：长期资产架构终态设计、阶段路线图、任务表和目标闭环证据

## 状态边界

- 历史报告保留当时的命令、退出码和风险，不自动改写。
- 若历史报告中的 `NEEDS-FIX` 已被后续提交或验证闭环覆盖，以 `current-status.md`、`scripts/check-current-status-consistency.sh . --summary-json` 和最新门禁输出为准。
- 需要引用当前健康状态时，优先引用 `scripts/governance-health.sh . --format json`、`scripts/check-all.sh --quick` 和 `agent-dev-kit/scripts/devkit.sh test` 的最新执行结果。
- 需要复核 phase gate、reference dirty、Codex live 和 ADK readiness 的组合状态时，优先生成 `governance-review-YYYY-MM-DD.md`，不要只手工改 `subrepos/phase-gate.env`。
- 需要做跨 `llm_agent` 与 `agent-dev-kit` 的终态架构设计时，优先在 `architecture/` 写明当前架构、目标架构、职责边界、问题地图、路线图、验证门禁、状态一致性门禁和不采纳项，再执行实现。
- 批量归档、会话总结和微信吸收报告不得替代 release/pilot 当前状态索引。

## 最小流程

1. 执行 `scripts/sync-subrepos.sh . fetch`
2. 执行 `scripts/diff-scan.sh . 7 reports/weekly-change-report.md`
3. 评估候选项并写入 `subrepos/adoption-matrix.md`
4. 在 `codex` 试跑后更新 `reports/codex-pilot-report.md`
