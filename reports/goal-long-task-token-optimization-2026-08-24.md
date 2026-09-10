# 4 小时 Goal：长任务、Token 与完成验证优化报告

- review_status: reviewing
- captured_at: 2026-08-24
- scope: llm_agent + agent-dev-kit working tree
- raw_content_stored: false
- release_authority: none

## 结论

本轮形成四项可审查的生产源改进，并修复两项治理基线问题：

1. `devkit.sh token monitor`：实时消费 canonical usage JSONL，输出累计 Token、预算比例、速率、
   ETA、ok/warn/critical/exhausted 与 continue/checkpoint/compact/stop 建议；支持幂等 delta/snapshot
   和原子恢复 state。
2. `devkit.sh execution guard`：机器验证长任务 heartbeat、staleness、retry、连续无信息 heartbeat、
   checkpoint、open items、required evidence 和 completion claim；可消费 token summary，但动作始终
   `advisory_only`。
3. `workflow.sh verify` fail closed：修复 Bash 条件上下文抑制 `set -e` 后，前置 strict gate 失败被
   后续 format 成功覆盖的假 `verified`。
4. Official freshness：默认日期统一为 UTC 并在 summary 披露 date basis；逐条复核 27 条 OpenAI
   官方来源并刷新 90 天 freshness，不改变 adoption decision。
5. Reference dirty governance：OpenSpec/superpowers/vibeflow fingerprint、数量和分类完全匹配旧基线；
   生成 report-only triage 后仅刷新复审窗口，不修改参考仓。
6. Removal fixture：更新 dirty baseline/adoption matrix 的 evidence hash；plan 仍为 dry-run、
   `apply_supported=false`、`repository_deleted=false`。

## 外部实践与迁移边界

- OpenAI Agents SDK：逐 run usage、checkpoint usage、trace/span；迁移为 canonical usage 与可恢复计数，
  不引入 SDK/runtime。
- LangGraph：checkpoint/thread cursor/interrupt 重放要求副作用幂等；迁移为 event fingerprint、
  snapshot 单调和 state-before-output。
- Temporal：event history、deterministic replay、heartbeat/retry；迁移为 long-task state guard，
  不引入 worker/server。
- Anthropic context editing/prompt caching：Token 阈值可驱动 tool-result clearing，但清理会影响缓存；
  因此只建议 compact，不自动执行。
- OpenAI 官方来源：Skills progressive disclosure、tracing/evals、context trimming/compression、plugin
  tool hints/正负测试、macro eval regression promotion 仍有当前一手证据。

Source URLs：

- https://openai.github.io/openai-agents-python/usage/
- https://openai.github.io/openai-agents-python/tracing/
- https://docs.langchain.com/oss/python/langgraph/interrupts
- https://github.com/temporalio/sdk-python
- https://platform.claude.com/docs/en/build-with-claude/context-editing
- `agent-dev-kit/manifests/official_docs_freshness_gates.json` 中 27 条 OpenAI official URL

## 关键验证

| Scope | Evidence | Result |
|---|---|---|
| ADK supported full | Python 3.11 isolated source `268dc95b…` | 63/63；strict/format/targets/routing 30/30/wheel/dependency audit pass |
| ADK host quick | `tests/run_all.sh --quick` | 25/25 |
| Token monitor | `tests/test_token_monitor.sh` | 8/8 |
| Execution guard | `tests/test_execution_guard.sh` | 5 methods，覆盖 fresh/stale/future/retry/no-progress/token/completion/security |
| Workflow lifecycle | `test_workflow.sh` + fail-closed fixture | pass |
| Official freshness | official gate + cross-TZ | pass |
| Root goal capability | Token + execution guard + benchmark | pass |
| Root quick working-tree | `check-all.sh --quick --working-tree` | 51/55；4 个 release/status gate 未闭环 |
| Root tests | `tests/run_all.sh` | 18/20；2 个均由 stale Software M5 snapshot 阻断 |
| Reference triage | schema v2 report-only | 3/3 fingerprint/classification match，status=pass |

## 被证伪路径

- “`set -e` 会自动传播函数内失败”：在 `if ... && function` 上下文不成立；必须显式短路。
- “heartbeat 新鲜等于任务有进展”：空 heartbeat 可无限续命；必须单独计数 no-progress heartbeat。
- “同 scope 可混用 delta/snapshot”：会双计；现在 fail closed。
- “先输出 decision 再写 state 也可恢复”：state 写失败会分叉；现在先原子持久化再 flush。
- “延长 expiry 就能修复 official gate”：拒绝；先逐页核验，再只更新匹配条目。

## 当前未闭环与边界

1. `adk.lock` 仍指向 `9bd0afa...`，当前 ADK HEAD 为 `302378e...`；不 commit 时不能更新锁定提交。
2. current-status/Software M5 release rehearsal 与当前工作树 manifest digest 不一致；必须在 owner review、
   commit 后重新生成 release evidence，不能复用旧 scorecard。
3. `subrepos/phase-gate.env:next_review_by=2026-08-22` 已过期；需要独立治理复核决定是否开门，
   本轮不自动改变 phase gate。
4. 五个 ADK change 均完成 author self-review、blocker/major=0 和机械验证，但 owner/independent semantic
   review 仍 pending，因此不声明可合并/可发布。
5. 未实现真实 Codex/OpenAI/Claude adapter pilot；fixture 证明 contract，不证明真实 provider integration。
6. 未执行 source-to-live 或 `~/.codex` apply；本轮不改变 live runtime。

## 回滚

- Token/guard：删除新增 module/CLI/test/docs/root gate 行；state schemas 为 additive，无迁移。
- Verify：恢复旧两行会重新引入假绿，不建议回滚。
- UTC/freshness：恢复日期/summary 字段会恢复 host/CI 分叉或 expired gate。
- Dirty baseline：恢复三条旧复审日期会让 reference triage 重新阻断；参考仓内容未被修改。

## 下一步（最多三项）

1. Owner/independent review 五个 change，重点核对 canonical usage、completion semantics 和 official redirect。
2. 在 commit 后重建 `adk.lock`、current-status 与 Software M5/release rehearsal 证据，再跑 release-clean gate。
3. 为一个真实 runtime adapter 做 report-only pilot：采集 usage counts -> token monitor -> execution guard，
   验证 checkpoint/compact/stop 建议但不自动执行副作用。

## Knowledge Archive Candidate

- Topic: `long-task-token-completion-guardrails`
- Sanitization: pass；无 secrets、raw prompts、完整日志、runtime state。
- Provenance: 本报告、五个 ADK change、确定性测试与上列官方来源。
- Memory candidate: no；先保持 reviewing，不自动提升为 AGENTS/memory。
- Gate result: pass as reviewing candidate；active promotion requires owner review。
