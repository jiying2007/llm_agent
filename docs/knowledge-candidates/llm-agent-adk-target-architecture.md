---
id: llm-agent-adk-target-architecture
title: llm_agent / agent-dev-kit 长期资产架构结论候选
status: reviewing-candidate
promotion: none
generated_by_ai: true
ai_role: summarized
source_repo: jiying2007/llm_agent
source_scope: llm_agent-and-agent-dev-kit
review_after: 2026-12-26
---

# llm_agent / agent-dev-kit 长期资产架构结论候选

本文件是供 Knowledge Hub **dry-run capture 与 owner review** 使用的脱敏候选，不是 Hub active 知识、产品发布证据、运行时资格或生命周期授权。

## 稳定职责边界

- `llm_agent` 负责 reference intake、来源与身份治理、采纳决策、跨仓证据组合、状态投影和成熟度/长期资产治理。
- `agent-dev-kit` 负责平台中立的 Agent / Skill / Workflow / Profile 合同、编译/导出、评测、target contract、受管证据验证与版本化 Release。
- 两者都不应演化为 LLM runtime；真实 runtime/provider 行为由对应 runtime 或独立执行环境提供证据。

## 证据分层原则

长期资产必须区分：

1. source/test 结构与确定性回归；
2. source-layout discover/load 探针；
3. 受管 trust/verifier 软件能力；
4. 真实 runtime/field campaign；
5. owner-reviewed lifecycle / product qualification。

前一层 PASS 不自动继承后一层 authority。synthetic fixture、数量、Token、绿色 CI 或组件 Release 都不能冒充真实效果、native certification、field evidence 或产品授权。

## 可重复发布与消费链

- ADK 组件发布使用 exact source identity、fresh-main CI、签名 promotion evidence、immutable Release。
- Root 只通过 canonical promotion 事务更新 ADK gitlink、lock、interface identity 与签名 evidence。
- PR CI 与合并后 fresh-main CI 分开核验；不能用 PR 绿色结果代替 main 结果。
- consumer 回归应调用 pinned ADK 的真实公共入口，而不是只比较版本号。

## 资产效果与上下文成本

- repeated-trial 比较以 task 为统计单位，保留失败样本、控制变量、护栏和 inconclusive 结论。
- Agent/Skill/Profile 价值判断优先使用 task success、wrong-route、abstain、人工介入、outcome、rollback/defect 与 retirement signals；资产数量、PR 数、报告数和 Token 总量不是质量指标。
- profile 上下文治理应分开记录 frontmatter metadata、entry body 与 deferred references/scripts/assets；source byte surface 不是 native runtime 初始 prompt/token 实测。
- source growth ratchet 是 review gate，不是上下文窗口或质量评分。

## Native target 原则

- source-layout probe 只证明导出布局可发现/可读取，固定 `native_runtime_evidence=false`。
- native trust registry 默认无启用 authority。
- 真实 native conformance 必须绑定版本固定 runtime、独立 discovery/load/trigger、typed receipt、签名/provenance、managed registry exact binding 和 production-loader 验证。
- 缺认证、签名、scope、digest 或任一 stage 失败时保持 blocked/static。

## 当前长期结论

- 软件控制面、组件发布链和 Root 消费链可以独立持续迭代，不应因真实 provider、owner 或时间窗证据尚未出现而停工。
- 外部证据缺失必须机器可见并 fail-closed；不能通过复制历史 evidence 或 fixture 关闭 blocker。
- Knowledge Hub 只接收脱敏候选；capture 默认 reviewing，active/archive 均需独立 owner review/授权。
- 历史报告永久保持其原始 source identity；当前状态通过机器 SSOT/生成投影表达，不回写历史结论。

## 复核来源

- `reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md`
- `manifests/comprehensive_optimization_backlog.json`
- `reports/current-status.md`
- `docs/runbooks/practice-effect-review.md`
- `docs/runbooks/native-target-conformance-readiness.md`
- `docs/runbooks/effect-readiness.md`

## Promotion boundary

本候选在 Root 内始终保持 `promotion=none`。正确下一步是 Knowledge Hub `knowledge-capture.sh --dry-run`，然后由 Hub owner/review queue 决定是否 capture、何时 review、是否 active/archive。Root 工具不得代签 owner、调用 `--apply` 或执行 promote。
