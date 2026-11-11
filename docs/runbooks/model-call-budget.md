# Goal / Loop Token 效率与模型调用观察

## 状态与唯一职责

统一实现：tools/codex_assets/model_call_budget.py；策略：manifests/model_call_budget.json。
此文件是可信模型调用执行器的无模型、无 prompt 控制组件，不是另一套 Goal 调度器。
当前仍标记 requires-host-integration：尚未接入真实中转站，因此不能宣称已优化真实账单。

**本策略没有每日人民币费用上限，也没有每日总调用次数或 Token 的硬停止规则。**
费用、缓存命中、工作流日 Token 只作为观测指标。不能以 ¥200/日为目标阻断有效 Goal。
用户投入应该用“验证通过的里程碑 / Token”和“有效工作轮次”衡量，而不是靠切断预算改善统计。

## 请求前：轻量化但不丢关键证据

可信 Host 对完整请求计算真实 input_tokens_bound；不要用字节数或仅凭缓存命中率代替测量。
调用每次带固定 schema=llm-agent-model-call/v2 和：
- request_id、workflow_id、session_id、model；
- goal_id / phase_id：有明确 Goal 时带稳定 ID；其他任务设 null，不伪造目标；
- context_sha256：对完整待提交请求的规范字节求 SHA-256；没有可验证摘要设 null。仅在同一 Goal / Phase 内，同一个摘要重复才进入 hold，不能单看长度就认定重复；
- input_tokens_bound、max_output_tokens、compaction_checked、risk、exception；
- quoted_max_charge_fen：可填 null，零或非负整数；**只记录报价，不是允许调用的条件或成本上限**。

示例：

~~~json
{
  "schema": "llm-agent-model-call/v2",
  "request_id": "call-unique-001",
  "workflow_id": "main-research",
  "session_id": "session-001",
  "goal_id": "goal-123",
  "phase_id": "slice-1",
  "context_sha256": null,
  "model": "gpt-6.1-sol",
  "input_tokens_bound": 48000,
  "max_output_tokens": 4096,
  "quoted_max_charge_fen": null,
  "compaction_checked": false,
  "risk": "normal",
  "exception": null
}
~~~

运行（状态路径须由真实 Host 自己管理，以下只展示离线本地调用形式）：

~~~bash
python3 -m tools.codex_assets.model_call_budget \
  --state /tmp/model-call-ledger.json reserve --request /tmp/request.json
python3 -m tools.codex_assets.model_call_budget \
  --state /tmp/model-call-ledger.json settle --usage /tmp/settlement.json
python3 -m tools.codex_assets.model_call_budget \
  --state /tmp/model-call-ledger.json report
~~~

只有 reserve 返回 status=allow 且 exit 0 时才可发送模型请求。hold 表示先压缩或重规划；
blocked / error 不应发送。原始证据保留在外部受控文件，模型默认只获取局部检索窗口。
不自动重试请求 ID，远程写操作结果未知时先对账。

## 上下文优化（不是按日截断）

| 输入上下文 | 默认动作 |
|---|---|
| ≤48K Token | 目标范围；根据需求读取必要原文 |
| ≥96K | 先输出带证据引用的阶段摘要，缩小下一轮上下文 |
| >128K | 常规任务暂停并检查是否需要读全量材料 |
| >200K | 常规任务阻断，需要受信 Host 的明确高风险例外 |
| ≥272K | **仅记录该账单渠道的长上下文价格档位告警**，不是费用阻断规则 |

高风险任务可以在可信 Host 真正审核后使用 reserve(..., allow_exception=True)；
CLI 不提供可自批的高价例外。高风险权限/签名/迁移等证据不能因为压缩而缺失。

真实 Host 在调用 `reserve` 前，应先使用 [Goal/Loop 事件预检](goal-loop-token-efficiency.md) 判断当前是否需要模型；如果预检返回 `skip-model`、`run-tool` 或 `run-verification`，不要为了形成一条调用记录而额外发起模型请求。`needs-review` 不能被当作 `skip-model`。原始事件证据与 cursor 由 Host 核验和保存，不进入模型历史。

## 与原生 Goal/Execution Policy 的单一收敛权威

