# Last Verified Product Baseline

- updated_at: 2026-08-24
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-08-24
- root_product_commit: e136a9f7b310282ee20b867adb2e2894991c157b
- agent_dev_kit_commit: 792a4cb91965d1150fea61d474787072a4cae248
- agent_dev_kit_release_commit: 792a4cb91965d1150fea61d474787072a4cae248
- adk_previous_commit: 6d11503d54c8e9f661d039652549a1d6cefb6b35
- adk_version: 4.0.0
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: applied-declarative-no-op
- knowledge_candidate_status: captured-reviewing
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本基线记录 ADK 4.0.0 Runtime Control 的破坏式单轨切换。ADK `792a4cb` 与 Codex `c846a8e`
已推送；Codex source-to-live 已执行 build、doctor、plan、dry-run、apply 和 post-apply check，
live drift 为零。ADK 映射目录 `agents/skills/optional-skills/workflows/templates` 在
`6d11503..792a4cb` 间无内容变化，因此 ADK handoff 决策为 `applied-declarative-no-op`；
Runtime Control wheel 由 Codex manifest 独立锁定版本与 SHA-256。

软件控制面保持 M3 / M5-ready，M5 certified 仍为 false。历史 Codex/Claude campaign、独立仓、
第二位 human operator、30 天现场周期和必需 field events 未补齐，不能提升到 final 4.1.0。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK source | PASS | `792a4cb` pushed，version/schema `4.0.0` |
| ADK full | PASS | `62/62` |
| Runtime Control | PASS | Engine 8/8；wheel SHA-256 `dd64702c...b5a79a6` |
| Upgrade/rollback | PASS | `3.1.0-rc.7 -> 4.0.0`，40 项安装、40 项恢复 |
| Codex full | PASS | `154/154`，五 profile smoke |
| Source-to-live | PASS | plan already-applied，effective changes 0 |
| Live health | PASS | `changed=0 stale=0 unmanaged=0` |
| Root release metadata | PASS | lock/current-status/M5/phase-gate synchronized |
| Software M5 certification | BLOCKED | readiness pass；field/runtime campaign blockers retained |

## Delivery Boundaries

- Runtime Control 只保留一个 Engine、Journal、manifest 和 CLI；无 alias、双读、双写或旧状态迁移。
- 旧 token monitor、execution guard、usage/session coach、goal template 和 ready wrapper 已从 active/live 路径删除。
- Journal 不保存 prompt、messages、目标原文或真实 cwd；wheel 版本/摘要不匹配时 fail closed。
- 本轮未创建 tag、GitHub Release 或上传远端二进制制品。
- Knowledge Hub 未新增 memory；耐久事实保存在版本化 change、review 和 release evidence 中。

## Remaining Evidence

1. 完成 Claude 认证与冻结的双 runtime campaign。
2. 补齐独立真实软件仓、第二位 human operator 和不少于 30 天的 field evidence。
3. 由独立 reviewer 记录最终 pilot review 后，才评估 final 4.1.0 promotion。
