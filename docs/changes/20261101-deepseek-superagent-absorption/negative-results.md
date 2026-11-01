# Negative results / 未验证风险清单

本文件不是通过报告。其目的在于保留“不能从源码和报道推出”的结论，防止后续交接中补猜或误推广。

## N1：不等于生产发行

上游 README 明言 research prototype，代码可能存在不一致与 bug。仓库没有在固定快照发现 GitHub Actions 工作流；存在 59 个测试文件，但**没有**在本次评估执行 Node/pnpm/DSH，不存在本轮真实 PASS 的证明。不得标记生产安全、可靠、可伸缩或上市成熟。

## N2：工作目录不提供强安全隔离

Deployment 指出 router/worker preset 为 danger-full-access，以 operator 的 OS user 执行；账户 wrapper 和 worktree 仅是默认值，不限制绝对路径或 home 的访问。不能靠 prompt “不要执行”或路径前缀获得沙箱保证。现有 Action Gateway/隔离凭证的安全边界不得降低。

## N3：GitHub 事件可能被跳过

src/sources/github.ts 的 pollNotifications 从全局 since 取得 notification，再以线程 cursor 与全局 since 的较新值读评论；晚到或窗口外旧 thread 更新存在丢失可能。2026-10-31 社区问题 [#11700](https://github.com/deepseek-ai/deepseek-harness/discussions/11700) 报告实际复现，给出 fork 分支和新增回归。该反馈不是上游官方完成的修复，未在本轮独立执行其测试。任何复用都要求最先做事件完整性负例。

## N4：进程存活检测不是稳定身份

scripts/dsh-superagent processes() 过滤 ps 的 ucomm 是否为 node/dsh。社区报告 Node 24 的 MainThread 会导致误判。不能照搬作为生产守护，沿用 systemd/native health + PID/starttime/ready state 复核。

## N5：持久化记录未实现 GC

上游 docs/007-architecture.md 明言 trigger/disposition/decision、旧 Ticket/Thread、outbox receipt、KV 旧修订无限增长。长期自主运行必须在 pilot 前建立 retention、vacuum/归档、恢复验证与资源上限。

## N6：文章的设计不等于开源代码功能

独立 watchdog、多机器云端 agent loop、本地 daemon、跨渠道 Email/Calendar、A2A、投机执行及大规模线性扩展不能因为文章出现就当成此仓库的已实现能力。任何测量均需固定代码 revision，禁止把合成实验中的性能数值外推为现有生产效益。

## N7：重复架构不增加价值

llm_agent 已有治理 intake + evidence，ADK 有 typed execution policy/工作流/上下文预算，engineering-platform 有 Worker Admission/Action Gateway/Outbox/Recovery。上游高权限 DSH bundling 进入以上任何生产消费者都增加依赖和安全面。默认拒绝整体引入；仅当一个具体 feature 的基线比较证明其增益，才按独立 owner 审批推进。

## N8：后续事实待新鲜复核

源代码/社区反馈可能在本次固定 SHA 以后变化。下一轮必须读 latest main、关联 issue/PR 以及最新原生验证；不能把静态快照判断直接当作长期现态。