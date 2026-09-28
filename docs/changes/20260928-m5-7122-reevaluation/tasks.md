# 执行检查点

- [x] 修复 collector 当前 ADK CLI 路径与费用门禁；缺预算参数的 pinned ADK 在模型调用前阻断，无真实模型调用。
- [x] 强化原始报告与当前源码、任务集、grader 和逐例模型身份校验，补拒绝旧报告与错配模型的负例。
- [x] Python 3.11 collector 单测 4/4、完整 smoke fixture 与 rollover 正反例通过；旧固定 ADK `c8b57b5…` 的 Python 3.8 quick 曾为 49/49。当前 ADK 7.12.4 main `35b5fb31…` 的三版本 CI、签名 promotion、annotated tag 与 Release 均完成，根仓 exact gitlink/lock 及签名证据已本地导入并验证；真实 M5 测量证据待补。
- [x] rollover 改用当前 UTC 日期和受限 review window；签名推广门禁先于任何写入。模拟正例、缺签名工具、过期证据和回填资格时间负例通过。
- [x] rollover 写入前拒绝 dirty 根仓源码树；临时 fixture clean-commit 正例与 dirty 负例通过，实际工作树未提交或清理。
- [ ] 收集真实模型、签名、root integration 与 owner review 证据后，才考虑 `software_m5_rollover --apply`。

停止条件：缺真实 measured runtime、签名工具、fresh root integration 或预算确认时保持重评准备状态，不升级 M5。
