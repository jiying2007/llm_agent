# Last Verified Product Baseline

- updated_at: 2026-07-31
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-31
- root_product_commit: 4eeab5faabcf2e56fdb041c14e0edff570d7f337
- agent_dev_kit_commit: cf082b602d68f3948ae1fcd6d00a522d116ddd0a
- agent_dev_kit_release_commit: 9f82e1d9deffadc3967f446069375f5872363d46
- adk_previous_commit: 66a8c199fa7b11fe1396676b3eeb82249ef05554
- adk_version: 3.1.0-rc.6
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: required-pending-owner-authorization
- knowledge_candidate_status: required-pending-capture
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，current 架构报告由
`manifests/report_registry.json` 动态选择；本基线对应的历史软件 M5 审计是
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.6` 封装 RC5 release source 之后进入主线的 MCP 2026 governance-only
activation、嵌入式远程 ADB/HIL 取证加固和 G11+ 架构优化模板。release source commit
`9f82e1d` 的两次 720-file exact build 字节一致；evidence HEAD `cf082b6` 只固化
rehearsal/review/verification，release source 到 evidence commit 的 mapped asset diff 为空。

相对 RC5 release source `66a8c19`，映射资产发生变化。RC5→RC6 本地 artifact rehearsal 已通过，
但本轮没有获得新的 Codex source-to-live 写入授权，因此状态固定为
`required-pending-owner-authorization`；未执行 build/plan/dry-run/apply，也不复用 RC5 的 live
apply 证据冒充 RC6 已应用。该边界不影响 RC6 source/local release baseline，但阻止 live-ready 声明。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK release full | PASS | Python 3.11/3.12 local-CI 均 `57/57`；dependency audit 无已知漏洞 |
| ADK current evidence | PASS | release source `9f82e1d`；evidence HEAD `cf082b6`；post-release mapped asset diff=0 |
| Root quick/full | PASS | RC6 full `60/60`，fail `0`；未单独重复 quick |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；由 ADK full/effect tests 重算通过 |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | release source `9f82e1d` 两次 exact-commit build SHA256 `4cd728126b7242150665315a22706811c12de4de9f136eaef17b0e3ecbe63b15`；720 source files |
| Wheel | PASS/BOUNDARY | Python 3.11/3.12 均成功构建 wheel；远端 attestation 未运行 |
| Upgrade/rollback | PASS | `3.1.0-rc.5 -> 3.1.0-rc.6 -> rollback`；previous/candidate 各安装 39 项，rollback removed/restored=39 |
| Source-to-live | PENDING AUTHORIZATION | RC6 未执行 Codex build/plan/dry-run/apply；等待独立 owner 授权 |
| Live health | NOT-RUN/BOUNDARY | 不复用 RC5 live health 作为 RC6 证据；native direct-target runtime smoke 仍未执行 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |
| Knowledge Hub archive | PASS/BOUNDARY | candidate `llm-agent-external-practice-intake-terminal-20260719` 已 capture 为 `reviewing`；exact search 与 strict body coverage pass；无 active promotion/memory write；Hub 全局 199 条既有 frontmatter 漂移未掩盖 |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `66a8c19..9f82e1d` 的 mapped ADK 资产发生变化；RC6 Codex source-to-live 必须等待独立 owner 授权。
- RC6 唯一已验证 artifact 回退是 checksum-verified RC5 artifact；本次未创建 live backup anchor，因为没有执行 live apply。
- 本次未 tag、创建 GitHub Release、上传制品或运行远端 CI/attestation；final `3.1.0` 继续由 eligibility gate 阻断。
- 已生成 repository knowledge candidate，Knowledge Hub capture/active promotion 和 memory write 均未执行。
- 既有 dirty 参考子仓与未跟踪研究目录保持原样，未清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 在真实 Claude Code/OpenCode/Hermes 安装环境执行 discovery/load/trigger/permission smoke；fixture 与 Codex source-to-live 不替代该证据。
6. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
