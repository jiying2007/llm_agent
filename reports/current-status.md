# Last Verified Product Baseline

- updated_at: 2026-07-13
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-13
- root_product_commit: d8813e53dcbc0d1963b6b51b78540aec80b71213
- agent_dev_kit_commit: 53681eb8b563d49dabea97f39dda706e5ae6df70
- adk_previous_commit: eec7cd14447bb75f93f810e758d2c34261a884a9
- adk_version: 3.1.0-rc.1
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: not-required-no-mapped-assets
- knowledge_candidate_status: not-required-repo-only
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计由
`manifests/report_registry.json` 指向
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.1` 已具备平台中立 compiler/control plane、并发 writer lock、
transactional install/rollback、可恢复双 runtime campaign、可复现发布和本地升级演练。
`llm_agent` 已具备不可弱化 policy、匿名 pilot ledger、append-only evidence hash chain 和
fail-closed software M5 certifier。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK quick/full | PASS | quick `15/15`；full `49/49`，fail `0` |
| Deterministic routing | PASS | 60/60；本轮 P95 `0.330ms` |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | source 两次 SHA256 `b6adcb98d5fc3be9138754a114122a1d1d92aa72a577b2a8200850558114324f` |
| Wheel | PASS | SHA256 `a03ce13931277db2d95cba81d279035122f899eed04fa36f643473295609fcf6`；隔离安装和 `pip check` 通过 |
| Upgrade/rollback | PASS | `3.0.0 -> 3.1.0-rc.1 -> rollback`；31 项 managed assets 全部恢复 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `eec7cd1..53681eb` 在 `agents/skills/optional-skills/workflows/templates` 下无内容变化，
  因此不执行无意义的 `~/codex -> ~/.codex` apply。
- 本次不创建 tag、GitHub Release 或远端制品；final `3.1.0` 由 eligibility gate 阻断。
- 本次不执行 Knowledge Hub active promotion，也不写 `~/.codex/memories`；长期结论保存在仓库审计与事件证据中。
- `OpenSpec`、`superpowers`、`vibeflow` 保持已登记 dirty baseline，未被清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
