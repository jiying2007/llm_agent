# Last Verified Product Baseline

- updated_at: 2026-07-13
- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-07-13
- root_product_commit: e744400836c8b6ae8842263bcbe6157507ecfb18
- agent_dev_kit_commit: eec7cd14447bb75f93f810e758d2c34261a884a9
- adk_previous_commit: b29a2ce840a6f6c636fada3d162b52cc5b5a9c48
- adk_version: 3.0.0
- product_maturity: M3
- terminal_mature: false
- field_status: field_not_verified
- root_gate_status: pass
- runtime_eval_status: codex-pass-claude-not-run
- live_refresh_status: not-required-no-mapped-assets
- knowledge_candidate_status: dry-run-planned-not-applied
- working_tree_scope: product commits exclude registered dirty reference worktrees

## Summary

本文件记录最近一次已验证的产品提交基线，不等同于把当前工作树、开放世界效果或现场状态声明为全面成熟。机器状态以 `manifests/product_maturity_scorecard.json` 为准，当前审计以 `manifests/report_registry.json` 指向的 `reports/architecture/llm-agent-adk-product-maturity-audit-2026-07-13.md` 为准。

`llm_agent` 已收敛为 evidence-first reference intake 与决策工作区；`agent-dev-kit` 3.0 已收敛为平台中立的 Agent 资产 compiler/control plane，不实现 LLM agent runtime。ADK 先提交并推送，根仓产品实现提交随后固定 gitlink 与 `adk.lock`。

总体成熟度是 **M3 / release-candidate**。关键软件与发布路径达到本地可验证状态，但 Claude runtime 未认证、固定任务集不代表开放世界、并发 writer 未做压力验证，且真实设备/团队/生产现场证据缺失，因此 `terminal_mature=false`、`field_not_verified`。

## Verified Evidence

| Area | Result | Evidence |
|---|---|---|
| ADK strict/product/full | PASS | strict validate；product contract；full regression `48/48`；quick `14/14` |
| ADK release | PASS | reproducible archive SHA256 `4cd2e4b3bdb2676c3f4256751ced38c66ed713d10399470295e41ca7e834ba4a`；wheel SHA256 `f0b9b837a7eb3a42e4629daa166787a46190dac2e07f9b640855c654b31e9fb0` |
| Codex runtime A/B | PASS | baseline `27/30`、ADK `30/30`；success/route `0.90 -> 1.00`，safety `1.00 -> 1.00` |
| Claude runtime | NOT_RUN | CLI installed but unauthenticated；baseline/adk plans both retain explicit reason |
| Root product contracts | PASS | product maturity、reference integrity、architecture、doc sync、gitlink/lock and dirty baseline gates |
| Root integrated gate | PASS | `scripts/check-all.sh` -> `61/61`, failures `0`; applicable closeout gates validate this status contract |
| Active intake pipeline | PASS | only recent registry+dynamic S/A candidates analyzed；all decisions remain `review-required` |

## Delivery Boundaries

- Direct release targets are Claude Code、Hermes Agent and OpenCode. Codex is an external handoff target.
- `b29a2ce..eec7cd1` has no content delta under `agents/skills/optional-skills/workflows/templates`; a `~/codex -> ~/.codex` apply is therefore not required and was intentionally not executed.
- Knowledge Hub preflight selected `projects/llm-agent/validation`. Candidate `llm-agent-adk-v3-product-maturity-20260713` was planned with `active_promotion=false`; Hub had unrelated dirty changes, so apply and memory promotion were not executed.
- Root GitHub CI is self-contained because the ADK submodule is private. ADK full CI runs in its own repository; local root integration reconciles gitlink、lock、manifest and worktree state.
- `OpenSpec`、`superpowers`、`vibeflow` remain registered observe-mode dirty baselines. They were neither reset nor included in product commits.

## Remaining Evidence

- Authenticate Claude and repeat the same full baseline/adk suite before making a cross-runtime effectiveness claim.
- Add repeated/open-world evaluation, confidence intervals and tail-latency investigation before generalizing the fixed-suite result.
- Collect real device/team pilot、upgrade/rollback、incident trend、maintenance cost and field telemetry before changing field maturity.
- Validate concurrent writer behavior or add a target lock before supporting simultaneous export/install operations against one destination.
