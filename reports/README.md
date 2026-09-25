# 报告目录说明

本目录用于沉淀持续迭代证据，避免“只有结论没有验证”。

## 文件约定

- `weekly-change-report.md`：由 `scripts/diff-scan.sh` 生成的最新周报
- `weekly-change-report.template.md`：周报模板
- `codex-pilot-report.md`：`codex` 实战试跑报告
- `codex-pilot-report.template.md`：`codex` 试跑模板
- `current-status.md`：最近一次已验证提交基线，用于区分已验证基线与历史报告；实时工作树状态必须读取 health/subrepo/governance gate
- `governance-review-YYYY-MM-DD.md`：由 `scripts/governance-review.sh` 生成的治理复核报告
- `architecture/`：长期资产架构终态设计、阶段路线图、任务表和目标闭环证据
- `repo-analysis/<repo>/<commit>/`：从不可变 commit snapshot 生成的参考仓分析清单
- `reference-source-integrity-remediation-YYYY-MM-DD.md`：参考源真实性、dirty 分类和分析隔离修复证据

## 状态边界

- 历史报告保留当时的命令、退出码和风险，不自动改写。
- 若历史报告中的 `NEEDS-FIX` 已被后续提交或验证闭环覆盖，以 `current-status.md` 的最近已验证基线、`scripts/check-current-status-consistency.sh . --summary-json` 和实时门禁输出共同为准；实时门禁优先。
- 需要引用当前健康状态时，优先引用 `scripts/governance-health.sh . --format json`、`scripts/check-all.sh --quick` 和 `agent-dev-kit/scripts/devkit.sh test` 的最新执行结果。
- 需要复核 phase gate、reference dirty、Codex live 和 ADK readiness 的组合状态时，优先生成 `governance-review-YYYY-MM-DD.md`，不要只手工改 `subrepos/phase-gate.env`。
- 需要做跨 `llm_agent` 与 `agent-dev-kit` 的终态架构设计时，优先在 `architecture/` 写明当前架构、目标架构、职责边界、问题地图、路线图、验证门禁、状态一致性门禁和不采纳项，再执行实现。
- 批量归档、会话总结和微信吸收报告不得替代 release/pilot 当前状态索引。

## 最小流程

1. 按 `manifests/reference_pins.json` 显式计划并物化批准来源到外部 cache。
2. 使用 `llm-ctl analyze` 或 cache-only pipeline 生成固定提交的覆盖报告。
3. 按 `docs/runbooks/practice-effect-review.md` 冻结干预与重复试验，独立审查后决定采纳。
4. 组件、消费端、原生运行和现场证据分别保存，不互相继承资格。

## 2026-09-25 研究归档索引

原方案保持逐字不变。以下元数据整合自 `reports/optimization/2026-09-25/archive.json`，替代该独立索引；原文件和各项身份字段不变。旧索引可从提交 `9cfb8b99c8b4adf23843259aa286cdbc4b9f4d99` 追溯。本次整合不调整报告数量预算、不改变资格状态。

<!-- BEGIN RESEARCH ARCHIVE 2026-09-25 -->
```json
{
  "kind": "research-archive-metadata",
  "source_filename": "llm_agent-adk-optimization-plan-2026-09-25.md",
  "archived_path": "reports/optimization/2026-09-25/llm_agent-adk-optimization-plan.md",
  "bytes": 25060,
  "sha256": "d2c605ebbc174ec6cd0e6216293ddb976bcb9eb5d39eb07bd3e56246d29dcf30",
  "git_blob": "0a12f0b86dcbba494aebfed339b534e118560d83",
  "original_status": "proposal-not-implemented",
  "root_baseline": "1df8204166ff7768d0e26e42ee12bcd38ba3b515",
  "adk_baseline": "7367ef84787de75bb751940b32c9e80009660e47",
  "implementation_evidence": "docs/changes/2026-09-25-evidence-intake-hardening/tasks.md",
  "qualification_authority": "none"
}
```
<!-- END RESEARCH ARCHIVE 2026-09-25 -->

历史脚本状态摘录：`optimization/2026-09-25/historical-script-status-2026-05-23.md`；仅保留历史，不作为当前状态依据。元数据与原方案的字节、SHA256、Git blob 一致性由 `tests/test_intake_active_docs.sh` 实际核验。
