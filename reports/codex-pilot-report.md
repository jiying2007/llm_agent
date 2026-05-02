# codex 实战试跑报告

- 试跑日期：2026-05-02
- 目标仓库：`~/.codex`
- 对应 gdk 版本/分支：`global-dev-kit`（本地当前工作分支）
- 执行人：Codex（自动化落地）

## 门禁证据状态

- pilot_high_risk_case_done: yes
- artifact_labels_complete: yes
- review_test_consistent: yes
- command_evidence_recorded: yes

## 本轮状态

1. `~/.codex` 作为全局运行目录纳入试跑目标（不再依赖当前仓库本地 `codex/`）。
2. 阶段门禁已开启：`subrepos/phase-gate.env` 中 `allow_upstream_sync=yes`。
3. 开门后正式执行了 `sync + diff` 增量评估（见 `weekly-change-report.md`）。
4. 已在 `global-dev-kit` 落地 `artifact-gated-lite`：
   - profile：`artifact-gated-lite`
   - optional skill：`artifact-gated-lite`
   - runbook：`docs/runbooks/artifact-gated-delivery.md`
5. 关键验证已通过：
   - `rtk scripts/check-gdk-harden-readiness.sh . --open-gate`
   - `rtk scripts/sync-subrepos.sh . fetch`
   - `rtk scripts/diff-scan.sh . 7 reports/weekly-change-report.md`
6. 本轮 `adoption-matrix` 已回填（adopt/observe/reject）。
7. 待执行三类 codex 试跑：新功能、缺陷修复、重构优化。

## 试跑场景 A（已完成）

场景：`~/.codex` 高风险配置门禁校验（RTK/skills 链接一致性与配置渲染状态）

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 使用 `~/.codex/control/scripts/doctor.sh` 对 `minimal` profile 执行门禁检查
- 识别 errors/warnings 并形成可追溯结论
inputs:
- ~/.codex/control/scripts/doctor.sh
- ~/.codex/control/catalog/*.csv
handoff_to:
- subrepos/adoption-matrix 决策回填

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None（当前不阻断）
can_follow_up:
- None

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash ~/.codex/control/scripts/doctor.sh ~/.codex minimal` -> `errors=0 warnings=0`
known_issues:
- None

## 下一步

1. 在 `codex` 选择 1 个高风险变更，使用 `artifact-gated-lite` 跑完整 `propose -> apply -> verify -> review`。
2. 记录 `artifact:*` 标签完整度、review/test 一致性与耗时。
3. 回填 `subrepos/adoption-matrix.md` 的 codex 试跑结论（adopt/observe/reject）。
