# P0 收口报告（2026-05-02）

## 结论

- P0 来源仓共 6 个：`OpenSpec`、`artifact-gated-agents`、`codex`、`global-dev-kit`、`superpowers`、`superpowers-zh`。
- 当前验收状态：全部为 `done`（详见 `subrepos/adoption-matrix.md`）。
- `codex_doc_cn` 非 P0，维持 `blocked`，已补解除条件。

## P0 项逐条收口

1. `superpowers`（workflow-core）
- 压实能力：生命周期流程主干（`propose/apply/verify/review/archive`）
- 证据：
  - `global-dev-kit/docs/workflows.md`
  - `global-dev-kit/scripts/workflow.sh`
  - `global-dev-kit/tests/test_workflow.sh`
- 验证命令：
  - `rtk global-dev-kit/tests/test_workflow.sh`

2. `superpowers-zh`（workflow-core）
- 压实能力：中文流程表达与触发语义规范化
- 证据：
  - `global-dev-kit/AGENTS.md`
  - `global-dev-kit/docs/workflows.md`
  - `global-dev-kit/docs/agent-skill-catalog.md`
- 验证命令：
  - `rtk bash global-dev-kit/scripts/validate_assets.sh --strict`

3. `OpenSpec`（workflow-core）
- 压实能力：变更工件命名与状态流转硬约束
- 证据：
  - `global-dev-kit/docs/workflows.md`
  - `global-dev-kit/scripts/workflow.sh`
- 验证命令：
  - `rtk global-dev-kit/tests/test_workflow.sh`

4. `artifact-gated-agents`（workflow-core）
- 压实能力：轻量 artifact 门禁模板
- 证据：
  - `global-dev-kit/optional-skills/artifact-gated-lite/SKILL.md`
  - `global-dev-kit/docs/runbooks/artifact-gated-delivery.md`
- 验证命令：
  - `rtk global-dev-kit/tests/test_workflow.sh`

5. `codex`（runtime-target）
- 压实能力：`~/.codex` 真实运行闭环与试跑证据门禁
- 证据：
  - `reports/codex-pilot-report.md`
  - `subrepos/gdk-v1-freeze-checklist-execution-2026-05-02.md`
- 验证命令：
  - `rtk scripts/check-codex-pilot-evidence.sh .`
  - `rtk scripts/check-global-codex-health.sh ~/.codex minimal`

6. `global-dev-kit`（gdk-core）
- 压实能力：总门禁编排与发布级回归基线
- 证据：
  - `scripts/check-gdk-harden-readiness.sh`
  - `subrepos/gdk-v1-freeze-checklist-execution-2026-05-02.md`
- 验证命令：
  - `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot`
  - `rtk bash global-dev-kit/tests/run_all.sh`

## 本轮关键验证回放

- `rtk scripts/check-skill-metadata.sh .` -> PASS
- `rtk scripts/check-skill-routing-conflicts.sh .` -> PASS
- `rtk scripts/check-doc-sync.sh .` -> PASS
- `rtk scripts/check-global-codex-target-policy.sh .` -> PASS
- `rtk bash global-dev-kit/tests/run_all.sh` -> All tests passed
- `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot` -> PASS

## 风险与后续

- 当前不阻断风险：`codex_doc_cn` 上游不可达（非 P0）。
- 后续动作：
  1. 按周运行 `sync-subrepos + diff-scan`。
  2. 对新增候选继续走 `adopt/observe/reject` 与证据回填。
