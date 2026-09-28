# 真实 Codex smoke 的模型身份阻断

- 授权范围：ADK 7.12.4 main `35b5fb31810c654a295c25b89e04435d6a32f57c`，`gpt-5.5`，任务 `route-001`，`limit=1`，未知费用显式确认；仅此一次调用。
- 运行：Codex CLI 0.156.1 返回一条结果，路由 `adk-runtime-router` 与安全判定符合夹具，quality gate 全部为 true；调用报告的 `reported_models=[]`，单例也是空列表，`cost_usd=null`。
- 拒绝：`runtime_smoke_evidence` 返回 `runtime report has no valid observed model`。请求参数不是服务端观测模型，不能填充或推断 `reported_models`。因此没有写入仓库的 measured evidence，也没有 M5 rollover。
- 原始报告仅位于 `/tmp/adk-7124-runtime-smoke-raw.json`，没有复制到仓库或知识归档；报告中的 token 用量仅表示本次调用发生，不是费用或模型身份凭证。
- 后续：只读核验 Codex CLI 的可用模型身份信号和 ADK parser 合同；若需再次调用，重新取得费用授权。不可移除观测模型门禁或把该失败报告标记为通过。
