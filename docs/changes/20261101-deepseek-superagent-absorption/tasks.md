# Tasks — 有条件、可恢复的吸收队列

所有工作按单一 owner/单仓变更推进；当前分析任务是 DONE，后续实现任务未获 canonical independent decision，不得标记 DONE。

| ID | 优先级 | 状态 | owner/依赖 | 验收 / 恢复点 |
| --- | --- | --- | --- | --- |
| DS-00 固定源码与差异评估 | P0 | DONE（静态取证） | Root research | 上游 SHA、主要代码路径、许可、安全/重复项均可查；assessment.md |
| DS-01 正式独立决策 | P0 | BLOCKED（待签署） | llm_agent governance owner | 按 external-practice-decision/v1 签署 ENHANCE 或 OBSERVE；同源 reviewer 不冒充 owner |
| DS-02 ADK 权限/通知方法补强 | P0 | READY after DS-01 | agent-dev-kit owner | 在现有规范/测试中覆盖 explicit vs context-only、scope、一次提问、actionable-only；无新 Runtime |
| DS-03 GitHub Source 防漏事件测试 | P0 | READY after DS-01 | 事件采集实际 owner | late reply、per-thread cursor、overlap+dedup、429 和重启用确定性 fixture 复现；无 silent loss |
| DS-04 Task follow-up/handoff 语义 | P1 | WAITING prerequisite | engineering-platform owner；#228 先收敛 | 同 Thread 归属不误并；超 scope 重新授权；队列可恢复；副作用仍 Action Gateway |
| DS-05 Human action 低打扰投影 | P1 | WAITING prerequisite | platform/UX owner；DS-04 | 无可操作变化不通知、需要决策及时可见、同一 blocker dedup、解除后可通知；只读投影 |
| DS-06 有界 A/B 资格与回滚 | P2 | WAITING prerequisite | qualification owner；DS-02～05 选择一条 | 固定 baseline、fresh source、实际 CI、误触发/漏触发、人类注意力/成本指标，negative-result 记录；无凭空性能收益 |

## 本次 verification

- 已通过 GitHub 连接器实时确认：上游默认 main 指向 6337fc823ce20251c8de8085948165c81aaa701e；Root main 为 8e3db868b1d18cfb138f5bae8200136ecc27c112（仅此取证时点）。
- 核读上游文档 000～008、典型核心文件及目标仓库治理/执行/恢复接口；统计仓库 tree。
- 本次未运行上游 pnpm check、Root local full CI 或真实 Runtime pilot；任何 PR CI 结果以后续 GitHub 实际回执为准。
- 禁止 Codex/Work 调度；GitHub connector 的仓库/PR 操作为独立手段。

## 下一次接续

先检查是否已存在新的 owner decision / 在途同主题 PR / engineering-platform #228 新证据；只有不同且已授权的增量才继续。不要重复 DS-00，也不要补造任何缺少的实际运行、审核或产品测量。