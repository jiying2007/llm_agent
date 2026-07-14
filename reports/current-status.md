# Last Verified Product Baseline

- updated_at: 2026-07-14
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-14
- root_product_commit: 83e8a26a754adaa162cc424b80fe64edb3b93215
- agent_dev_kit_commit: dd67b488c13e96933d80336f05160b9eea94e4fe
- adk_previous_commit: 53681eb8b563d49dabea97f39dda706e5ae6df70
- adk_version: 3.1.0-rc.2
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: authorized-pending-apply
- knowledge_candidate_status: required-pending-capture
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计由
`manifests/report_registry.json` 指向
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.2` 已修复 direct target 原生路径/frontmatter，统一 export/install
renderer，并补齐 receipt v3、Draft 2020-12 Schema、OOD trace/outcome eval、性能曲线、
静态/依赖/Scorecard 门禁、SBOM/provenance 和 rc.1 -> rc.2 回滚演练。
`llm_agent` 已具备不可弱化 policy、匿名 pilot ledger、append-only evidence hash chain 和
fail-closed software M5 certifier。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK full | PASS | full `51/51`，fail `0` |
| Root quick/full | PASS | quick `56/56`；full `62/62`，fail `0` |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；本轮 P95 `0.330ms` |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | 三次 source build SHA256 `8571134df515289d32905961ae78d5e5c2dd308d2771691690594a85c76142ac` |
| Wheel | NOT-RUN | 本地不重复制造 wheel 证据；GitHub CI/release workflow 负责 Python 3.12 wheel 与 attestation |
| Upgrade/rollback | PASS | `3.1.0-rc.1 -> 3.1.0-rc.2 -> rollback/fallback`；52 项 rc.1 managed hashes 恢复并清理 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `53681eb..dd67b48` 在 `agents/skills/optional-skills/workflows/templates` 下无内容变化；
  用户仍已明确授权执行完整 `~/codex -> ~/.codex` 声明式链路，当前状态为等待 root 提交后的 plan/dry-run/apply 复核。
- 本次不创建 tag、GitHub Release 或远端制品；final `3.1.0` 由 eligibility gate 阻断。
- Knowledge Hub 只创建 `reviewing` validation candidate，不执行 active promotion，也不写 `~/.codex/memories`。
- `OpenSpec`、`superpowers`、`vibeflow` 保持已登记 dirty baseline，未被清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
