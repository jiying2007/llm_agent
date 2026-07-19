# Last Verified Product Baseline

- updated_at: 2026-07-19
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-19
- root_product_commit: e7b92eff2cf426ca86614e0a67c59232151bcda9
- agent_dev_kit_commit: 9a8f735928976cf2efac81dd167911664bf6c490
- agent_dev_kit_release_commit: 66a8c199fa7b11fe1396676b3eeb82249ef05554
- adk_previous_commit: bffcd93eefac45669d8a038000161ff0fcc05e04
- adk_version: 3.1.0-rc.5
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
机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计由
`manifests/report_registry.json` 指向
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.5` 从不可变 upstream snapshot 吸收调用意图、工作项权限、Hotspot/YAGNI
和 prototype provenance 方法，并压实为平台中立 manifest/schema/typed validator、既有 Skill/Agent
增强与 target adapter；未复制或安装 upstream Skill/plugin。task-package v1、legacy Codex metadata、
冗余 implicit=true 与 active compatibility reader 已硬切退役。release source commit `66a8c19`
的两次 611-file build 字节一致；evidence commit `9a8f735` 只固化归档后的 rehearsal/review/verification。

相对 RC4 evidence commit `bffcd93`，映射资产已变化。经用户明确授权，本轮完成
`agent-dev-kit -> ~/codex -> ~/.codex`：最终 plan 为 copy/overwrite/delete 全零，Codex 101 tests、
五 profile smoke、live 63/63 nested metadata 与 post-apply drift 全通过。该结果只证明 Codex
声明式运行资产收敛，不替代 Claude Code/OpenCode/Hermes native runtime smoke。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK release full | PASS | RC5 final full `55/55`，355296ms，fail `0` |
| ADK current evidence | PASS | release source `66a8c19`；evidence HEAD `9a8f735`，无 post-release mapped asset 变化 |
| Root quick/full | PASS | quick `53/53`；full `58/58`，fail `0` |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；由 ADK full/effect tests 重算通过 |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | release source `66a8c19` 两次 exact-commit build SHA256 `7c0ddf0c0d0e2174abcb682e0df1e6b5d10fdcb8695bdaaa2dccc37a5daf3907`；611 source files |
| Wheel | NOT-RUN/BOUNDARY | RC5 未重跑固定容器 wheel/audit；远端 attestation 未运行 |
| Upgrade/rollback | PASS | `3.1.0-rc.4 -> 3.1.0-rc.5 -> rollback`；RC4 安装 62 项、RC5 安装 39 项、fallback 恢复 62 项 |
| Source-to-live | PASS | build/doctor/plan/dry-run/apply/routing/check 完成；最终 copy/overwrite/delete=0，post-apply drift=0 |
| Live health | PASS/BOUNDARY | Codex managed runtime metadata 63/63 nested、legacy/implicit-true=0；native direct-target runtime smoke 仍未执行 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |
| Knowledge Hub archive | PASS/BOUNDARY | candidate `llm-agent-external-practice-intake-terminal-20260719` 已 capture 为 `reviewing`；exact search 与 strict body coverage pass；无 active promotion/memory write；Hub 全局 199 条既有 frontmatter 漂移未掩盖 |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `bffcd93..66a8c19` 的 mapped ADK 资产发生变化；Codex source-to-live 已按授权完成并保留 apply 前备份，最终计划无新增覆盖或删除。
- invocation/task/metadata 退役是 RC5 破坏性合同；唯一回退是完整恢复 checksum-verified RC4 artifact/commit 和 Codex apply 前备份，不在 RC5 中恢复兼容 reader、双 schema 或 legacy metadata。
- 本次未 push、tag、创建 GitHub Release、上传制品或运行远端 CI/attestation；final `3.1.0` 继续由 eligibility gate 阻断。
- Knowledge Hub candidate 已 capture 为 `reviewing` 并可精确检索；未执行 active promotion，也未写 `~/.codex/memories`。Hub 全局仍有 199 条与本 change 无关的既有 frontmatter 漂移。
- 既有 dirty 参考子仓与未跟踪研究目录保持原样，未清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 在真实 Claude Code/OpenCode/Hermes 安装环境执行 discovery/load/trigger/permission smoke；fixture 与 Codex source-to-live 不替代该证据。
6. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
