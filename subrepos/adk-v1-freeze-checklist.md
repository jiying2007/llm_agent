# adk v1 冻结前检查清单（发布级）

## 使用方式

- 适用阶段：v1 冻结前、开门前、发布前。
- 执行原则：先跑命令再打勾；无证据不得勾选通过。
- 记录要求：每个检查项至少附 1 条命令结果或报告路径。

## A. 基础信息

- [ ] 检查日期：
- [ ] 执行人：
- [ ] 目标分支：
- [ ] 目标版本：
- [ ] 变更范围摘要：

## B. 技能生态门禁

- [ ] 技能元数据完整（`name/description/version/last_updated`）
  - 验证命令：`rtk scripts/check-skill-metadata.sh .`
  - 证据：
- [ ] 技能触发路由无冲突
  - 验证命令：`rtk scripts/check-skill-routing-conflicts.sh .`
  - 证据：
- [ ] `manifest` 与技能目录一致
  - 验证命令：`rtk bash agent-dev-kit/scripts/validate_assets.sh --strict`
  - 证据：

## C. 工作流与 Artifact 门禁

- [ ] 工作流状态机可用（`proposed -> applied -> verified -> review-passed`）
  - 验证命令：`rtk agent-dev-kit/tests/test_workflow.sh`
  - 证据：
- [ ] `review --result` 与 `artifact:ReviewReport/TestReport` 结论一致性生效
  - 验证命令：`rtk agent-dev-kit/tests/test_workflow.sh`
  - 证据：
- [ ] 变更工件强制项齐全（proposal/design/tasks/checklist/negative-results）
  - 验证命令：`rtk agent-dev-kit/tests/test_workflow.sh`
  - 证据：

## D. 治理与文档一致性门禁

- [ ] `registry.csv` 字段模型符合 v1 规范
  - 验证命令：`rtk scripts/check-doc-sync.sh .`
  - 证据：
- [ ] `adoption-matrix` 包含类别标签与验收状态
  - 验证命令：`rtk scripts/check-doc-sync.sh .`
  - 证据：
- [ ] `codex` 目标策略正确（全局 `~/.codex`）
  - 验证命令：`rtk scripts/check-global-codex-target-policy.sh .`
  - 证据：

## E. 回归与试跑门禁

- [ ] adk 全量测试通过
  - 验证命令：`rtk bash agent-dev-kit/tests/run_all.sh`
  - 证据：
- [ ] 压实总门禁通过（含技能/路由/文档）
  - 验证命令：`rtk scripts/check-adk-harden-readiness.sh .`
  - 证据：
- [ ] codex 试跑证据通过（高风险场景）
  - 验证命令：`rtk scripts/check-codex-pilot-evidence.sh .`
  - 证据：
- [ ] 全局 `~/.codex` 健康通过
  - 验证命令：`rtk scripts/check-global-codex-health.sh ~/.codex minimal`
  - 证据：

## F. 冻结决策前人工复核

- [ ] `adoption-matrix` 中 P0 项验收状态均为 `done`
  - 证据：
- [ ] `blocked` 项已登记阻塞原因与解除条件
  - 证据：
- [ ] Breaking Change 已给出迁移与回滚步骤
  - 证据：
- [ ] 回滚演练命令可执行且结果已记录
  - 证据：

## G. 冻结决策

- [ ] 冻结结论：`通过 / 不通过`
- [ ] 冻结决策人：
- [ ] 冻结时间：
- [ ] 后续动作（如：开门同步 / 补缺修复 / 延期）：

## H. 附录（证据索引）

- 命令输出日志：
- 报告文件路径：
- 相关变更单/PR：
