# 设计

`runtime_smoke_evidence` 在 `--execute` 前要求显式未知费用确认，传给 ADK `eval run --execute --max-new-results N --approve-unknown-cost`；`--raw-result` 路径不接受费用确认。原始报告除 route/safety 成功外，还要绑定当前 Manifest 摘要、冻结任务集合同、逐例 prompt 摘要和非空观测模型。任何失败都不得写可用于 M5 的证据文件。

collector 在读取报告前后各核一次 clean ADK 来源身份；期间源码漂移时不写证据。此检查缩小竞态窗口，但并不把多文件读取/模型调用宣称为原子快照。

收集器先以 `eval run --help` 做只读能力核验，缺项时在模型调用前阻断。旧固定 ADK `c8b57b5…` 缺预算参数；当前 7.12.4 main commit `35b5fb31…` 已同步到根仓 gitlink/lock 且具备参数，main promotion 签名已验证，但仍需 root fresh integration 与明确模型费用授权才能进入真实调用。

重评顺序：当前 ADK exact source → promotion 静态声明和 Sigstore 签名 → root fresh integration → 已批准预算的真实 Codex smoke → evidence collector → rollover certifier 和状态投影。缺项保持 blocked。旧 5.0.0-rc.2 资格资料留作历史证据。

rollover 以当前 UTC 日期判断 runtime `review_after`、资格记录时间和状态投影；不允许用旧证据的生成日期把历史报告重放为当前放行。写入前必须重跑根仓已有的签名推广门禁；本地测试用隔离 mock cosign 仅证明调用顺序与回滚，不能作为真实签名验证。

rollover 仅接受 clean 根仓源码树；检查同时包含暂存、未暂存、未跟踪和子仓 dirty 状态。模拟正例在 `/tmp` 中提交自己的 fixture 基线，实际根仓和 ADK 工作树保持原状。
