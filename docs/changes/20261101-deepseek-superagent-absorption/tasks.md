# Tasks — DeepSeek Superagent 有界吸收与验收队列

**最新远端复核：2026-11-01 03:26 UTC。** 本文件区分“研究与方案、ADK 方法合同、工程平台软件交付、宿主运行行为与产品资格”。`DONE` 只能标记有精确源码、原生 CI、合并与必要 fresh-main 证据的**限定范围**；不能从一个仓库的成功推断别仓 / real-host / field / live model 已认证。来源研究 PR [Root #285](https://github.com/jiying2007/llm_agent/pull/285) 已正式合并为 `bdacc52b676e9b82df2bd1f04f6216cb71ed5d20`，保留原始独立评估文件而不重新研究。

| ID | 优先级 | 当前状态 | 唯一责任/实际证据/下步 |
| --- | --- | --- | --- |
| DS-00 固定源码与差异评估 | P0 | **DONE — 研究/设计资产** | Root owner；上游 `deepseek-ai/dsh-superagent-prototype@6337fc823ce20251c8de8085948165c81aaa701e`，Root [#285](https://github.com/jiying2007/llm_agent/pull/285) 合并，原生 [CI #41260837234](https://github.com/jiying2007/llm_agent/actions/runs/41260837234) SUCCESS。不得冒充上游 Runtime 生产认证。 |
| DS-01 独立采纳决策 | P0 | **WAITING_OWNER_DECISION — 未伪造** | `docs/absorption-governance.md` 的 `external-practice-decision/v1` 需真实独立 owner decision / provenance。用户已广泛授权执行，但不能由 collector / automation 自称签署正式 owner judgment；保留缺项，不能反向造审批。 |
| DS-02 ADK 授权/续行/低打扰方法 | P0 | **IMPLEMENTED / WAITING_INDEPENDENT_REVIEW** | ADK [PR #229](https://github.com/jiying2007/agent-dev-kit/pull/229) 8.1.5 source candidate，精确 head `4174d208282587970183db0516a02d0048959e3e`。Python3.8/3.11/3.12 contract + security SUCCESS；完整 regression 因8.1.4 Harness 旧审核对新源码失效而 FAIL，详见 [#41262670775](https://github.com/jiying2007/agent-dev-kit/actions/runs/41262670775)。一次性独立 AI 审核任务已提交执行平台，未读到 PASS 前不标 DONE、不合并、不提升 Root pin。 |
| DS-03 GitHub Source 防漏事件测试 | P0 | **NOT VERIFIED / NOT CLAIMED** | Source/cursor 实际 owner；尚无本轮对应同事件 ID、旧 Thread 晚到消息、分页/429/重启游标与去重的原生回放验收证据。以既有 owner 找到的实际 Source 行为及 CI 为准，不从 ADK Skill 文本推导已实现。 |
| DS-04 Thread 归属与 Task follow-up | P1 | **BLOCKED BY RECOVERY AUTHORITY** | engineering-platform owner，#228 Action no-replay Recovery、#229 PostgreSQL Context 生命周期仍 [OPEN](https://github.com/jiying2007/engineering-platform/issues/228)。既有 WorkItem/Worker/Action Gateway 是唯一执行面；不得复制 DSH Ticket/Router / 额外高权限运行器。真实超 scope hand-back 和 resumed access 仍需宿主测试。 |
| DS-05 人类行动投影和通知 | P1 | **SOFTWARE_SUBSCOPE DONE / ACTUAL NOTIFICATION NOT CERTIFIED** | 工程平台 [#303](https://github.com/jiying2007/engineering-platform/pull/303) 已正常保护合并 `main@992b5ab448c215db4e1b26e1490890b055c4a39f`；PR exact-head [5/5 CI #41265983621](https://github.com/jiying2007/engineering-platform/actions/runs/41265983621) SUCCESS，独立主线 [5/5 CI #41267196247](https://github.com/jiying2007/engineering-platform/actions/runs/41267196247) SUCCESS，[pre-live #41267196200](https://github.com/jiying2007/engineering-platform/actions/runs/41267196200) SUCCESS。新 `GET /api/v1/operations/attention` 仅只读投影并 fail-closed；实际通知发送/去重/rearm、最终真实宿主及 SLO 无本轮证据，不能标整项 DONE。 |
| DS-06 有界 A/B / 宿主与产品资格 | P2 | **BLOCKED / NOT RUN** | 独立 qualification owner：固定 baseline 和真实 Source／Task 回放、误触发漏触发、人工打扰次数、回复时延、成本和效果、回退/取消；不能从 GitHub CI 或 prompt 语义推断改进百分比。工程平台 #105 / #106 真实 unattended provider 与部署仍 OPEN。 |

## 本轮进展与精确证据

1. Root 研究到主线：[#285](https://github.com/jiying2007/llm_agent/pull/285) / `bdacc52b676e9b82df2bd1f04f6216cb71ed5d20`。
2. 工程平台局部软件交付：[#303](https://github.com/jiying2007/engineering-platform/pull/303) / `992b5ab448c215db4e1b26e1490890b055c4a39f`；5 required PR CI + 5 distinct fresh-main CI SUCCESS，pre-live SUCCESS；仅授权零模型回合 Codex 兼容验证，原日志 `model_turn_executed=false`、`credential_used=false`；没有付费模型回合、Work 或 Codex Cloud。原有工程平台 Issue [#293](https://github.com/jiying2007/engineering-platform/issues/293) 已保存交付复核。
3. ADK 8.1.5 方法吸收仍 **OPEN**：[#229](https://github.com/jiying2007/agent-dev-kit/pull/229) 真实来源绑定 Harness 独立审读、完整 3-Python CI、受保护合并、独立 fresh-main、immutable component release 都不得预报 PASS。若后续发布成功，Root 仍须按正常 `adk_promotion` exact-source lock/gitlink/attestation/受保护 PR 完成 8.1.5 提升；**不得在发布前预改 pin**。
4. 工程平台 #228 / #229 / #105 / #106 均实时确认仍 OPEN；软件交付不能关闭 Recovery、Context、真实 Provider、unattended 产品资格。实际通知/事件日志和 A/B 均没有 source-to-live、现场或人工体验证据。
5. 上游研究是方法参考；不 clone/启用其 `danger-full-access` Worker，不保留平行 Runtime；Context、工具输出、机器人评论均不得自行升级权限。

## 唯一恢复路径

优先等**真正独立**的 ADK #229 AI 审核回执：缺少就继续 BLOCKED，不能凭 automation 已创建、self-review 或旧8.1.4证据放行；完成后核 PR-head 全 CI、Release、Root exact-source promotion。DS-03/DS-04/DS-05 实际通知部分需从**现有 Source/Platform owner** 与真实代码/验收补全，不在本 research 任务里额外启动竞争工作。只在新证据到来后更新此表；不得为“全部闭环”伪造 owner decision、模型费用、实测性能或 Product READY。
