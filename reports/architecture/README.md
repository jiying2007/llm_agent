# Architecture Reports

本目录保存 `llm_agent` 与 `agent-dev-kit` 的长期资产架构设计、目标闭环记录、阶段路线图和实现任务表。

## 写入边界

- 只记录可复用、可审查、可验证的架构结论。
- 不写一次性会话流水账，不替代 `reports/current-status.md`。
- 不把 `llm_agent` 的本地运行状态提升为 `agent-dev-kit` core 规则。
- 不直接记录或执行 `~/.codex` live 写入；涉及 Codex 运行资产时只引用 `~/codex -> ~/.codex` source-to-live 证据链。

## 必填内容

每份架构报告至少包含：

- 当前架构地图
- 目标架构
- 职责边界
- 架构操作模型
- SSOT 矩阵
- 问题地图和风险分级
- 落地成熟度协议
- 运行态交付契约
- 知识提升契约
- 状态对账契约
- 分阶段路线图
- 可执行任务表
- 验证门禁
- 不采纳项与理由
- Evidence Index

## 验证入口

```bash
rtk scripts/check-architecture-reports.sh .
rtk scripts/check-architecture-reports.sh . --summary-json
rtk tests/test_architecture_reports.sh
```

## 当前报告

- `llm-agent-adk-target-architecture-2026-07-11.md`
