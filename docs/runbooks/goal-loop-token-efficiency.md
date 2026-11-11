# Goal / Loop 事件预检、上下文增量与 Token 效果对照

## 定位与唯一边界

现有 ADK Goal、Execution Policy 和 Root model_call_budget 是权威；此处**不再创建 Loop 状态机、daemon、定时巡检或第二套费用预算**。
`tools/codex_assets/goal_loop_event_context.py` 是纯标准库、离线、只读的 **Host-side helper**：
对来自可信执行器的已验证事件元数据进行增量预检，输出最小上下文索引及是否需要模型判断的建议；
并对同一批真实任务的前后用量做配对对照。不得把测试绿、model_invocation_required=true、
简单 SHA 或模型输出冒充真实运行时授权与结果。

本仓库没有直连第三方 API 中转、ChatGPT Goal 或 Dot 宿主调度器。规则必须由实际 Host 在
**调用模型之前**执行，且由 Host 审核提交的 source SHA、事件和 evidence 来源；否则只是可接入实现，
不能声称已经省下真实 Token。现有 `model_call_budget` 的状态保持 `requires-host-integration`。

## 运行路径（不轮询模型）

1. **受信 Host 收集一份状态**：当前 Goal、阶段、source SHA、plan/state/event 哈希、
   事件类型、明确的下一动作和最多 64 个证据索引。完整工具日志、diff、CI 原始记录保留在外部。
   所有 input/previous 均为受信 Host 的机械事实；不能让模型自行编造新 SHA 或审批。
2. **仅调用一次确定性 preflight**：
   - CI pending、无待执行步骤、heartbeat → `skip-model`；即使 Host 残留旧 `pending_action=model`，
     无新增关键证据的普通风险等待事件也不得触发新模型轮次；高风险状态或新增 `critical` 证据 → `needs-review`。
   - 明确的确定性工具或验证 → `run-tool` / `run-verification`，不消耗 LLM 推理；
     但若事件为 `review_required`，必须先 `needs-review`，不得由旧的待执行工具动作绕过。
   - 用户目标变化、真正新的源码/CI 错误/审核要求、当前需要语义判断 → `invoke-model`。
   - 同 Goal、同阶段、相同规范化状态再要求模型判断 → `skip-model`；高风险重复/未知/证据溢出 → `needs-review`，绝不静默跳过高风险。
3. **模型仅接收 `llm_packet`**：目标与阶段标识、状态指纹、精简 changed evidence（最多8）和 raw_ref。
   不把整个 CLI JSON、`next_cursor`、历史聊天、完整工具响应或自动生成的会话日志重新注入模型。
   `deferred_evidence_count>0` 时，模型判断路径不会带着部分证据自行继续，需先取完整索引。
4. **阶段/事件完成后才记录 cursor**：如果需要模型、工具或定向验证，必须先核实对应调用结果与证据，
   再把 `next_cursor` 持久化为后续 `--previous` 的受控 JSON。
   预检刚生成时就更新 cursor 会造成漏执行；模型返回失败或结果未知时，沿旧 cursor 恢复并重新核对幂等。
   `cursor_commit_condition` 明确回执条件。
5. **只在原验收/风险要求时展开原文**：安全、权限、签名、接口升级、生产、未解释测试失败等必须可回读 L2/L3 原始材料；
   `raw_ref` 是索引而非信任指令。Host 必须自行验证原文哈希、完整性、权限与覆盖范围。

## 输入示例

```json
{
  "schema": "llm-agent-goal-loop-snapshot/v1",
  "workflow_id": "embedded",
  "goal_id": "g-100",
  "phase_id": "p-1",
  "risk": "normal",
  "source_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "plan_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "state_sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "event_sha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  "event_kind": "ci_pending",
  "pending_action": "none",
  "observation_complete": true,
  "evidence": [
    {
      "id": "ci-123",
      "sha256": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      "raw_ref": "reports/ci-123.json",
      "priority": "normal"
    }
  ]
}
```

```bash
python3 -m tools.codex_assets.goal_loop_event_context \
  preflight --snapshot /safe/meta/now.json \
  --previous /safe/meta/previous-cursor.json
```

首次运行省略 `--previous`。本工具只返回 JSON，不创建状态文件、发网络请求或触发下一个调度；
真实 Host 从输出中持久化 `next_cursor`，并只在适用执行结果确认后更新。
状态缺项、事件查询不完整、旧 cursor 属于别的 Goal、非法路径/字段，返回非零而不是假装无变化。

## 现有 llm-ctl 入口与执行回执去重

无需新增 Python 入口或后台服务，既有控制面命令可以直接执行：

```bash
llm-ctl goal-loop preflight --snapshot /safe/meta/current.json
llm-ctl goal-loop preflight --snapshot /safe/meta/current.json --previous /safe/meta/acknowledged.json
llm-ctl goal-loop attribute --trace /safe/meta/usage.json
llm-ctl goal-loop compare --baseline /safe/meta/baseline.json --candidate /safe/meta/candidate.json
```

**只有成功执行并由 Host 验证过结果的 cursor 才能放入 `--previous`。**
当 Goal/阶段/事件/原始证据完全一致，第二次 `run-tool` 或 `run-verification`
不再重新执行，而返回 `skip-model` + `previously-acknowledged-unchanged-action`；
新 HEAD、新事件 SHA 或新的证据重新开放对应动作。高风险重复确定性操作必须复核，
不能仅凭有相同 cursor 就省略审查。单纯运行 preflight **不会**提交 cursor。

