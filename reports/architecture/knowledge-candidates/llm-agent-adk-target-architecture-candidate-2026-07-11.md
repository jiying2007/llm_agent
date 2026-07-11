# Knowledge Hub Candidate: llm_agent / agent-dev-kit Target Architecture

- source: `reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md`
- captured_at: 2026-07-11
- topic: llm-agent-adk-target-architecture
- candidate_kind: decision
- intended_domain: projects/llm-agent
- status: candidate
- owner_review_required: true

## Summary

`llm_agent` 与 `agent-dev-kit` 的长期资产架构应分层治理：`llm_agent` 负责参考来源、采纳决策、报告证据、runtime target registry 和 source-to-live 边界；`agent-dev-kit` 负责平台中立的 Agent、Skill、Workflow、Profile、模板、脚本、测试和治理契约。Codex 继续作为 external handoff target，经 `agent-dev-kit -> ~/codex -> ~/.codex` 链路承接，不进入 ADK direct `tool_targets`。V3 设计复核进一步确认，长期架构不能只记录 L0-L5 静态分层，还必须固定操作模型、SSOT 矩阵和落地成熟度协议，避免把设计、提交、live apply 和长期知识提升混在同一个完成态。

## Decisions

- 将目标架构报告固定到 `reports/architecture/`，并用 `scripts/check-architecture-reports.sh` 机器检查章节、操作模型、SSOT 矩阵、落地协议、P0/P1/P2 任务表、Evidence Index、负结果或 before-fix 证据、Goal Closure 字段和 source-to-live 边界。
- 将高价值报告结构抽象为 ADK 平台中立模板：`agent-dev-kit/templates/artifacts/target-architecture-report-template.md`。
- 使用落地成熟度协议区分 `report-only`、`source-staged`、`source-committed`、`dry-run-verified`、`live-applied` 和 `knowledge-promoted`；本轮目标是 L2 source-committed。
- 参考子仓 dirty baseline 不是永久豁免，必须有 fingerprint、owner、expires_on 和 triage report。
- 官方 OpenAI/Codex 资料只作为 report-level evidence 和治理输入；进入 ADK core 前必须平台中立化，并通过 freshness、owner review 和既有门禁。
- `~/.codex` live 写入仍必须经 `~/codex` source-to-live 链路和人工审批；本次不执行 live apply、rollback、push 或上游同步。

## Verification

关键验证证据来自本仓命令输出：

- `rtk scripts/check-architecture-reports.sh . --summary-json` -> pass
- `rtk tests/test_architecture_reports.sh` -> pass
- `rtk scripts/check-all.sh --quick` -> 55/55 pass
- V2 design sections in source report: `V2 Review Matrix`, `External Evidence Refresh`, `Target Architecture Delta`, `Next Implementation Backlog`
- V3 design sections in source report: `Architecture Operating Model`, `SSOT Matrix`, `Landing Protocol`
- `rtk scripts/check-adk-harden-readiness.sh .` -> ADK full regression 47/47 pass
- `rtk bash agent-dev-kit/tests/test_templates.sh` -> 15/15 pass
- `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` -> pass

## Residual Risk

- 该文件只是仓内候选，不是 Knowledge Hub active/archive 条目；提升前需要 owner review。
- 真实 source-to-live apply、rollback 和 live runtime refresh 没有在本轮执行。
- `OpenSpec`、`superpowers`、`vibeflow` 仍是 observe-mode dirty reference subrepos；本轮仅刷新 baseline 到 2026-07-18。

## Promotion Candidate

建议提升为 Knowledge Hub `projects/llm-agent` 下的 decision 或 runbook 摘要。不要提升为全局 memory；若后续影响 Agent 行为，应先通过 `adk-memory-curator` 生成单独 memory candidate。
