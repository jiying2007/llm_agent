# 2026-10-18: 长期资产闭环加固（Root）

## 本轮边界

只推进可重放、无外部消费、无真实 Owner 行为假设的工程工作。保留已发布 ADK 的 Python 3.8+ 兼容性及跨仓 Release/Runtime/Product 各自独立的认证。外部真实 G21/G22、Harness Owner、LTA-04、条件性 current-source Product M5 继续由已有机器入口与 Issue 跟踪，不能凭本轮 CI 冒充通过。

## 发现与变更

1. **活跃文档漂移（并行主线已修复）**：受保护主线已通过原生 LTA-01 状态对齐和 `tests/test_long_term_asset_qualification.sh` 回归修复旧 runbook。本 PR 不再覆盖它们，也不创建平行状态表，保留现有机器 SSOT。
2. **未知 Git 历史漏检风险（并行主线已修复）**：根仓最新 main 已独立合入该项：`tools/control_plane/impact.py` 在 base 不可读取时抛出 ValueError，PR/push CI 无合法或可读 base 时明确失败，不再将未知历史解释成 `integration-deep NOT_REQUIRED`。本 PR 只保留现行实现，绝不再修改 CI/impact 形成平行版本；手工 dispatch 仍沿用既有参数。
3. **关键控制面类型回归**：并行主线已将 `consumer_chain.py`、`longitudinal_operation.py` 和 `evidence_paths.py` 纳入既有严格 mypy，并完成 `intake_io.py` 的共享输入类型修复；本 PR 只补充尚未纳入的 `status_projection.py` 和类型缩窄，不覆盖已合并的文件。
4. **被增量集成漏检的长期资格测试**：并行主线的 `tests/test_long_term_asset_qualification.sh` 曾保留独立 `.lower()` 语法错误；doc-only main CI 因 integration-deep 合理跳过而未执行该测试，直到本轮 deep integration 才暴露。主线并行提交已修复这个测试本身的语法和过期文字断言；该 canonical LTA 测试已由受保护主线的 always-run `tests/test_ci_incremental_gate_dag.sh` 调用，避免另外一处重复执行。本 PR 复用该已生效断言，不新增 Gate 或第二套资格验证器。
5. **真实维护指标**：明确复用 `tools.codex_assets.maintainability_evidence` 产生 review-required churn 候选。真实 owner_concentration / inactive_assets 不得凭空补零；没有 provenance 时保持 report-only/not-available。

## 验证

- Root contract/profile DAG、`tests/test_ci_incremental_gate_dag.sh`、`tests/test_long_term_asset_qualification.sh` 与本 PR 扩展的 CI strict mypy；已合入的回归保持原样。
- 需要深度集成时必须通过 ADK exact-source pin 与已存在 Sigstore provenance 入口，并核 PR head、fresh-main 分别成功。
- 文档变更不刷新历史资格、不新增 runtime trust authority、不修改现有 Python 支持矩阵。

## 仍未达到的真实终态

- G21：ADK #153 真实 authenticated native discovery/load/trigger + managed trust.
- G22：Root #154 固定任务与模型版本的真实对照、真实 invocation receipts、全资产 owner 判定。
- LTA-04：Root #67 真实最后 24 小时现场 `pilot_observed`、30天完整摘要与人类 Owner review。
- Harness：ADK #205 七维 90 天真人复核；历史语义审查 ADK #201。
- Product M5：Root #236 仅在明确产品发布场景重做当前源码认证。

所有未完成项继续 fail-closed；不能用静态测试、时间推进或另一层签名替换真实外部事实。
