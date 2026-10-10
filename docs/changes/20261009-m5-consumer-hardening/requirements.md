# M5 消费端证据加固

- request: 提高预算，按建议全部优化落地闭环。
- goal_statement: 修复审查确认的签名、runtime 完整契约、源码身份与时效、CI 身份和链接输入五类缺陷，完成确定性回归和独立复审。
- scope_write: 根仓 tools/codex_assets、相关 tests、M5 CLI 包装入口和本 change 文档。
- excluded: ADK 子仓、参考目录、历史 policy/scorecard/qualification、真实测量、live runtime、commit/push/merge。
- implementation_permission: authorized；外网查询和真实晋级不属于本实现的验收前提。
- acceptance: 无验签配置或验签失败不得认证；错误观察模型、零任务、伪 gate、身份/摘要/时效不匹配、无可信 CI 身份、链接/FIFO 均 fail closed；合法合成 fixture 的晋级事务与回滚仍可测试。
- evidence_boundary: 测试 fixture 和 mocked verifier 只证明源码行为，不形成真实 runtime/field/owner/release 资格。
- retry_budget: 每个失败假设最多两次定向重试；新 blocker/major 类连续两轮触发 replan。
- staleness_threshold: 修改后重新绑定 snapshot；完整验证与工作区副作用串行。
- stop_condition: 五类缺陷 fixed，完整源码回归和 whole-diff 独立复审闭环；外部资格缺项分别报告。

## 2026-10-10 重审修复范围

- request: 按建议全部优化落地闭环。
- confirmed_findings: P1 继承 Bash 启动环境；P1 证据可以摘要未实际执行的任意文件。
- acceptance: capability/eval 共用清理后的环境；执行前选定可执行普通文件，固定真实调用，执行后与发布前复核摘要；raw import 身份不可验证时标记并在生产消费中拒绝。
- compatibility: 原启动器路径及 argv[0] 保留，不复制启动器二进制，以保持相对资源寻址。旧报告仍可导入诊断，但不能直接作为当前 M5 资格证据。
- deferred_unverified: Git filter 路径未完成复现，不列为已确认缺陷；不重复被安全检查拒绝的验证。
