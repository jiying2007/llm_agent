# 设计：准确输入与统一进程预算

设计者：主 Agent。实现由独立 implement_gates 承担；共享配置串行确认后应用，独立只读审查。

- impact 使用 git diff --name-only -z，以 NUL 分隔保留原始文件名；错误显式失败，避免引号/反斜杠替换损坏路径。
- gate_runner 直接复用 process_budget.run_bounded，统一进程组、后代清理、超时和字节预算；timeout/output-limit 与普通 nonzero 明确区分，维持现有回执消费者。
- 生产 gates.json 当前 9 个 content-addressed gate 都有未完整声明的 index/checkout/动态证据/时间/工具输入，本轮改为 disabled。保留 runner 的完整输入缓存能力，待真实需求和输入完整性证据再启用。
- 当前 hosted CI 无 --cache-dir，本次关闭生产缓存不增加它的常态门禁次数。此事实由调用点检索复核。
- 不使用 HEAD tree 代表整个工作区，也不把新 snapshot 权威加入现有链。

回滚使用受保护变更恢复代码和策略；不改变历史证据。与 ADK 版本 pin、外部方法记录串行整合。环境缺失的 ~/codex Provider/Execution Policy 明确 unavailable，不能把等价本地测试冒充其通过。