cursor 只是来源已由 Host 核实的事件观察记录，不是 Goal 终态或生产审批凭据；
`llm-ctl goal-efficiency` 可同时展示当前 ADK Goal 的状态和预检建议，
但观察报告不会输出未确认可提交的 next_cursor。Host 仍须执行并核实动作回执。

## Tool / Skill 与上下文瘦身

- 数据搜集优先本地脚本/GitHub API 一次性**批量查询**；`raw_ref` 保留完整可审计来源，
  `evidence` 只发送有实际 SHA 差异的记录，默认最多 8 条，不追加 100KB 原始 JSON。
- Skill 仍按 ADK 原生目录与 profile 动态发现，当前任务一个 primary Skill；references 只在命中后读取。
  不能为了减少 Token 而删除稳定缓存前缀：稳定规则/工具定义在前，新的 Goal/事件/差异放最后。
  对接支持缓存断点、延迟工具加载的实际提供商时，先做模型/工具兼容回归，再启用原生参数，
  **不要**向任何未验证的模型偷偷传入 OpenAI 特定字段。
- CI 等待、常规目录/文件列举、SHA 比对、状态相等比较应在 Host 代码中完成。
  **不能因为任务未完成就由 LLM 不断主动轮询；只在事件完成/失败/人工修订等新触发后恢复。**
- 控制费率不是本工具职责。保留 `manifests/model_call_budget.json` 的**无每日金额、Token、次数硬上限**；
  高频但真正有进展的 Goal 不应被一天配额卡死。

## 同任务真实 A/B：质量优先

以至少10个**真实** Goal/任务，冻结原始 task_id、验收分母与 task_set_sha256，
从实际 Host 的 usage/执行结果生成 baseline 与 candidate，两边相同任务集合：

```json
{
  "schema": "llm-agent-goal-loop-comparison-set/v1",
  "task_set_sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "source_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "tasks": [
    {
      "task_id": "goal-1",
      "completed": true,
      "verified_milestones": 1,
      "input_tokens": 12000,
      "cached_input_tokens": 11000,
      "output_tokens": 1000,
      "nonclosing_calls": 1,
      "repeated_context_calls": 0,
      "first_useful_action_ms": 1000
    }
  ]
}
```

以上仅是字段样例，不足10条**不能产生有效 A/B 结论**。不含 prompt、密钥、日志或私人文件。
`input_tokens` / `output_tokens` 缺失必须填 null，不得按0算节省。

```bash
python3 -m tools.codex_assets.goal_loop_event_context \
  compare --baseline /safe/meta/baseline.json \
  --candidate /safe/meta/candidate.json
```

对比真实 Token/验证里程碑、已完成目标、nonclosing_calls、重复上下文调用，
不能仅看 Token 下降；质量退化或任务集合漂移不允许成为晋级候选。
返回 `candidate_for_review=true` **只表示可提交进一步审核**，不是 release、Goal 完成、
生产效果证据或真实网关部署。不存在任何用户隐式背景任务或轮询。

## 请求级输入构成归因（先测再优化）

有真实模型 Host 时，建议将**供应商实际 usage** 与 Host 的逐段 tokenizer
计数统一成不含 prompt 的一份小型 trace。新命令处理最多 1 万条、4 MiB 的纯数字元数据，
即使像 11 月 9 日那样有 3,669 次调用，也只返回一份简短汇总。
没有来源可信的逐段计量，则不能把该天约 820M Token 强行分摊到某个 Skill 或日志文件。

~~~json
{
  "schema": "llm-agent-goal-loop-usage-trace/v1",
  "source": "provider-usage",
  "tokenizer_verified": true,
  "requests": [
    {
      "request_id": "req-1",
      "workflow_id": "research",
      "goal_id": "goal-1",
      "input_tokens": 50000,
      "cached_input_tokens": 48000,
      "output_tokens": 500,
      "segments": [
        {"kind": "rules", "tokens": 2000},
        {"kind": "tool_schemas", "tokens": 3000},
        {"kind": "history", "tokens": 40000},
        {"kind": "current_delta", "tokens": 4000}
      ]
    }
  ]
}
~~~

~~~bash
python3 -m tools.codex_assets.goal_loop_event_context \
  attribute --trace /safe/meta/provider-usage.json
~~~

支持的分段是 rules、tool_schemas、history、tool_results、project_source、
goal_state、current_delta、other。分段相加不得大于 provider 输入；
差额保留为 unattributed_input_tokens，不能凭空“分配”给历史或缓存。
tokenizer 未验证、存在差额时 attribution_status=PARTIAL。
统计每工作流输入总量、缓存比例、p50/p95、>272K 次数、零输出次数与最大构成。
这里的 272K 是**用户所提供渠道账单的观察口径**，不是所有模型通用的计价规则，也不是拒绝阈值。

缓存策略依据实际 provider API 能力评审：稳定系统/工具前缀在前，增量证据在后；
新模型支持的显式缓存断点与延迟工具加载，需要先通过目标 provider 支持性和
同任务成本/正确性对照，再配置。不可频繁压缩而让 97.6% 的既有缓存优势全部失效。
不传入未经验证的新参数，不借优化改变审批、安全和完整验收。

## 本地和 CI 验证

```bash
bash tests/test_goal_loop_event_context.sh
bash tests/test_model_call_budget.sh
```

负例重点：不同 Goal/cursor 混用、重复工具证据、伪造 raw_ref、CI 不完整、首次与重复执行、
高风险复审、证据溢出、测试效果样本小于10、任务集合漂移、缺失 usage、验收退化。
该检查与现有 `tests/run_all.sh` 的机械回归互补，不代表有真实模型 Token 收益。
