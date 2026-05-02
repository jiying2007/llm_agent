# Wave9：Delivery 类 Observe -> Adopt 升级（2026-05-02）

## 目标

把 `adoption-matrix` 中已稳定的 `delivery` 类 `observe + done` 项分批升级为 `adopt`，并通过新增门禁脚本确保后续不会回退到“弱证据采纳”。

## 稳定性判定标准

1. 已具备 Agent/Skill/Workflow 三层落地证据。
2. 已具备 wave 任务包报告证据（至少 1 条）。
3. 已通过当前治理主链路验证（doc-sync/matrix-status/observe-depth/harden-readiness）。

## 本轮升级条目

| 来源仓库 | 升级前 | 升级后 | 采纳结论 |
|---|---|---|---|
| `hermes-agent` | `observe + done` | `adopt + done` | 大仓交付触点模板已稳定进入 gdk |
| `AUBB-Server` | `observe + done` | `adopt + done` | 命令级 Evidence Index 交付标准已稳定 |
| `arthas` | `observe + done` | `adopt + done` | 评审分级与发布门禁模板已稳定 |
| `autonomous-vehicle-dev` | `observe + done` | `adopt + done` | 阶段迁移验收模板已稳定 |

## 新增治理门禁

1. 新增脚本：`scripts/check-delivery-adopt-depth.sh`
- 校验对象：`delivery + adopt + done` 行。
- 校验要求：必须包含 Agent/Skill/Workflow 三层证据 + `reports/` 证据 + wave 任务包报告证据。

2. 接入主链路：`scripts/check-gdk-harden-readiness.sh`
- 默认执行 delivery adopt 深度检查。
- 提供显式开关：
  - `--check-delivery-adopt-depth`
  - `--skip-delivery-adopt-depth-check`

3. 文档同步：`scripts/README.md`
- 补充 delivery adopt 深度检查用法与说明。

## 变更清单

- `subrepos/adoption-matrix.md`
- `scripts/check-delivery-adopt-depth.sh`
- `scripts/check-gdk-harden-readiness.sh`
- `scripts/README.md`
- `reports/post-freeze-kickoff-2026-05-02.md`

## 回归与门禁证据

1. `rtk scripts/check-delivery-adopt-depth.sh .` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-observe-intake-depth.sh .` -> PASS
5. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave9 已完成 `delivery` 类稳定项从 `observe` 到 `adopt` 的批量升级，并把采纳深度校验纳入持续门禁，满足“先 delivery 类升级”的目标。
