# 模型协议闭环验证

本轮关闭本地协议兼容和响应身份一致性缺口；当前候选资格仍 blocked。保留历史报告，不重标历史 5.0.0-rc.2 或过期 scorecard。

真实取证使用 native Codex 0.159.2、requested model gpt-6.1-sol、reasoning medium，每次一个 canonical task。本轮共三次，预算已用完，没有第四次调用。认证只在内存转发，工具禁用，只允许固定官方 HTTPS，不保存认证、请求/响应正文或原生 stderr。

| 取证 | 结果 | 限定结论 |
| --- | --- | --- |
| raw-1 | HTTP 200，MIME gate 拒绝，completed=false | 定位本地 MIME 前置检查问题 |
| raw-2 | HTTP 200，实际 SSE 完成，completed=true，observed_models=[] | 真实流完成，但缺契约支持的服务端模型身份 |
| raw-3 | metadata 兼容后仍 completed=true，observed_models=[] | 兼容扩展没有补齐真实模型身份 |

安全诊断位于 `.cache/m5-protocol-closure-20261010/raw-{1,2,3}-observation-failure.json`。三次 collector 均失败关闭，没有有效 runtime-{1,2,3}.json。completed=true 不能等同于任务评分通过、可核验 usage 或有效模型身份。第三次之后进一步收紧跨响应 ID 校验，最终源码没有追加真实模型采集；前述失败回执属于各自执行时快照。

软件验证：四组定向测试 55/55 PASS（ResourceWarning 为 error）；根仓回归 74/74 PASS。根仓回归在本轮修复期间运行，最终 M5 测试通过，最终源码另外由 55 项定向测试覆盖；不宣称整轮回归原子绑定单一快照。Ruff E9/F 与 git diff --check PASS。最终离线 wheel 校验 55 个 Python 文件逐字节一致，5 个 CLI 从非仓库目录 --help PASS，未安装或发布。wheel SHA256 `b882e22f31cf8152d5d4fb2b678ff4fbc36b7ce480b7341e6869480add4c2edc`，source-map SHA256 `b548bd6d2018a1f3c6281e2414624c3468bf91a181ad735e3bfe40e30cc044cb`。

独立复审 Spec/Quality PASS、无剩余本轮 finding，见 protocol-review.md。真实 Cosign 诊断 promotion_signature=pass，但 blocking_gates=[runtime, qualification, historical_declaration]；software_m5_certified=false、release_authorized=false。

ADK quick 56/56 PASS；doc sync 与 AGENTS coverage PASS；token budget 检查无失败，保留已有 3 项软预算警告。最终串行聚合回执位于 `.cache/m5-protocol-closure-20261010/aggregate.json`，结果单独验收。没有提交、推送、触发外部 CI、修改 live 配置或制造 field/owner 证据。Provider 本轮 context 可用；没有通过 Provider 持久化新知识或 activity，不声明已归档。

剩余闭环需要：受信上游可核验的模型身份及完整任务/usage 回执；绑定当前候选的真实 CI 和资格证据；新鲜 field、owner 决策与 scorecard。获得这些证据前，保持 fail-closed，并保留当前线程恢复检查点。
