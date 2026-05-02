# gdk v1 压实执行蓝图（质量优先）

## 目标

在 6 周内完成 gdk 初版压实：生态技能与工作流双主线并行落地，形成“可执行、可验证、可回滚”的基线版本；压实完成后再进入常态化上游增量吸收。

## 里程碑与门禁

### M1（第 1-2 周）：模型与门禁重构完成

- 技能治理：
  - 完成 `core/optional/deprecated/vendor-observe` 分层定义
  - 补齐技能元数据规范（name/description/version/last_updated + 触发字段）
  - 通过 `scripts/check-skill-metadata.sh`
- 工作流治理：
  - 固化唯一状态机：`proposed -> applied -> verified -> review-passed`
  - 在高风险场景默认启用 `artifact-gated-lite`
- 阶段门禁：
  - `scripts/check-gdk-harden-readiness.sh . --check-skill-metadata --check-routing-conflicts --check-doc-sync`

### M2（第 3-4 周）：实施与兼容层收口

- 技能路由：
  - 冲突触发词清理，保证高频意图单一路径
  - 通过 `scripts/check-skill-routing-conflicts.sh`
- 工作流落地：
  - `review` 阶段校验 artifact 标签与评审结论一致性
  - 通过 `global-dev-kit/scripts/workflow.sh` 端到端演练
- 文档同步：
  - `registry.csv`、`adoption-matrix`、`scripts/README.md` 字段与约束一致
  - 通过 `scripts/check-doc-sync.sh`

### M3（第 5-6 周）：发布级验证与冻结

- 全量回归：
  - `global-dev-kit/tests/run_all.sh`
  - `scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 真实试跑：
  - 在 `~/.codex` 完成 feature / bugfix / refactor 至少各 1 次闭环
  - 证据落档 `reports/codex-pilot-report.md`
- 基线冻结：
  - 更新 `subrepos/adoption-matrix.md` 全量决策
  - 发布 v1 说明与回滚策略

## 失败阻断规则

1. 关键门禁失败（metadata/routing/doc-sync/full-suite/pilot-evidence）即阻断开门。
2. 无证据不得标记 `done`，仅可标记 `pending` 或 `blocked`。
3. 工作流出现跳状态或 artifact 结论冲突，必须回到 `needs-fix`。

## 增量迭代切换条件

满足以下条件后，允许常态化追踪参考子仓更新：

1. `check-gdk-harden-readiness` 全部通过（含 `--require-pilot`）。
2. `adoption-matrix` 所有 P0 项验收状态为 `done`。
3. `reports/weekly-change-report.md` 与矩阵决策已同步。