该模块仍是可信 Host 的**逐模型调用**安全/上下文保护，不拥有 Goal 权限或原验收的终态决策。
- **独立接入、无原生 Goal Engine**：`reserve` 默认的 3 轮无新增证据 `hold` 继续生效，防止盲目重发。
- **已验证的原生 Execution Policy**：只有真正可信的 Host 在同一 Goal/Thread 上独立核验了 canonical progress gate，且请求携带非空、已核实的 `goal_id`，该 gate 明确允许本次执行，才可通过 Python API `reserve(..., verified_external_progress_gate=True)` 将收敛控制委托给唯一引擎。该布尔值不是模型声明，也不是普通 CLI 开关；不表示 release、安全、合规或人工许可。
- 委托**仅**避免重复的 no-progress stop；相同完整上下文 SHA、请求 ID 幂等、单次 96K/128K/200K 上下文保护、必要原文审核和真实 Host 权限依然生效。可在响应中的 `progress_control` 与 `root_no_progress_observed` 核对来源。无受信原生 gate 时不得声称已委托。
- 静态 200K 是当前未接入时的保守保护值，不代表所有模型物理上下文窗口；真正 Host 尚未获证时不得任意放宽。校准需核对 provider 对应模型实际上下文窗口、保留输出和提示缓存行为及 A/B 验收。
- 两层的成本和目标收敛状态应当区分；绝不通过日费用/总调用数硬限停止有效 Goal。

## Goal / Loop 的高效率执行协议

1. **一目标一状态**：先读当前 Goal、验收 ID、受影响文件与最后 checkpoint（目标状态建议 ≤8 KiB）。长历史、全量日志、旧对话不自动注入；按需查原始证据指针。
2. **先本地再推理**：对确定性操作（目录定位、CI 状态、校验脚本、散列比对）使用本地工具与 GitHub Actions；不用强模型重复解释无变化的结果。
3. **执行可关闭批次**：一次选 1–4 个边界清晰的纵向交付，小修改用 targeted tests；一批闭合后才跑受影响的完整门禁，避免每个微步骤都做全量复审。
4. **按新证据判断进度**：仅接受当前 Goal 的真正新增验证产物、解决的新 blocker/假设或关闭的验收项；相同 evidence SHA 再上报不算进展。无新增证据的调用累加 nonclosing_calls。
5. **去重与反空转**：可信 Host 可提供当前 prompt/context 的 SHA；同 Goal / Phase 完全相同上下文不再次推理。连续三次没有验证新进展，停止盲重试并进入 replan；新 Goal 不继承旧 Goal 的停滞计数。
6. **重规划必须改变方案**：仅可信 Host 调用 Python API 的 replan(...)，并提供 prior_plan_sha256、revised_plan_sha256 和独立 evidence_sha256；前后计划相同、摘要无效时拒绝。模型不得自行申请重置。
7. **阶段交接而非整轮复述**：checkpoint 只存目标、正在执行的验收、已验证证据、关键未解决问题、最新 commit/CI 引用和最多三个下一动作；不向新阶段重新发送全部聊天。
8. **终态验收**：每一 Goal 完成时核对原始验收分母、真实证据和未关闭项；高风险场景仍保留完整审查。未完成的任务不得通过缓存命中率、测试数量或 token 下降冒充成功。

## 调用后：记录效果，不限制费用

settle 使用 llm-agent-model-call-settlement/v1；input/cached/output 为可观测整数；
billed_fen 可为 null（提供商未报告价格），不是零。没有任何 usage 时用 outcome=unavailable
并保留保守 Token 预留。需要报告区分真实观测与未知状态。

report 按 workflow、Goal 汇总：
- requests、tokens_allocated、cached_input_tokens_observed、unpriced_calls（没有报价/价格的次数）；
- goals 按可观测输入 Token 取前 10 项，列出 calls / input_tokens_observed /
  new_progress_events / nonclosing_calls / input_tokens_per_progress；
- 分母为零或存在未知 usage 时，input_tokens_per_progress 返回 null，不能伪造效益；省略更多目标详情，完整原始账本可回读；
- status=observed-not-provider-certified；不能用这些数字代替供应商原始账单。

既有本地 file lock 只保护单机共享存储；多机真实网关需要中心化幂等预留/结算，
不能绕过 host approval 或生产门禁。当前 Root 没有实际模型代理接入，仍需 Issue #322 的
真实 Token 轨迹与前后对照，不能声称真实费用已经下降。

## 验证

~~~bash
bash tests/test_model_call_budget.sh
~~~

重点验证：没有每日费用或调用量硬停止、跨 Goal 停滞互不污染、同 Goal/Phase 相同上下文拒绝重复、
同证据再次上报不算新进展、计划无变化不能重置、并发本地账本、无报价/usage 区分、
高风险例外仍由可信 Host 审批。
