# 模型调用 Token 与费用预算：运行时接入

## 状态

Root 提供纯标准库的模型调用预算组件 tools/codex_assets/model_call_budget.py；不调用任何模型、不接收 prompt、不传输密钥。清单 manifests/model_call_budget.json 的状态是 requires-host-integration。**提交此代码不代表当前 Codex / API 中转站已开始拦截请求。**

预算参数基于 2026-11-09 用户账单提出：272K 为该渠道报告的分档阈值，不能外推到所有模型和代理。接入前必须与提供商真实 Token 计数、报价和账单核对。计时使用北京时间自然日，费用单位为人民币分。

## 唯一可信调用入口：两段式

1. Runtime / 网关使用真实 tokenizer 与完整请求消息计算保守输入上界 input_tokens_bound，配置 max_output_tokens；依渠道价目表计算 quoted_max_charge_fen。不能把 UTF-8 字节数等同 token，更不能相信模型自己提供的数字或审批。
2. 每次调用生成不可重复 request_id，绑定 workflow_id、session_id、model；只提供数字与脱敏标识，不把 prompt、工具日志、会话历史、密钥放入预算账本。
3. **调用前 reserve**：只有退出码 0 且 status=allow 时允许发送模型请求。hold 必须先压缩上下文或经证据支持的 replan；blocked/error 不可发送。为避免网络结果不明后重复扣费，同一 request_id 重放会被拒绝。
4. **调用后 settle**：以可信中转的原始 Usage 计量、缓存输入、输出 Token 与实际 billed_fen 结算。若已经发送但 usage 不可用，settle 使用 outcome=unavailable，四个计费/用量字段填 null，并保留最初预算预留，不能视作免费。
5. 只有调用方验证了新测试、commit 或真正阶段产物，才记录 progress_evidence_sha256；没有可验证成果时填 null。连续三次无进展后需通过验证真实变更的 replan，而非简单 heartbeat。
6. 通过 report 按 workflow 汇总日 Token/成本，只有接入真实中转账单并验证身份后才能声称 provider-billed；默认回执 billing_verified=false。

## 格式样例

~~~json
{
  "schema": "llm-agent-model-call/v1",
  "request_id": "call-001",
  "workflow_id": "llm-agent",
  "session_id": "session-001",
  "model": "gpt-6.1-sol",
  "input_tokens_bound": 48000,
  "max_output_tokens": 4096,
  "quoted_max_charge_fen": 80,
  "compaction_checked": false,
  "risk": "normal",
  "exception": null
}
~~~

~~~bash
python3 -m tools.codex_assets.model_call_budget \
  --state "$HOME/.local/state/llm-agent/model-call-budget.json" \
  reserve --request /safe/input/request.json

python3 -m tools.codex_assets.model_call_budget \
  --state "$HOME/.local/state/llm-agent/model-call-budget.json" \
  settle --usage /safe/input/settlement.json

python3 -m tools.codex_assets.model_call_budget \
  --state "$HOME/.local/state/llm-agent/model-call-budget.json" report
~~~

结算 JSON 全字段为：schema=llm-agent-model-call-settlement/v1、request_id、outcome (success/error/unavailable)、input_tokens、cached_input_tokens、output_tokens、billed_fen、progress_evidence_sha256（无可信进展填 null）。重规划命令是 replan --workflow-id ... --session-id ... --evidence-sha256 ...；仅上游真正验证新的决策或阶段产物后才可使用。

## 限额初值及优化动作

| 维度 | 初始配置 | 行为 |
|---|---:|---|
| 单次输入目标 | 48K | 超过目标提示，非自动失败 |
| 压缩触发 | 96K | 必须先压缩，保留原始证据 |
| 软上限 | 128K | 超过须审查/例外 |
| 默认硬上限 | 200K | 未经批准不调用 |
| 渠道高价阈值 | 272K | 外部批准+真实渠道价目核对 |
| 每 workflow 日调用 | 256 次 | 默认阻断超额 |
| 每 workflow 日 Token 额度 | 25M | 预留+结算控制，包括缓存输入 |
| 每 workflow 日费用 | ¥200 | 单 workflow 配额，不替代全局上限 |
| 共享账本日费用 | ¥200 | 全局跨 workflow 累计，不可拆账本绕过 |
| 共享账本日调用 | 512 次 | 各工作流合计 |
| 共享账本日 Token | 50M | 各工作流合计 |
| 无有效进展 | 连续 3 次 | hold + evidence-bound replan |

高风险例外要求 host 独立核验审批后，再携带审批 ID 和原因码，并启用 --allow-reviewed-exception。CLI 标志本身 **不构成权限控制**；模型文本不能自我审批。

模型降级策略：只在探路、检索、日志摘要等低风险任务选择经质量验证的轻量模型；涉及安全、发布、架构、代码审查或不明根因时保留高能力模型。分级选型不硬编码具体提供商价格或名称。

减少上下文的执行规则：任务开始先 L0 项目地图，读取一个 primary Skill，references 和工具 schema 只在触发时加载；工具默认提供不超过约 2K Token 的相关摘要及 raw_evidence 可回读位置，禁止重复灌入整个日志；阶段切换只携带成功标准、当前差异、未解决问题、验证工件和最多三个下一步。尽量用 GitHub Actions 事件驱动替代模型轮询 CI。不可为节省 Token 丢弃安全/权限/迁移等原文证据。

## 部署与验收限制

- 文件锁和原子写入仅约束**共享本地状态路径的同一主机**；多主机或多容器要由真正网关使用中心化原子计数器，不能靠不同本地状态文件自称全局限额。
- 组件不是模型代理或透明网络拦截器；不在每次真实请求前调用 reserve 并拒绝非 allow 时，就没有成本控制效果。请求报价、Token 上界、审批和证据都必须来源于不可被 Agent 任意伪造的 trusted host。
- 实际落地分为：一次历史脱敏请求 shadow replay → 网关集成 → 端到端高价拒绝测试 → 扣费对账和完成质量 A/B 回归 → 更新状态。未获得以上实际运行证据，不声明真正节约人民币。
- 不修改 ADK gitlink/跨仓锁、Sigstore、现有 KWS 工作流和 Codex / ChatGPT Work 共享额度。

~~~bash
bash tests/test_model_call_budget.sh
~~~

测试必须覆盖 200K/272K、压缩前置、128K 软审查、预算超额、并发预留、结算缺失、重复 ID、无进展、软/硬异常和不可相信的报价。单元测试证明的是本地逻辑，不能替代真实 provider 集成证据。
