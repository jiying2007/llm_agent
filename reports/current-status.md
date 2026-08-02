# Last Verified Product Baseline

- updated_at: 2026-08-02
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-08-02
- root_product_commit: 30e965fa42226ed48f9cc1419b7db7e7b06e0c77
- agent_dev_kit_commit: 9bd0afa7d63ad0d14662cdf931333d4fe067ba6a
- agent_dev_kit_release_commit: 60c9a9ebbcc38ebdfcb07bc1fd399f533ce08e5f
- adk_previous_commit: 9f82e1d9deffadc3967f446069375f5872363d46
- adk_version: 3.1.0-rc.7
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: applied-declarative-changed
- knowledge_candidate_status: captured-reviewing
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，current 架构报告由
`manifests/report_registry.json` 动态选择；本基线对应的历史软件 M5 审计是
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.7` 固化 Token/context governance v2、task-cost、bounded receipt、按需
routing 和 release-clean/working-tree 双门禁。release source commit `60c9a9e` 的两次 754-file
exact build 字节一致；evidence HEAD `9bd0afa` 只增加 rehearsal/review/verification，release
source 到 evidence commit 的 mapped asset diff 为空。

相对 RC6 release source `9f82e1d`，映射资产发生变化。RC6→RC7 本地 artifact rehearsal 已通过；
本轮获得 Codex source-to-live 写入授权并完成 build/doctor/plan v3/dry-run/apply/post-apply check。
plan 初次包含 2 个 content changes，重复检查为 `already-applied`，Codex 126/126 tests、5 profiles
和 live diff=0 均通过，因此状态为 `applied-declarative-changed`。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK release full | PASS | Python 3.11/3.12 local-CI 均 `58/58`；dependency audit 无已知漏洞 |
| ADK current evidence | PASS | release source `60c9a9e`；evidence HEAD `9bd0afa`；post-release mapped asset diff=0 |
| Root quick/full | PASS | RC7 release-clean full `60/60`，fail `0`；未单独重复 quick |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；由 ADK full/effect tests 重算通过 |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | release source `60c9a9e` 两次 exact-commit build SHA256 `a46d26d79be3ee0bed02cde9c5fa031a5c0cd6e533793edc906b01f753ec48e0`；754 source files |
| Wheel | PASS/BOUNDARY | Python 3.11/3.12 均成功构建 wheel；远端 attestation 未运行 |
| Upgrade/rollback | PASS | `3.1.0-rc.6 -> 3.1.0-rc.7 -> rollback`；previous/candidate 各安装 39 项，rollback removed/restored=39 |
| Source-to-live | PASS | Codex plan v3 的 2 项 content changes 已 apply；repeat state=`already-applied` |
| Live health | PASS/BOUNDARY | Codex 126/126、5 profiles 与 live diff=0；native direct-target runtime smoke 仍未执行 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |
| Knowledge Hub archive | PASS/BOUNDARY | 两个 Token/context candidates 已 capture 为 `reviewing` 并提交 `f60a722`；无 active promotion/memory write；并发个人/PCR02 草稿不在本轮提交 |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `9f82e1d..60c9a9e` 的 mapped ADK 资产发生变化；Codex declarative source-to-live 已授权并应用，post-apply live diff 为 0。
- RC7 唯一已验证 artifact 回退是 checksum-verified RC6 artifact；本轮未生成新的 Codex backup anchor。
- 本次未 tag、创建 GitHub Release、上传制品或运行远端 CI/attestation；final `3.1.0` 继续由 eligibility gate 阻断。
- Token/context knowledge candidates 已 capture 为 `reviewing`；未执行 active promotion 或 memory write。
- 既有 dirty 参考子仓与未跟踪研究目录保持原样，未清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 在真实 Claude Code/OpenCode/Hermes 安装环境执行 discovery/load/trigger/permission smoke；fixture 与 Codex source-to-live 不替代该证据。
6. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
