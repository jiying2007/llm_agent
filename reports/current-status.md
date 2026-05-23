# Current Status

- updated_at: 2026-05-23
- root_commit: 609ded1
- agent_dev_kit_base_commit: 5362f3e
- adk_version: 2.9.0
- working_tree_state: active optimization changes pending commit

## Summary

最近已提交基线的 root 与 `agent-dev-kit` 主链路健康。当前工作区包含本轮治理优化的未提交改动；root 聚合门禁中的 subrepo/evidence 检查会在 `agent-dev-kit` 提交、root gitlink 与 `adk.lock` 同步前保持阻断，这是预期开发态，不可作为 release 结论。

历史报告中保留的 `NEEDS-FIX` 多数是当时 `agent-dev-kit` 尚未提交导致的严格子仓状态失败，不代表当前已提交基线状态。

## Latest Gates

| Gate | Result | Evidence |
|---|---|---|
| root doc sync | PASS | `rtk scripts/check-doc-sync.sh .` |
| root token budget | PASS | `rtk scripts/check-token-budget.sh .` |
| root aggregate gate | DEFERRED | blocked while `agent-dev-kit` has uncommitted working changes |
| adk strict validation | PASS | covered by `test_validate` in full adk regression |
| adk full tests | PASS | `rtk bash -lc "cd agent-dev-kit && bash scripts/devkit.sh test --max-failure-lines 100"` -> 37/37 |
| pilot readiness | PASS | `pilots=10 ready=10 planned=0 device_needs_fix=0 device_simulated_pass=1` |
| fallback sunset | PASS | `replacement_score=70/70` |

## Open Boundaries

- `embedded-production-field-readiness` 目前是 `simulated-pass`，不等于真实设备 production-ready。
- 真实生产放行前仍需实机烧录/readback、boot log、HIL/产测、OTA rollback 和现场维护包证据。
- 20 个参考子仓 dirty 为 `subrepos/dirty-baseline.tsv` 登记的 observe baseline，复核日期为 2026-06-15。
