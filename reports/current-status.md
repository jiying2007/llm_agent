# Last Verified Product Baseline

- updated_at: 2026-08-30
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-08-30
- root_product_commit: 048793deb838029e98073d51083e01d8a29f1f48
- agent_dev_kit_commit: 12bfeaf1f85b297628b57ac15d12eedc849e3919
- agent_dev_kit_release_commit: 12bfeaf1f85b297628b57ac15d12eedc849e3919
- adk_previous_commit: 792a4cb91965d1150fea61d474787072a4cae248
- adk_version: 5.0.0-rc.2
- product_maturity: M3
- software_m5_readiness: not-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-current-smoke-pass-claude-owner-attested-v2
- m5_campaign_status: blocked-full-campaign-and-field-pending
- live_refresh_status: required-pending-owner-authorization
- knowledge_candidate_status: captured-reviewing
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本基线记录 ADK `5.0.0-rc.2` 平台收敛候选。ADK `12bfeaf1` 已推送至 `origin/main`，
候选制品绑定 clean commit/tree 且 `release_eligible=true`。原 `4.0.0 -> 5.0.0-rc.1` rehearsal
已被全面复审判定无效：previous artifact
`1241d345...` 混入 5.x working-tree 内容，既不等于历史正式制品 `4c1e9b3c...`，也不等于
`792a4cb` exact rebuild `8eb5253d...`。正式 4.0 artifact 当前不可用，release readiness fail-closed。
`792a4cb` exact rebuild 到 `12bfeaf1` 的诊断 transition 通过，但不替代官方制品连续性。
映射目录在 `792a4cb..12bfeaf1` 间有变化，因此 source-to-live 保持
`required-pending-owner-authorization`，本轮没有写入 `~/codex` 或 `~/.codex`。

Claude Code 由 repository owner 显式裁决为默认通过，证据层为 `owner-attested`、
`runtime_measured=false`；这关闭默认使用决策，不替代 native conformance receipt 或正式 campaign。
软件控制面保持 M3 / source-ready，Software M5 readiness 为 not-ready、certified 为 false。除 release rehearsal 外，双 runtime measured campaign、独立仓、
第二位 human operator、30 天现场周期和必需 field events 未补齐，不能提升到 final 5.1.0。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK source | PASS | `12bfeaf1` pushed，product `5.0.0-rc.2` / manifest schema `4.0.0` |
| ADK full | PASS | `68/68` |
| Supported parity | PASS | Python 3.11.15/3.12.13 full 各 `68/68`，routing `30/30`，wheel/audit pass |
| Upgrade/rollback | BLOCKED | 正式 4.0 artifact 不可用；污染 previous artifact 的 pass 已失效 |
| Claude default decision | PASS | owner-attested；不冒充 runtime-measured campaign |
| Source-to-live | PENDING | mapped content changed；等待独立 owner authorization |
| Root release metadata | PASS | `048793d` pushed；gitlink/lock/current-status/M5 SSOT synchronized |
| Software M5 certification | BLOCKED | release readiness、field/runtime campaign blockers retained |

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
