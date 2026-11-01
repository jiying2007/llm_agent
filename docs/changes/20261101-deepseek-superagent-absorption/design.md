# Design — 方法差异吸收而非另造 Runtime

## 核心选择

DeepSeek dsh-superagent-prototype 提供研究样例：Source/Trigger → Thread/Eval → immutable Mandate/Ticket → Assignment/Worker → Outbox/人类待办。其代码依赖 DSH 并仅针对一个 GitHub 仓库。我们的系统已经拥有 Root metadata-only intake、ADK typed policies 和 engineering-platform 真实 WorkItem/Worker/Action Gateway，故不复刻整条链。

## 与现有 authority 对齐

| 上游 | 本地 owner | 复用或扩展 |
| --- | --- | --- |
| Source / Trigger | 现有来源适配与事件/CI入口 | 引入稳定事件 ID、带来源的 cursor 与乱序恢复测试；禁止 source body 转授权 |
| Gate / Mandate | ADK execution_policy；消费者自己的 admission/Action Gateway | 明确 actor × scope × mode × policy revision；Context 不授予权限；resume 再验证 |
| Thread / Subscription | 任务事件归属与协作上下文 | Follow-up 优先到已有任务；context-only、owner hand-back 与无重复评估 |
| Ticket / Assignment | engineering-platform WorkItem/Task/Worker | 长期任务 identity、checkpoint 与执行 attempt 分开；失败报告不可伪装 DONE |
| Outbox | engineering-platform 独立 outbox & Action Recovery | 复用 lease 和 UNKNOWN 不重放；无需引入 DeepSeek 实现 |
| Human action | 既有 status/queue/summary | 只读 actionable projection、事件键降噪、状态改变强通知 |
| Router / Worker | 已有调度器与执行者分工 | Router 不同步等 CI/长命令；按角色限制权限，不因 prompt 提示代替宿主隔离 |

## 强制边界

1. **输入与权限分离**：外部文本、Issue/PR 评论、CI log 只能成为 evidence/context；任何执行授权由可信宿主策略与已批准 owner 生成。Bot 的自动评论不得触发 explicit 工作。
2. **幂等和排序**：Event ID 基于 Source+native event id+revision，不用内容相似度代替；同一 Thread 一次 Eval，批量事件不改变事件权限。
3. **任务/执行解耦**：Work ID 不随 Worker 重试变化；attempt id、resume checkpoint、source revision、授权 revision 分开保存；历史失败保留不可覆盖。
4. **反馈有价值**：仅当存在需要人的下一步、交付 ready、不可自动恢复的异常时主动通知；正常巡检保持沉默，状态仍可被手动查询。
5. **副作用**：GitHub push/merge、CI、设备/Flash、签名、生产发布仍由独立网关执行；回执未知先 reconcile，再决定是否重复，不由提示词绕过。
6. **扩展顺序**：现有 engineering-platform #228 的 orphan Action no-replay Recovery 终态是先决依赖；不改它的 state machine 并行引入新执行器。

## 试点评测设计（需批准后单独变更）

- 固定任务集合：允许的明确用户请求、未授权提及、普通讨论、机器人评论、已有 Ticket 的 in-scope/out-of-scope follow-up、历史 PR 新评论、旧 cursor 下晚到消息、Network 429/5xx、Worker 中断、外部 effect UNKNOWN、人工 stop。
- 每个样例输入相同的不可变事件及 policy revision，在 baseline/variant 下记录 admitted、ticket identity、attempt count、notifications、receipt provenance。
- 关键安全指标 100%：未授权执行数必须 0；重复 effect 数必须 0；未经核实 UNKNOWN replay 数必须 0。历史消息及重复事件应可稽核；丢失不应静默。
- 体验/效率指标先测 baseline：human prompts/task、重复消息数、待办响应时间、真实完成率、误触发和漏触发、工作量/tokens。改进阈值由 owner 在实验开始前预注册，不能事后选择。
- 增量变更使用现有 schema/测试/CI，而不是新增自由格式审批或“另一个总状态表”。

## 推广、终止与回滚

1. Root research → independent decision → ADK change；未批准保持只读研究资料。
2. ADK 只修改既有角色规范和判据的薄层，并提供 deterministic negative fixtures；不动 runtime/provider 绑定。
3. 工程平台后续进入独立试点，仅在 #228 收敛且 fresh-main 合格后按新 feature 实施，无人工行为证据不启用自动行为。
4. 若误触发率、漏事件、审核负担、成本或安全负例恶化，立即停用扩展规则并保留事件 ledger 和原有受控链路；不以新系统覆盖旧证据。

## 状态

本 Design 是独立评估生成的候选方案，非 owner approval，不声称已实现上述改动。