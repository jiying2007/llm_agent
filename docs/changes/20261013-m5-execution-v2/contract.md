# M5 v2：真实执行与制品来源验收

用户明确要求从 M5 移除实际模型身份采集、标记和验证。新的 `llm-agent-runtime-smoke-evidence/v2` 验证真实任务执行、结果质量、源码和制品来源；`requested_model` 与 reasoning effort 仅表示请求配置，不声明服务端实际模型。

M5 producer 默认产出 v2，直接调用固定 Codex CLI，不启动模型身份观察器，也不检查模型 header。发布报告 `schema_version=2`，移除顶层及各任务的 `reported_models` 和 collection 的 `model_observation`；这些字段不得重新混入 v2。固定 ADK 的 v1 原始报告仅作输入，模型元数据不参与新契约评分，不进入发布证据；原始输入摘要仍绑定证据，原始内容不归档。独立 collector 使用 `--execution-only` 显式选择 v2，与 `--observe-provider-model` 互斥。

保留实际执行文件的前后 hash、固定源码/ADK/manifest/task/prompt、任务逐项路由及安全结果、usage 的严格类型、数量、错误和时效检查。执行 receipt 的 v1 schema 是通用来源协议，可继续使用；它签名绑定整个测量内容，包括新 evidence schema，因此旧签名不能通过改写字段变成 v2。

旧 evidence v1 继续按原实际模型身份规则读取和验证；不改变历史 signed/failed 记录，不把旧失败重标为新契约成功。rollover 和当前 M5 消费者均接受显式 v1/v2，未知版本拒绝。Cosign、workflow/main/run/attempt/source 绑定和固定信任真实验签继续强制执行；没有签名或无效签名仍拒绝。

本次验证分层：离线 fixture/假执行器仅证明新契约与拒绝行为；源码测试及 CI 不证明新契约下的实际模型任务完成。新的真实取证必须使用新运行和相应有界额度，不复用历史失败/未知计数。field、independent pilot、owner 和 release 各自验收保持独立。

回退方式：通过正常补丁把 producer 恢复为 v1 observation 路径；保留已生成 v2 的原始含义，不覆写其签名或反向补造身份。
