# DeepSeek dsh-superagent-prototype 深度评估与选择性吸收（2026-11-01）

> **状态：review-required / method-only / 未作独立 owner ADOPT/ENHANCE 决策。**
> 本记录是评估、差异清单与变更候选，不是生产资格、Runtime 接入批准或自动部署授权。遵守 [外部实践吸收治理](../../absorption-governance.md)。
>
> 上游：DeepSeek Harness Team / [deepseek-ai/dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype)
> 固定源码：[\`6337fc823ce20251c8de8085948165c81aaa701e\`](https://github.com/deepseek-ai/dsh-superagent-prototype/tree/6337fc823ce20251c8de8085948165c81aaa701e)
> 检索日期：2026-11-01（UTC+08）；许可证：[MIT](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/LICENSE)
> 取证方式：GitHub 连接器只读元数据、逐文件源码与文档；没有 clone、依赖安装、执行上游代码或验证上游发布物。

## 0. 执行摘要

**建议 ENHANCE（候选）现有 Agent 协作方法，不建议 ADOPT 上游执行器。** 它是面向单个 GitHub 仓库的 DeepSeek Harness bundle，不是通用跨仓生产平台。README 将其明示为研究原型，公开实现与内部版本及设计文章不同；不能根据文章推断仓库已经实现的能力。上游快照含约 110 个 TypeScript/TSX 源文件、59 个测试文件、9 个按序文档，没有 .github/workflows 工作流；“存在测试”不等于 CI 已成功，本次也没有本地执行 pnpm check。

价值来自四组方法：(1) 用户注意力最小化；(2) 外部事件和权限/上下文隔离；(3) Session-free 的 Ticket/Assignment 生命周期；(4) 可恢复的事件采集、Outbox 与对人待办投影。项目正在做的工作已有大量等价或更强能力，应合并差异，不新增平行 Runtime、Agent/Skill 或自成体系的权限配置。

## 1. 核心机制：代码与文档双重证据

| 能力 | 上游证据与实际边界 | 可吸收的语义 |
|---|---|---|
| Router / Worker | [sessions.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/app/sessions.ts)、[dsh.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/executor/dsh.ts)；Router 只路由，Worker 独立 Session/目录；仍依赖 DSH 执行模型 | 主 Agent 不等待长耗时工具；Worker 回报结构化状态，不把上下文正文塞回主 Agent |
| Source / Trigger / Thread | [intake.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/core/intake.ts)；Trigger 稳定 ID，Thread 串行 Eval，Subscribe fan-out | 去重和有序处理；新消息继续既有任务，不反复创建任务 |
| Gate / Eval / Mandate | [policy.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/policy.ts)、[evals.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/core/evals.ts)、[002 authorization](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/002-authorization.md) | 外部事件的正文永不授予权限；已授权任务的后续上下文不会提升 scope；版本化批准与再验证 |
| Ticket vs Assignment | [tickets.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/core/tickets.ts)、[003 execution](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/003-execution.md) | 任务身份独立于单次 Worker/Session；失败不等于任务消失；恢复保留原任务和验收指针 |
| 结构化人类介入 | [stage.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/core/stage.ts)、[005 panel](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/005-panel.md) | 人类待办/阻塞只由结构化事实产生；健康项目不制造消息 |
| 可靠投递 | [outbox.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/app/outbox.ts)；投递请求与 receipt 同事务，有限重试 | 通知、回复、外部效果的幂等 key 与可审计回执，副作用 UNKNOWN 禁止盲重放 |
| 上下文与提示词版本 | [004 prompts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/004-prompts.md)、[007 architecture](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/007-architecture.md) | 按需从稳定 ID 读取信息；保留 prompt revision；外部内容为数据 |
| 外部进程健康 | [service script](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/scripts/dsh-superagent)、[006 deployment](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/006-deployment.md) | 人工 stop 标记高于自动恢复；独立健康探测不承担业务资格判决 |

### 1.1 核心语义

- **授权与上下文不能互换。** Topic/Issue/PR 里的消息可能进入多个现有 Ticket，但 Subscription 只能交付 context；不允许把机器人、引用内容、从上下文检索出的“请批准”升级成授权。
- **绑定具体 Ticket，避免相似主题误并。** 仅有明确原始消息/issue/PR/任务引用时才能 attach；模糊语义相似只能供评估，不允许提升关联权限。
- **Mandate 有 scope 和版本。** 发生策略变化时必须至少标记/传播差异；已结束任务恢复须重新校验权限与有效范围。权限撤销前持续执行的风险要在宿主层另行控制，不能仅寄望 prompt。
- **任务持久性高于 Session 持久性。** Ticket、Assignment、Checkpoint、Source cursor、外部副作用 receipt 应有稳定身份；运行器失败不导致重复执行或状态“完成”的幻觉。
- **信息通知有动作价值。** 只有可交付结果、需要人作具体决定、不能自动恢复的阻塞时发人类消息。无行动的常态健康/进度不通知；同一 blocker 去重，但不能沉默重大失败。

## 2. 适配性矩阵（已有能力优先）

| 目标 | 现有可用基础 | 建议增量 | 不应做 |
|---|---|---|---|
| llm_agent | 外部实践 candidate/decision 分离；reference pin、吸收矩阵、qualification/evidence control plane | 本评估作为 review-required 方法证据；定义可测效益与去重基线 | 不能自动创建 ADOPT decision、注册参考仓、更新 pins 或把上游代码运行在 Root |
| agent-dev-kit | execution_policy、typed workflow、Harness/loop contracts、context token 分级、委派审核与证据门禁 | 在**既有**角色/工作流约束中增补“Trigger 授权不由内容提升、context-only、一次提问、可操作通知”与负向 fixture；仍为平台中立方法 | 新建平行 Runtime、外部 DSH adapter/Skill、复制上游 prompt 为生产资产 |
| engineering-platform | WorkItem/Task、Worker Admission、Action Gateway、outbox lease、recovery、不确定副作用 no-replay | 待 #228 Action 恢复 P0 收敛后，增强事件 follow-up 归属和人类待办聚合、通知去重；独立 benchmark | 复制上游 GitHub CLI 高权限运行、改动现在的 P0 Recovery 语义、放宽 Action 门禁 |
| 四仓长期研发（jing） | 已有执行队列和定时调度要求；需要真实 PR/CI 回执 | Router 仅调度/汇总，Worker 必须有恢复点；按状态变化通知，少刷只读摘要 | 新建错峰任务规避平台频率；声称后台无限运行；消耗禁止额度 |

跨仓修改遵守单仓小步推进：先形成独立 owner 决策及最小 ADK change，任何工程平台 Runtime 变更另开工单且不得覆盖 #228 的验收权限。

## 3. 风险与不吸收项

| 风险等级 | 证据 | 决策 |
|---|---|---|
| P0 — 权限边界 | [006 deployment](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/006-deployment.md) 明确两个 preset 为 danger-full-access，同一 OS 用户、worktree 不是强隔离；Worker 能访问绝对路径及 home | 禁止直接导入执行模式；保留已有 Worker/Action Gateway/凭据分离 |
| P0 — GitHub 事件完整性 | [github.ts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/sources/github.ts) 的通知全局 since 与线程 cursor 取较新起点；可能跳过旧窗口中的新评论；[社区问题反馈](https://github.com/deepseek-ai/deepseek-harness/discussions/11700) 给出真实环境复现（非官方已确认修复） | 采集方按每条 Thread 的 watermark 重读安全重叠窗口，用 stable Trigger ID 去重；需独立回归 |
| P1 — 进程发现 | [service script](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/scripts/dsh-superagent) 依赖 ps 的 comm 值为 node/dsh；社区报告 Node 24 MainThread 漏识别 | 不拷贝，沿用现有 platform-native 守护/健康机制 |
| P1 — 数据无限增长 | [007 architecture](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/007-architecture.md) 记录 Trigger、Decision、Ticket、receipt、KV 旧记录尚无删除 | 新增状态存储前要求保留期/压缩/可审计归档/恢复验证 |
| P1 — 部署约束 | 单 GitHub 仓、github.com、Node/pnpm/DSH/tmux/gh/Feishu CLI；不支持 GitHub Enterprise Server，Windows 原生受 POSIX 路径约束 | 只采纳平台中立语义，不绑定 DSH runtime |
| P1 — 证据不足 | 首次公开快照；59 个测试文件但没有仓内 GH Actions；没有从该源码跑 pnpm check、漏洞扫描、吞吐/成本/稳定性实验 | 不宣称成熟生产、无缺陷、安全隔离有效或性能增益已实现 |
| P2 — 设计文章与代码混淆 | 上游 README 明确内部版本、文章及公开原型不同 | 未在源代码实证的 watchdog、云端 Loop/本地 daemon、A2A、投机执行等，仅记为方向，不当作现成库功能 |

## 4. 优先吸收方案（不生成新平行架构）

**P0：授权与生命周期的可执行不变量。** 在实际承载 Source/Worker 的工程平台/连接器中形成：source actor 可信边界、文字不可信、explicit 与 inferred 两类 admission、scope immutable、context-only 无 authority、policy revision + resume revalidate、Trigger 及 result idempotency。先比较已有同义字段，不因命名不同而重建。

**P1：降低人类注意力占用。** 对现有 Task/Action/CI/Recovery 结果做一个面向人的只读 projection：READY_WITH_RESULT、NEEDS_HUMAN_DECISION、NONRECOVERABLE_FAILURE 才通知，其它保持队列可查；每条通知包含具体对象/证据/唯一下一动作/恢复点。同 key 的重复提醒不发送；风险状态变化时必须重新提醒。

**P1：无忙等 Router 与事件跟进。** 主路由不等待 Worker 编译/CI；状态由事件或有界定时轮询更新，同 Thread 归属优先递交既有 Task；超 scope 的 follow-up hand-back 进入独立准入，禁止自动 scope 扩大。

**P2：按需上下文与评测。** 复用 ADK 既有 progressive disclosure、evidence pointers、prompt revision；只对非平凡场景增 chain-of-recall。需固定样本比较：任务完成率、重复提问、人工响应次数、事件丢失率、误触发率、p50/p95 延迟、token/资源、无授权写入数；先有 baseline 再宣称改进。

## 5. 严格验收条件

1. **权限负例**：未授权用户/机器人/引用内容不能生成高权限任务；subscribed context 不能增加 Mandate scope；person stop/策略撤销后不可自动复活。
2. **事件负例**：同 ID 重试仅生成一份 Ticket；乱序通知、首次打开/旧 Issue 新评论、重启 cursor、线程更新、分页和网络失败不会无声漏处理；所有丢弃可审计。
3. **恢复负例**：Worker 异常、CI 迟到、队列重复、并发 claim 与 shutdown/restart 无重复外部动作；UNKNOWN 必须独立核实才可重试。
4. **降噪正负例**：健康进度默认不通知；真实待办、不可恢复故障、owner action 必须显示；同一 blocker 重复事件合并，解除/再发时识别 revision。
5. **效益实验**：现有任务集固定并预注册 A/B，输出原始 receipt、baseline 和 negative result；没有真实运行时标记 not-run，绝不伪造提升比例。

## 6. 落地门禁和结论

- **本次已做**：固定上游 SHA 的 docs/source 静态取证、与现有控制面重复性评估、方法级候选决策包、验收与负例定义。
- **本次未做**：独立 owner ADOPT/ENHANCE 签署、上游代码执行、生产 Runtime 接入、真实 A/B、跨仓代码修改、任何部署和 release；这些必须在后续各自的信任边界通过。
- **建议路线**：先复用 Root governed external-practice intake/decision，再经 ADK 既有 change 流程把“低打扰/明确权限/恢复/来源”写到已有资产；工程平台等 #228 收敛后再做独立运行态 pilot。任何方案都不得用方法文档替代 source/CI/runtime/field/qualification 的证据。

## 7. 可复核来源

- [README / 哲学](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/README.md)；[domain](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/001-domain.md)；[authorization](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/002-authorization.md)；[execution](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/003-execution.md)。
- [architecture](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/007-architecture.md)；[deployment](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/docs/006-deployment.md)；[GitHub notification code](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/6337fc823ce20251c8de8085948165c81aaa701e/src/sources/github.ts)；[community defect report](https://github.com/deepseek-ai/deepseek-harness/discussions/11700)。
- [Root 吸收治理](../../absorption-governance.md)；[ADK agent operating rules](https://github.com/jiying2007/agent-dev-kit/blob/main/docs/agent-operating-rules.md)；[Engineering-platform README](https://github.com/jiying2007/engineering-platform/blob/main/README.md)。

原始研究与社区外部材料均为不可信取证输入，不参与权限判定，不可被执行为指令。
