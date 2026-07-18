# Last Verified Product Baseline

- updated_at: 2026-07-18
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-18
- root_product_commit: 4cae24857c4c378798b85a8cd096e1d513da7b10
- agent_dev_kit_commit: a1b5e2fed679d8002b21567103c6366c57236915
- agent_dev_kit_release_commit: defe8a078b9693b6963e434f3131891ebbcf5d62
- adk_previous_commit: 0d25f3da7ac1f141a5172d62cfc7b6f4bfbd93b1
- adk_version: 3.1.0-rc.3
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: not-required-mapped-no-change
- knowledge_candidate_status: not-captured-outside-write-scope
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计由
`manifests/report_registry.json` 指向
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.3` 在 RC2 target contract 基础上完成终态合同加固：Harness readiness、
typed manifest、copy-only 安装声明、Python 3.11+ 依赖基线、严格性能包装门禁和受控本地 CI parity。
release source commit `defe8a0` 的两次独立 archive build 字节一致；evidence commit `a1b5e2f`
只增加 rehearsal/change 证据。两者与前一治理基线 `0d25f3d` 之间均无
`agents/skills/optional-skills/workflows/templates` 内容变化，因此本候选不需要 live apply。
`llm_agent` 已具备不可弱化 policy、匿名 pilot ledger、append-only evidence hash chain 和
fail-closed software M5 certifier。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK release full | PASS | `defe8a0` RC3 source/evidence tree full `54/54`，335446ms，fail `0` |
| ADK current evidence | PASS | `a1b5e2f` 只增加 rehearsal/change 证据，无 mapped asset 变化 |
| Root quick/full | PASS | quick `56/56`；full `62/62`，fail `0` |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；本轮 P95 `0.330ms` |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | 两次 exact-commit build SHA256 `46afbb507f61fce8facffbfa36c23f59fe3f5498e3f1843ceaa53f2507d8fcd8`；576 source files |
| Wheel | PASS/LOCAL | 固定 Python 3.11/3.12 容器 wheel build 通过；远端 attestation 未运行 |
| Upgrade/rollback | PASS | `3.1.0-rc.2 -> 3.1.0-rc.3 -> rollback`；candidate/previous 各 39 项，恢复 39 项 |
| Source-to-live | NOT-REQUIRED | `0d25f3d..defe8a0` 与 `defe8a0..a1b5e2f` 的 mapped paths 均无变化；未执行 plan/apply |
| Live health | INHERITED | RC2 映射内容未变；最近一次 66 tests/四 profile/live health 证据继续有效，但本轮未重新 apply |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `0d25f3d..defe8a0` 与 `defe8a0..a1b5e2f` 的 mapped ADK 资产均未变化，故本轮不写
  `~/codex`/`~/.codex`；这不是 apply pass 声明，而是机械 diff 支持的 not-required 决策。
- RC2 历史 artifact checksum 有效，但比其 release commit 重建多一个 ignored `history.log`；
  RC3 已排除 `*.log` 并增加归档负例，历史 provenance 缺口保留在 release evidence 中。
- 本次未 push、tag、创建 GitHub Release、上传制品或运行远端 CI/attestation；final `3.1.0` 继续由 eligibility gate 阻断。
- 本次未写 Knowledge Hub：仓库证据已落地，Hub 不在当前授权写入范围；历史 RC2 candidate 仍为 reviewing，
  未执行 active promotion，也未写 `~/.codex/memories`。
- `OpenSpec`、`superpowers`、`vibeflow`、`hermes/`、`hermes_data/` 保持既有 dirty/untracked baseline，未被清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
