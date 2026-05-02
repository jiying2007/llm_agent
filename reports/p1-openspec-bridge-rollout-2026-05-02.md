# P1 落地记录：openspec 桥接脚本化（2026-05-02）

## 目标

把 `OpenSpec` 相关借鉴从“文档声明”升级到“可执行桥接 + 回归可证”，完成 `openspec <-> gdk` 的最小双向工件迁移能力。

## 本轮改动

1. 新增桥接脚本：
- `global-dev-kit/scripts/openspec_bridge.sh`
- 支持 `import` / `export` / `status-map`

2. 接入统一命令入口：
- `global-dev-kit/scripts/devkit.sh` 新增 `bridge` 子命令

3. 新增 runbook 与文档映射：
- `global-dev-kit/docs/runbooks/openspec-bridge.md`
- `global-dev-kit/docs/runbooks/README.md`
- `global-dev-kit/docs/commands.md`
- `global-dev-kit/docs/mapping-matrix.md`
- `global-dev-kit/docs/reference-adoption.md`

4. 新增回归测试并接入全量测试：
- `global-dev-kit/tests/test_openspec_bridge.sh`
- `global-dev-kit/tests/run_all.sh`

5. 回填治理证据：
- `subrepos/adoption-matrix.md`（OpenSpec 行证据补齐脚本+runbook+测试）

## 验证命令与结果

1. 桥接专项测试：
- 命令：`rtk global-dev-kit/tests/test_openspec_bridge.sh`
- 结果：PASS

2. gdk 全量回归：
- 命令：`rtk global-dev-kit/tests/run_all.sh`
- 结果：PASS

3. 文档/治理一致性：
- 命令：`rtk scripts/check-doc-sync.sh .`
- 结果：PASS

4. adoption-matrix 状态：
- 命令：`rtk scripts/check-adoption-matrix-status.sh .`
- 结果：PASS

5. 压实门禁（含 pilot）：
- 命令：`rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
- 结果：PASS

## 风险与说明

1. 当前桥接聚焦最小工件迁移（`proposal/design/tasks/specs` + gdk 必需补齐），未扩展到复杂 delta 合并语义。
2. `import` 阶段推断策略为最小可执行规则；若团队有更细粒度阶段策略，建议通过 `--stage` 显式覆盖。
