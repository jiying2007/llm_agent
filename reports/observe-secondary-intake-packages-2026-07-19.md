# Observe Secondary Intake Packages（2026-07-19）

## Scope

- source：`mattpocock/skills` immutable snapshot `9603c1cc8118d08bc1b3bf34cf714f62178dea3b`。
- lane：仅覆盖尚在 upstream `skills/in-progress/` 的 `batch-grill-me`、`to-questionnaire`、`setup-ts-deep-modules`。
- decision：`observe`；不安装、不复制、不新增同名 ADK Skill，不启用 plugin/runtime。
- review trigger：稳定 release 晋级、出现新的可验证 contract，或本地已有资产暴露明确能力缺口。

## ASW Intake Package

| Layer | Existing asset | Responsibility |
|---|---|---|
| Agent | `agent-dev-kit/agents/architecture-planner/AGENTS.md` | 判断候选是否形成真实架构缺口，默认 Hotspot/YAGNI 收敛范围 |
| Skill | `agent-dev-kit/skills/adk-task-breakdown/SKILL.md` | 将后续复审拆成 research/decision 工作项，不授予实现权限 |
| Workflow | `agent-dev-kit/workflows/external-practice-absorption/WORKFLOW.md` | 复用 source→candidate→owner decision→verification→retire 闭环 |

## Candidate Boundaries

| Candidate | Current signal | Local overlap | Recheck condition |
|---|---|---|---|
| `batch-grill-me` | upstream in-progress | 既有 requirements questioning + task breakdown 已覆盖批量问题收敛 | 稳定发布且出现可机械验证的批处理合同 |
| `to-questionnaire` | upstream in-progress | 既有 structured requirements questioning 已覆盖问卷式收敛 | 稳定发布且证明新的输出 schema/交接边界 |
| `setup-ts-deep-modules` | upstream in-progress | 属于特定 TypeScript 项目设置，不是平台中立 core | 出现明确本地 TypeScript 交付需求与跨项目复用证据 |

## Verification and Stop Boundary

- adoption evidence：`reports/mattpocock-skills-absorption-2026-07-19.md`。
- lifecycle SSOT：`manifests/subrepo_lifecycle.json`，保持 `watch/manual/automation_eligible=false`。
- 当前停止条件：三个候选均无稳定晋级和本地缺口证据，继续 sampled watch；不触发 ADK/Codex 写入。
- 安全边界：不执行 upstream script、hook、MCP、plugin 或依赖安装；不进行外部写操作。
