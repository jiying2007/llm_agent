# Last Verified Product Baseline

- updated_at: 2026-08-30
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-08-30
- root_product_commit: e136a9f7b310282ee20b867adb2e2894991c157b
- agent_dev_kit_commit: c9a28b2e5afd9f30634a7215730539323895236e
- agent_dev_kit_release_commit: c9a28b2e5afd9f30634a7215730539323895236e
- adk_previous_commit: 792a4cb91965d1150fea61d474787072a4cae248
- adk_version: 5.0.0-rc.1
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-owner-attested
- m5_campaign_status: blocked-full-campaign-and-field-pending
- live_refresh_status: required-pending-owner-authorization
- knowledge_candidate_status: captured-reviewing
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本基线记录 ADK `5.0.0-rc.1` 平台收敛候选。ADK `c9a28b2` 已推送至 `origin/main`；
`4.0.0 -> 5.0.0-rc.1` checksum-bound upgrade/rollback rehearsal 通过并恢复 34 项资产。
映射目录在 `792a4cb..c9a28b2` 间有变化，因此 source-to-live 保持
`required-pending-owner-authorization`，本轮没有写入 `~/codex` 或 `~/.codex`。

Claude Code 由 repository owner 显式裁决为默认通过，证据层为 `owner-attested`、
`runtime_measured=false`；这关闭默认使用决策，不替代 native conformance receipt 或正式 campaign。
软件控制面保持 M3 / M5-ready，M5 certified 仍为 false。双 runtime measured campaign、独立仓、
第二位 human operator、30 天现场周期和必需 field events 未补齐，不能提升到 final 5.1.0。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK source | PASS | `c9a28b2` pushed，product `5.0.0-rc.1` / manifest schema `4.0.0` |
| ADK full | PASS | `68/68` |
| Supported parity | PASS | Python 3.11/3.12 quick 各 `29/29`，routing `30/30`，wheel/audit pass |
| Upgrade/rollback | PASS | `4.0.0 -> 5.0.0-rc.1`，34 项安装、34 项恢复 |
| Claude default decision | PASS | owner-attested；不冒充 runtime-measured campaign |
| Source-to-live | PENDING | mapped content changed；等待独立 owner authorization |
| Root release metadata | INTEGRATING | working-tree SSOT 已更新；父仓 commit 尚未授权 |
| Software M5 certification | BLOCKED | readiness pass；field/runtime campaign blockers retained |

## Delivery Boundaries

- Runtime Control 只保留一个 Engine、Journal、manifest 和 CLI；无 alias、双读、双写或旧状态迁移。
- 旧 token monitor、execution guard、usage/session coach、goal template 和 ready wrapper 已从 active/live 路径删除。
- Journal 不保存 prompt、messages、目标原文或真实 cwd；wheel 版本/摘要不匹配时 fail closed。
- 本轮未创建 tag、GitHub Release 或上传远端二进制制品。
- Knowledge Hub 未新增 memory；耐久事实保存在版本化 change、review 和 release evidence 中。

## Remaining Evidence

1. 执行冻结的双 runtime measured campaign；owner attestation 不替代结果矩阵。
2. 补齐独立真实软件仓、第二位 human operator 和不少于 30 天的 field evidence。
3. 由独立 reviewer 记录最终 pilot review 后，才评估 final 5.1.0 promotion。
