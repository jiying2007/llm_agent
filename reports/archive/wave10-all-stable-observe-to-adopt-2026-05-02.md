# Wave10：全部稳定 Observe 项升级为 Adopt（2026-05-02）

## 目标

按“已稳定可机校”标准，将 `adoption-matrix` 中全部 `observe + done` 条目升级为 `adopt + done`，完成本阶段 observe 收口。

## 稳定性判定标准

1. 具备 Agent/Skill/Workflow 证据层（历史由 observe 深度门禁校验通过）。
2. 具备 wave 任务包报告证据或主推进报告证据。
3. 具备治理主链路通过记录（doc-sync/matrix-status/harden-readiness）。

## 本轮升级清单（11 项）

1. `agency-agents-zh`
2. `agent-skills`
3. `skills`
4. `hermes-collaboration-skill`
5. `codex-skill-spec`
6. `Migrationed_skills`
7. `prompts`
8. `dotfiles`
9. `vscode-codex-settings`
10. `codex`
11. `codex-cookbook`

## 门禁脚本调整

`scripts/check-observe-intake-depth.sh` 从“无 observe 行时报错”调整为：
- 无 `observe+done` 行时返回通过，并提示 `observe backlog cleared`。

理由：当全部 observe 已升级为 adopt/reject 时，`observe` 队列为空是期望态，不应阻断主门禁。

## 变更文件

- `subrepos/adoption-matrix.md`
- `scripts/check-observe-intake-depth.sh`
- `scripts/README.md`
- `reports/post-freeze-kickoff-2026-05-02.md`
- `AGENTS.md`

## 回归与门禁证据

1. `rtk scripts/check-observe-intake-depth.sh .` -> PASS（no observe+done rows found）
2. `rtk scripts/check-delivery-adopt-depth.sh .` -> PASS（4 rows）
3. `rtk scripts/check-doc-sync.sh .` -> PASS
4. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
5. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave10 已完成“全部稳定 observe 项升级为 adopt”，当前 `adoption-matrix` 中 `observe+done` 为 0，进入以 `adopt/reject/blocked` 为主的常态治理阶段。
