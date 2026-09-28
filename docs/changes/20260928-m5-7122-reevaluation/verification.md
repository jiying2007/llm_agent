# 重评准备验证

- `runtime_smoke_evidence` 的当前 ADK 入口、费用确认、缺能力阻断与采集期间源码漂移拒绝：Python 3.11 provider-free 单测 4/4。
- 原始报告收集：正例通过；缺 task-set 身份、逐例模型错配、请求/观测模型不一致、重复字段、非有限 JSON 数字和 dirty ADK source 的负例均拒绝写证据；已有 M5 rollover 事务正反例通过。
- rollover 以当前 UTC 日期核证据 review window 与状态投影；正例在隔离 fixture 中通过，过期证据、回填资格时间与缺签名验证器的负例均在写入前失败，fixture 状态未改变。正例的 mock cosign 只验证调用边界，不代表真实签名通过。
- rollover 现在要求 clean 根仓基线。测试仅在 `/tmp` 内冻结 fixture commit；注入未跟踪文件后，命令明确返回 `Software M5 rollover requires a clean root source worktree` 且不改变 fixture 状态。
- 根仓最初更新 ADK pin 前的 `check-all --quick --working-tree` 为 49/52；7.12.4 main exact pin 与新签名证据的 `check-all --full --working-tree` 为 55/58，工作树指纹稳定。签名、harden、performance 与 root regression 通过；剩余参考仓 baseline、M5 readiness 与衍生 evidence bundle 三项阻断。
- 当前根仓 ADK checkout 为 clean `35b5fb31810c654a295c25b89e04435d6a32f57c`，与 gitlink、`adk.lock` 和 interface lock 一致；ADK 7.12.4 普通 clone 全套 96/96、GitHub main 三版本 CI 与签名 promotion 通过。`eval run --help` 包含 `--max-new-results` 与 `--approve-unknown-cost`。历史 `c8b57b5…` 报告缺新身份字段，collector 仍会拒绝。
- 经明确授权已执行一次 `gpt-5.5` / `limit=1` 的真实 Codex CLI 0.156.1 smoke：路由和安全质量门禁均通过，但 CLI JSON 事件没有可核验的观测模型，raw report 的 `reported_models=[]`。collector 按合同拒绝签发 measured evidence；原始报告仅留 `/tmp`，未纳入仓库，未重试。详情见 `negative-results.md`。
- 当前 SHA 仍没有合格的 measured runtime evidence，未执行 rollover `--apply`。Software M5 保持 blocked，status projection 的 `release_authorized=false`。7.12.4 Sigstore promotion 不能替代 M5 运行测量。

下一门槛：解决 Codex CLI 观测模型身份缺失并重新明确模型费用授权；在 root fresh integration 后获取可核验的真实 smoke，再用 7.12.4 的合格证据执行事务 rollover 和 certifier。
