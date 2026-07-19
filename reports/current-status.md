# Last Verified Product Baseline

- updated_at: 2026-07-19
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-19
- root_product_commit: a1f6fa0f12b861d9139939b2acc054d0c4d7fb19
- agent_dev_kit_commit: bffcd93eefac45669d8a038000161ff0fcc05e04
- agent_dev_kit_release_commit: ecec9185e44fe7389fc82640e563643954e7ec2d
- adk_previous_commit: a1b5e2fed679d8002b21567103c6366c57236915
- adk_version: 3.1.0-rc.4
- product_maturity: M3
- software_m5_readiness: m5-ready
- software_m5_certified: false
- terminal_mature: false
- field_status: self_pilot_active
- root_gate_status: pass
- runtime_eval_status: codex-smoke-pass-claude-blocked
- m5_campaign_status: blocked-claude-unauthenticated
- live_refresh_status: required-pending-owner-authorization
- knowledge_candidate_status: captured-reviewing
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的软件产品基线，不把 `M5-ready` 伪报为 `M5 certified`。
机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计由
`manifests/report_registry.json` 指向
`reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md`。

`agent-dev-kit 3.1.0-rc.4` 将外部实践吸收硬切为一个 report-only 控制面：统一 GitHub、GitLab、
Gitee、OpenAI/Codex 官方、Anthropic/Claude 官方、微信公众号和人工证据，候选与独立 owner
decision 分离；旧 intake Skill/CLI/schema 不保留 alias、wrapper 或双写。release source commit
`ecec918` 的两次 commit-archive build 字节一致；evidence commits 只增加 rehearsal、
review、verification 和 Knowledge Hub 边界证据。`llm_agent` 同步提供 fail-closed candidate/decision/cycle schema、
reference-repository 注册/移除合同和 legacy residue gate。

相对 RC3 evidence commit `a1b5e2f`，`agents/skills/optional-skills/workflows` 映射内容已变化。
本轮没有扩大到 `~/codex`/`~/.codex` 写权限，因此 live refresh 保持
`required-pending-owner-authorization`，不能把 source 完成误报为 live applied。

总体成熟度仍是 **M3 / release-candidate**。软件控制面达到 `M5-ready`，但 Claude 未认证、
完整双 runtime campaign 未执行，也没有独立真实软件仓、第二位 human operator、30 天现场周期和
完整复审事件，因此 `software_m5_certified=false`、`terminal_mature=false`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/security/release | PASS | 三项结构化门禁均为 pass |
| ADK release full | PASS | `ecec918` RC4 source tree full `54/54`，351240ms，fail `0` |
| ADK current evidence | PASS | `bffcd93` 只增加 rehearsal/review/verification/Knowledge Hub 边界证据，无 post-release mapped asset 变化 |
| Root quick/full | PASS | quick `53/53`；full `58/58`，fail `0` |
| Direct target static | PASS/BOUNDARY | Claude Code/OpenCode/Hermes `3/3`；真实 runtime smoke 仍为 `not-run` |
| Effect eval | PASS | OOD/adversarial `24/24`；routing ablation delta `0.3333` |
| Deterministic routing | PASS | 60/60；由 ADK full/effect tests 重算通过 |
| Codex runtime smoke | PASS | `gpt-5.5` 单任务只读 smoke `1/1` |
| Claude runtime | BLOCKED | CLI `2.1.138` 已安装但未认证；没有伪造调用或费用 |
| Runtime campaign | BLOCKED | 60 tasks、2 runtimes、2 conditions、3 trials；720 raw result 合同；最坏 `$144` |
| Release artifact | PASS | 两次 exact-commit build SHA256 `34ffba31a1da63edb7d0120b76b01746d2b2bbf2573ad445b636acd30cbc706d`；587 source files |
| Wheel | NOT-RUN/BOUNDARY | RC4 未重跑固定容器 wheel/audit；远端 attestation 未运行 |
| Upgrade/rollback | PASS | `3.1.0-rc.3 -> 3.1.0-rc.4 -> rollback`；candidate/previous 各 39 项，恢复 39 项 |
| Source-to-live | PENDING OWNER | `a1b5e2f..ecec918` mapped paths 发生变化；未运行 plan/dry-run/apply |
| Live health | NOT-CLAIMED | 当前 live runtime 仍健康，但未包含 RC4 新映射资产，不能作为 RC4 apply 证据 |
| Software M5 certifier | PASS/BOUNDARY | integrity/declaration pass；readiness `m5-ready`；certified `false` |
| Knowledge Hub archive | PASS/BOUNDARY | candidate `llm-agent-external-practice-intake-terminal-20260719` 已 capture 为 `reviewing`；exact search 与 strict body coverage pass；无 active promotion/memory write；Hub 全局 199 条既有 frontmatter 漂移未掩盖 |

## Delivery Boundaries

- Direct release targets 是 Claude Code、Hermes Agent 和 OpenCode；Codex 是 external handoff target。
- `a1b5e2f..ecec918` 的 mapped ADK 资产发生变化；`llm_agent` 只完成 source/version/rehearsal，
  不写 `~/codex`/`~/.codex`，等待独立 owner authorization 后再走 source-to-live 链路。
- 旧入口退役是 RC4 破坏性合同；唯一回退是完整恢复 checksum-verified RC3 artifact/commit，
  不在 RC4 中恢复兼容层。
- 本次未 push、tag、创建 GitHub Release、上传制品或运行远端 CI/attestation；final `3.1.0` 继续由 eligibility gate 阻断。
- Knowledge Hub candidate 已 capture 为 `reviewing` 并可精确检索；未执行 active promotion，也未写 `~/.codex/memories`。Hub 全局仍有 199 条与本 change 无关的既有 frontmatter 漂移。
- 既有 dirty 参考子仓与未跟踪研究目录保持原样，未清理、暂存或提交。

## Remaining Evidence

1. 完成 Claude 认证并执行冻结的 720-result Codex/Claude campaign，全部统计、资源和预算门禁通过。
2. 登记至少一个具有独立 Git common-dir 的真实软件仓，并由第二位 human operator 参与。
3. 完成不少于 30 天的 independent pilot，形成 workload、upgrade、rollback、fault、recovery、maintenance、review 事件与 metrics。
4. 由 independent reviewer 亲自记录 `pilot_reviewed=approve`，而不是只在 pilot 中出现。
5. owner 若授权 live refresh，按 `agent-dev-kit -> ~/codex -> ~/.codex` 执行 build/doctor/plan/dry-run/apply/routing/check，并记录 rollback。
6. 非版本 blocker 清零后才提升 final `3.1.0`，重建/回滚/完整回归并运行 `software-m5.sh certify`。
