# llm_agent / agent-dev-kit Target Architecture - 2026-07-11

## Summary

本报告是当前 goal 的第一阶段产物：为 `llm_agent` 与 `agent-dev-kit` 建立长期资产级终态架构，并落地最小治理修复。结论是：两个仓库的主链路已经具备较强门禁，下一阶段不应继续追加平行资产，而应围绕架构索引、状态外化、dirty baseline 周期复核、ADK 中立资产闭包和 source-to-live 证据回灌做持续治理。

本轮第一阶段已落地：

- 新增 `reports/architecture/` 作为架构终态设计与任务表归档入口。
- 记录本报告，作为后续 goal 执行的单一架构上下文。
- 将 `OpenSpec`、`superpowers`、`vibeflow` 的 observe-mode dirty baseline 复核窗口从 2026-07-10 刷新到 2026-07-18。只读 triage 显示三者 fingerprint 均匹配，本轮不清理、不 reset、不同步参考仓。
- 更新 `reports/current-status.md`，避免当前状态继续引用已过期的 2026-07-10 dirty baseline。

本轮第二阶段已落地：

- 新增 `scripts/check-architecture-reports.sh`，把架构报告必填章节、P0/P1/P2 任务表、命令级 Evidence Index、负结果或 before-fix 证据、Goal Closure 字段和 `~/.codex` source-to-live 边界转为机器门禁。
- 新增 `tests/test_architecture_reports.sh`，覆盖当前报告通过、fixture 通过和缺章节失败路径。
- 将架构报告门禁接入 `check-all --quick` 自动发现链路，并同步 `scripts/README.md`、`reports/architecture/README.md`、`check-doc-sync.sh`。

本轮第三阶段已落地：

- 新增 `agent-dev-kit/templates/artifacts/target-architecture-report-template.md`，把本次目标架构报告结构抽象为平台中立 ADK 工件模板。
- 将该模板接入 `agent-dev-kit/tests/test_templates.sh` 与 `agent-dev-kit/scripts/quality-gate-check.sh`，避免新增模板成为未验证资产。
- 在 `agent-dev-kit/docs/workflows.md` 的变更工件约定中登记 `target-architecture-report.md` 的用途。
- 新增仓内 Knowledge Hub candidate，供后续 owner 复核后再提升到 Hub active/archive。

本轮 V2 设计完善已补充：

- 按目标、功能、性能、可维护性、可扩展性、安全、验证、知识沉淀和运行态交付做全维度矩阵审查。
- 复核官方 OpenAI/Codex 当前实践，将其作为 report-level evidence，不新增外部 runtime，不直接改 `~/.codex`。
- 明确下一阶段 backlog 只围绕已有架构分层补强，不推翻 L0-L5 终态架构。

本轮 V3 架构再设计已补充：

- 在 L0-L5 静态分层之上增加操作闭环，明确发现、决策、资产化、交付和知识反馈如何流转。
- 增加 SSOT 矩阵，固定 current-status、架构报告、ADK 源资产、gitlink/adk.lock、source-to-live 证据和 Hub candidate 的权威边界。
- 增加落地成熟度协议，区分 report-only、source-staged、source-committed、dry-run-verified、live-applied 和 knowledge-promoted，避免把设计、提交、运行态应用或知识提升混为同一完成态。

## Scope

| Area | In Scope | Out of Scope |
|---|---|---|
| `llm_agent` | 根仓职责、报告治理、子仓治理、吸收治理、runtime target、source-to-live 边界 | 直接清理参考子仓 dirty、同步外部上游、改 `~/.codex` |
| `agent-dev-kit` | ADK 目标契约、能力闭环、workflow closure、性能预算、平台中立边界 | 把 `llm_agent` 私有路径写入 ADK core、引入 Codex 专属 direct target |
| Runtime | 只读健康检查、external handoff、证据链定义 | live apply、rollback、外部 runtime 启用 |
| Knowledge | Hub preflight、候选归档要求 | 静默写入长期 memory 或直接改 Hub active 条目 |

## Current Architecture Map

```text
reference subrepos
  -> subrepos/registry.csv
  -> subrepos/adoption-matrix.md + subrepos/adoption-matrix.jsonl
  -> reports/* analysis / triage / adoption evidence
  -> agent-dev-kit assets
       manifest.yaml
       agents/
       skills/
       optional-skills/
       workflows/
       manifests/
       scripts/
       tests/
       docs/
  -> runtime targets
       direct tool_targets: claude-code, hermes-agent, opencode
       external_handoff_targets.codex: agent-dev-kit -> ~/codex -> ~/.codex
  -> live evidence feedback
       reports/current-status.md
       runtime target health
       governance review reports
```

当前资产规模：

| Asset | Count |
|---|---:|
| root scripts | 89 |
| root manifests | 11 |
| reports | 164 |
| ADK agents | 12 |
| ADK core skills | 56 |
| ADK optional skills | 7 |
| ADK workflows | 6 |
| ADK scripts | 49 |
| ADK tests | 52 |
| ADK manifests | 30 |

## Target Architecture

终态采用六层分工：

| Layer | Owner | Purpose | Primary Assets | Gate |
|---|---|---|---|---|
| L0 Entry Policy | `llm_agent` | 低 token 入口、硬边界、常用命令 | `AGENTS.md`, `README.md` | `check-doc-sync`, `check-agents-coverage` |
| L1 Source Registry | `llm_agent` | 参考来源、runtime target、dirty baseline | `subrepos/registry.csv`, `runtime_targets.json`, `dirty-baseline.tsv` | `check-subrepo-state`, `check-runtime-targets` |
| L2 Decision Evidence | `llm_agent` | 采纳/观察/拒绝、分析报告、复核报告 | `subrepos/adoption-matrix.*`, `reports/` | `check-adoption-matrix-status`, `check-adk-target-evidence` |
| L3 Neutral ADK Assets | `agent-dev-kit` | 平台中立 Agent/Skill/Workflow/Profile | `manifest.yaml`, `agents/`, `skills/`, `workflows/` | `devkit validate`, `goal`, `capability`, `workflow-closure` |
| L4 Runtime Handoff | target owner | 显式 target 和 source-to-live 证据 | `external_handoff_targets`, `~/codex` chain | `check-runtime-health`, target evidence index |
| L5 Knowledge Feedback | Hub owner | 长期结论、决策、验证索引 | Knowledge Hub candidates | Hub preflight + owner review |

关键原则：

- `llm_agent` 负责发现、筛选、记录和交付证据。
- `agent-dev-kit` 只承载平台中立、可导出、可验证的 ADK 资产。
- Codex 继续作为 external handoff target，不进入 ADK direct `tool_targets`。
- 参考仓 dirty 不再视作永久豁免，必须有 fingerprint、owner、expires_on 和 triage report。
- 架构级任务必须先写本目录报告，再实施跨仓资产改动。

## Responsibility Boundary

| Decision | Lands In `llm_agent` | Lands In `agent-dev-kit` |
|---|---|---|
| 新参考源是否纳入 | registry、intake ledger、approval queue | 不落地，除非已转为中立能力 |
| 候选实践是否采纳 | adoption matrix、analysis report | Agent/Skill/Workflow/manifest/script/test |
| Codex 运行链路 | runtime target registry、health adapter、reports | external handoff target metadata only |
| 目标架构与路线图 | `reports/architecture/` | 仅当结论变成通用 ADK runbook 或 gate |
| 长期记忆和归档 | Hub candidate、report summary | 不写私有记忆，不含本机路径事实 |

## Architecture Operating Model

终态设计不只靠 L0-L5 静态分层，还必须有可执行的操作闭环。后续任何跨 `llm_agent` 与 `agent-dev-kit` 的架构级任务，都按以下闭环推进。

| Loop | Entry | Decision Owner | Write Target | Gate | Exit |
|---|---|---|---|---|---|
| Source Intake | 新参考源、外部实践、官方资料 | `llm_agent` owner | registry、adoption matrix、analysis report | intake/security/freshness gates | adopt / watch / reject |
| Decision Evidence | 候选能力或治理结论 | `llm_agent` owner | `reports/`, `reports/current-status.md` | evidence bundle、doc sync、token budget | 可追溯决策，不直接写 runtime |
| ADK Productization | 已采纳且平台中立的能力 | ADK owner | `agent-dev-kit` agents/skills/workflows/templates/manifests | devkit validate、template/test/gate | source asset committed |
| Runtime Handoff | 明确目标运行态 | target owner | gitlink/adk.lock、runtime evidence、source-to-live report | runtime health、source-to-live dry-run/apply evidence | dry-run-verified 或 live-applied |
| Knowledge Feedback | 可复用长期结论 | Hub owner | Hub candidate/archive 或 memory candidate | owner review、脱敏、rollback gate | knowledge-promoted 或 kept-candidate |

操作规则：

- 新设计先落 `reports/architecture/`，只有通过架构报告门禁后才允许进入 ADK 产品化或 runtime handoff。
- ADK core 只接受平台中立结论；Codex、`~/codex`、`~/.codex` 只能出现在 external handoff 或证据边界里。
- 任何 live 状态声明必须有 source-to-live 证据；没有 `apply` 证据时，最高只能声明 source-staged/source-committed 或 dry-run-verified。
- Hub 或 memory 提升必须是单独闭环；仓内 candidate 不等于长期知识已生效。

## SSOT Matrix

| Fact Type | SSOT | Readers Should Treat As | Update Rule |
|---|---|---|---|
| 当前仓库健康状态 | `reports/current-status.md` | 最新状态索引 | 每次 root quick、subrepo closeout 或 live refresh 后同步 |
| 架构终态设计 | `reports/architecture/*.md` | 长期设计与任务表 | 先写报告再改跨仓资产；必须有 Evidence Index 和 Goal Closure |
| 参考源与 dirty baseline | `subrepos/registry.csv`, `subrepos/dirty-baseline.tsv` | source registry 状态 | fingerprint、owner、expires_on 和 triage report 同步维护 |
| 采纳/观察/拒绝决策 | `subrepos/adoption-matrix.*` | 候选实践决策记录 | 只在有证据报告后更新 |
| 平台中立 ADK 资产 | `agent-dev-kit/` | 可导出 source asset | 通过 ADK tests/gates 后提交子仓 |
| 父仓引用一致性 | `agent-dev-kit` gitlink, `adk.lock` | 当前 source handoff 指针 | 子仓提交后同步 gitlink/adk.lock 并跑 `check-adk-lock` |
| Codex live 状态 | `~/codex` source-to-live evidence | 运行态应用证据 | 只有 build/doctor/plan/dry-run/apply/check 完整证据才能声明 live-applied |
| 长期知识状态 | Hub active/archive 或 candidate | 可复用知识结论 | candidate 需 owner review 后再 promotion |

## Issue Map

| ID | Severity | Finding | Evidence | Action |
|---|---|---|---|---|
| P0-1 | blocker | reference dirty baseline 过期会让 `check-subrepo-state` 失败 | `check-subrepo-state --summary-json` -> `unexpected_dirty=3`, `stale_baseline=3`; triage fingerprint 均匹配 | 本轮刷新 baseline 到 2026-07-18，并生成新的 dirty triage report |
| P0-2 | major | 架构终态设计没有稳定归档入口，容易散落在普通报告和 goal 文本里 | `rg reports/architecture` 未发现正式目录；既有报告多为单次治理或实践吸收 | 本轮新增 `reports/architecture/` 与 README |
| P1-1 | major | `reports/current-status.md` 已落后于 2026-07-07/2026-07-11 实际状态 | 文件仍写 2026-06-26、dirty baseline 到 2026-07-10 | 本轮更新为当前架构设计和 baseline 刷新状态 |
| P1-2 | major | 报告数量较大，后续 agent 容易把历史 NEEDS-FIX 当作当前事实 | `reports/` 有 164 个文件，README 已要求 current-status 优先 | 后续补 `reports/architecture` 与 current-status 的引用约束 |
| P1-3 | major | ADK core 能力强但规模已大，继续新增平行 skill 会增加触发冲突风险 | 56 core skills, 7 optional skills, 6 workflows, 30 manifests | 后续优先合并、增强现有 skill，新增前跑 routing 和 capability health |
| P2-1 | minor | Knowledge Hub 无直接命中本次终态设计旧结论，但要求结束时有 candidate 或明确不归档 | Hub preflight selected `llm-agent` route and recommended candidate | 完成或阶段收口时生成 Hub candidate 或说明本次报告即为仓内证据 |

## V2 Review Matrix

| Dimension | Current State | Gap | Terminal Design | Priority |
|---|---|---|---|---|
| Goal alignment | `llm_agent` 已定位为参考源治理与 ADK 压实工作区，`agent-dev-kit` 已保持平台中立资产包定位 | 当前目标清晰，但后续 Phase 4/5 仍可能与 root commit、source-to-live apply 混在一个会话里 | goal 必须显式拆分为 architecture/design、root commit、source-to-live、Hub promotion 四类闭环 | P0 |
| Functional coverage | registry、adoption matrix、runtime target、architecture report、ADK template/test/gate 已覆盖主链路 | skill/workflow 重复与触发冲突仍只列为 B2，尚无本轮实证矩阵 | 复用现有 routing/capability 门禁，定期输出 skill/workflow conflict delta，不新增平行 skill | P1 |
| Performance and token cost | `check-token-budget` 通过，root 最大文件仍为 `scripts/README.md` 515 行 | 报告数量和 README 长度仍会增加默认读取成本 | current-status 保持短索引；深报告进入 `reports/architecture/`；新增门禁优先 summary-json | P1 |
| Maintainability | 架构报告、README、机器检查和模板形成闭环 | 仍依赖人工判断哪些架构结论需要进入 ADK manifest 或 Hub | 使用 `Implementation Tasks` + `Completion Audit` 作为下一轮唯一入口，owner 复核后再提升长期规则 | P0 |
| Extensibility | L0-L5 分层区分 source registry、decision evidence、neutral assets、runtime handoff、knowledge feedback | Phase 4 source-to-live 与 Phase 5 Hub promotion 尚未形成独立执行工件 | 每个扩展方向先创建独立 goal 或 runbook evidence，不在架构报告中直接执行 live 写入 | P1 |
| Security and permissions | 明确拒绝直接改 `~/.codex`、破坏性清理、外部 runtime 默认启用 | 外部官方资料复核可能诱导把 Codex product 行为写入 ADK core | 外部来源仅作为 citation/governance input；进入 ADK core 前必须平台中立化并通过 freshness gate | P0 |
| Verification | root quick gate 55/55、evidence bundle pass、subrepo state pass、ADK full regression已有证据 | `check-all --quick` 会生成非目标 OSS report-only 副产物，需要固定清理步骤 | 每次 root quick 后清理非目标 reports，再复跑关键只读门禁或 status 检查 | P1 |
| Knowledge retention | 仓内 Knowledge Hub candidate 已生成，不写 active memory | candidate 仍未 owner review，不应声称 Hub 已归档 | 保持 candidate 为审查产物；Hub active/archive promotion 单独授权执行 | P2 |
| Runtime delivery | Codex 是 external handoff target，`adk.lock` 与 gitlink 已同步 | source-to-live apply 未执行，不能声称 live runtime 已更新到本轮 ADK commit | Phase 4 只在用户批准后走 `~/codex` build/doctor/plan/dry-run/apply/check 链路 | P0 |

## External Evidence Refresh

本节记录 2026-07-11 的官方资料复核。请求入口使用 `developers.openai.com`，页面当前会重定向到 `learn.chatgpt.com`；本轮仅作为 report-level evidence，不更新 `agent-dev-kit/manifests/official_docs_freshness_gates.json`，因为这些主题已存在有效 freshness 记录，且本轮没有提升新的 ADK manifest 规则。

| Source ID | Source URL | Retrieved | Expires | Review Status | Local Decision |
|---|---|---:|---:|---|---|
| codex-best-practices-v2-review | `https://developers.openai.com/codex/learn/best-practices` | 2026-07-11 | 2026-10-09 | watch | 采纳为 report-level 证据：复杂任务先计划；`AGENTS.md` 要短、实用、面向验证；测试和 review 是完成闭环的一部分 |
| codex-customization-v2-review | `https://developers.openai.com/codex/concepts/customization#skills` | 2026-07-11 | 2026-10-09 | watch | 采纳为分层边界证据：AGENTS、memories、skills、MCP、subagents 互补；skills 通过 progressive disclosure 降低上下文成本 |
| codex-automations-v2-review | `https://developers.openai.com/codex/app/automations` | 2026-07-11 | 2026-10-09 | watch | 采纳为 Phase 4/5 边界证据：自动化需先测试 prompt，复核前几次运行，默认最窄权限；本轮不启用 automation |

## Target Architecture Delta

| Area | Delta | Non-Goal |
|---|---|---|
| L0 Entry Policy | 保持根 `AGENTS.md` 短入口；将长期架构细节留在 `reports/architecture/` 和 runbook | 不把本报告正文回写到 `AGENTS.md` |
| L1 Source Registry | dirty baseline 必须有复核窗口、fingerprint 和 triage report；下一次复核不晚于 2026-07-18 | 不清理 reference 子仓 dirty |
| L2 Decision Evidence | current-status 是当前事实入口，历史报告只作 provenance；架构报告必须有 Completion Audit | 不把历史 NEEDS-FIX 当当前状态 |
| L3 Neutral ADK Assets | 目标架构报告模板已进入 ADK；后续新增能力优先增强现有 skill/workflow | 不新增 Codex 专属 core target |
| L4 Runtime Handoff | `adk.lock`/gitlink 是 source handoff 证据；live apply 必须另行批准 | 不直接写 `~/.codex` |
| L5 Knowledge Feedback | candidate 保持仓内审查态；promotion 需要 owner review、脱敏和 Hub 路由 | 不静默写 memory 或 Hub active |

## Landing Protocol

本报告使用成熟度阶梯描述设计落地程度。任何完成声明必须明确处于哪一级，不得跨级声明。

| Level | Name | Required Evidence | Allowed Claim | Forbidden Claim |
|---:|---|---|---|---|
| L0 | report-only | 架构报告或分析报告 | 设计已提出 | 已提交、已应用、已归档 |
| L1 | source-staged | staged diff、目标文件清单、定向门禁 | source 变更已准备提交 | root 已提交或 live 已刷新 |
| L2 | source-committed | root commit、提交前后门禁、git status 边界 | source 资产已进入仓库历史 | `~/.codex` 已更新 |
| L3 | dry-run-verified | `~/codex` build/doctor/plan/apply --dry-run 证据 | live 计划已验证但未应用 | live runtime 已刷新 |
| L4 | live-applied | source-to-live apply、routing precedence、final check | live runtime 已更新 | Hub active 已提升 |
| L5 | knowledge-promoted | Hub owner review、脱敏、archive/active 写入证据 | 长期知识已生效 | 未审查 candidate 已生效 |

本轮目标落地级别为 L2：将架构治理 source 变更作为 root commit 收口。L3-L5 保留为后续独立授权目标。

## Phase Roadmap

| Phase | Goal | Done Criteria | Verification |
|---|---|---|---|
| Phase 1 | 外化目标架构并修复最明显 baseline 漂移 | 架构报告、任务表、current-status 更新、dirty baseline 通过 | `check-subrepo-state`, `check-reference-dirty-triage`, doc sync |
| Phase 2 | 建立架构报告与治理复核的固定闭环 | 架构报告有独立 README、机器检查脚本和回归测试；报告不替代 current-status | `check-architecture-reports`, `test_architecture_reports`, `check-doc-sync`, `check-token-budget` |
| Phase 3 | 将高价值架构结论转为 ADK 中立资产 | 通用目标架构报告模板进入 ADK templates，并由模板测试与质量检查覆盖 | `test_templates`, `quality-gate-check`, `devkit validate`, `workflow-closure` |
| Phase 4 | 回灌到 Codex source-to-live 链路 | 仅在用户批准后运行 `~/codex` build/doctor/plan/dry-run/apply/check | source-to-live evidence index |
| Phase 5 | 长期知识沉淀 | Hub candidate 或 archive item 记录目标架构和阶段结论 | Hub candidate review |
| Phase 6 | 周期化架构漂移复核 | dirty baseline、official docs freshness、skill/workflow conflict 和 current-status 均有周期复核记录 | targeted gates + architecture report delta |
| Phase 7 | 架构再设计落地收口 | 操作模型、SSOT 矩阵、落地协议进入报告和机器门禁；root commit 完成 | `check-architecture-reports`, `test_architecture_reports`, `commit-ready`, post-commit state checks |

## Implementation Tasks

| ID | Priority | Task | Files | Stop Condition | Verification |
|---|---|---|---|---|---|
| A1 | P0 | 刷新 observe dirty baseline | `subrepos/dirty-baseline.tsv`, `reports/reference-dirty-triage-2026-07-11.*` | fingerprint mismatch 或 change count mismatch | `check-subrepo-state --summary-json`; `check-reference-dirty-triage --summary-json` |
| A2 | P0 | 建立架构报告归档入口 | `reports/README.md`, `reports/architecture/README.md` | doc sync 失败且无法定位 | `check-doc-sync.sh .` |
| A3 | P0 | 写入本次目标架构和任务表 | `reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md` | 目标、非目标或验证命令缺失 | 人工审查 + doc sync |
| A4 | P0 | 更新当前状态索引 | `reports/current-status.md` | 验证结果和状态索引不一致 | 重跑相关 gate 后修正 |
| B1 | P1 | 为架构报告补可机器检查的必填字段 gate | `scripts/check-architecture-reports.sh`, `tests/test_architecture_reports.sh`, `scripts/check-doc-sync.sh`, `scripts/README.md`, `reports/architecture/README.md` | 当前报告格式稳定后再做 | `check-architecture-reports`, `test_architecture_reports`, `check-all --quick` |
| B2 | P1 | 复核 ADK skill/workflow 重复与触发冲突 | `agent-dev-kit/manifest.yaml`, generated docs | 发现共享 routing 影响时先停下出 issue map | skill routing conflicts + workflow closure |
| B3 | P1 | 抽象平台中立目标架构报告模板 | `agent-dev-kit/templates/artifacts/target-architecture-report-template.md`, `agent-dev-kit/tests/test_templates.sh`, `agent-dev-kit/scripts/quality-gate-check.sh`, `agent-dev-kit/docs/workflows.md` | 模板缺 artifact/status/owner 或引入平台私有路径 | `test_templates`, `quality-gate-check`, `devkit validate` |
| C1 | P2 | 生成 Knowledge Hub candidate | `reports/architecture/knowledge-candidates/llm-agent-adk-target-architecture-candidate-2026-07-11.md` | 无写入权限或 owner 未授权 | candidate 可单独阅读，且不写 active memory |

## Next Implementation Backlog

| ID | Priority | Task | Files | Stop Condition | Verification |
|---|---|---|---|---|---|
| D1 | P0 | 将 root staged 架构治理产物提交为一个原子提交 | staged root files | owner 未授权 commit 或 root quick gate 失败 | `check-all --quick`; `commit-ready` |
| D2 | P0 | source-to-live dry-run 规划 | `~/codex` chain evidence only | 用户未批准 live 链路或 build/doctor 失败 | `build`, `doctor`, `plan`, `apply --dry-run` |
| D3 | P1 | skill/workflow conflict delta 审查 | generated routing/capability reports | 发现需改 ADK core 但缺 owner 复核 | `check-skill-routing-conflicts`; `devkit capability health` |
| D4 | P1 | official docs freshness delta 审查 | `official_docs_freshness_gates.json` only if promoted | 官方来源超出 allowed domains 或缺 expires_at | `check-official-docs-governance` |
| D5 | P2 | Hub candidate owner review | `reports/architecture/knowledge-candidates/...` | 未完成脱敏或 owner review | Hub candidate validation |
| D6 | P0 | 将操作模型和落地协议纳入架构报告门禁 | `scripts/check-architecture-reports.sh`, `tests/test_architecture_reports.sh`, `reports/architecture/README.md` | 新门禁无法区分旧式报告缺章节 | `check-architecture-reports`; `test_architecture_reports` |

## Verification Gates

本轮设计与第一阶段实现使用以下 gate：

| Command | Expected |
|---|---|
| `rtk scripts/check-doc-sync.sh .` | pass |
| `rtk scripts/check-agents-coverage.sh .` | pass |
| `rtk scripts/check-token-budget.sh . --summary-json` | `status=pass` |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | `status=pass` after baseline refresh |
| `rtk scripts/check-reference-dirty-triage.sh . --summary-json` | `status=pass` after 2026-07-11 triage generation |
| `rtk bash agent-dev-kit/scripts/devkit.sh goal check --summary-json` | `status=pass` |
| `rtk bash agent-dev-kit/scripts/devkit.sh capability health --summary-json` | `status=pass` |
| `rtk bash agent-dev-kit/scripts/devkit.sh workflow-closure --profile core --summary-json` | `status=pass` |
| `rtk bash agent-dev-kit/scripts/devkit.sh perf budget --summary-json` | `status=pass` |
| `rtk git diff --cached --check` | pass before root commit |
| `rtk bash ~/codex/scripts/commit-ready.sh` | pass before root commit, or blocked by unavailable external checker with explicit risk |

## Rejected Options

| Option | Decision | Reason |
|---|---|---|
| 清理或 reset `OpenSpec`、`superpowers`、`vibeflow` | reject | 这些是 reference subrepos，dirty 已有 fingerprint baseline；本 goal 不授权破坏性清理 |
| 直接修改 `~/.codex` | reject | 违反 `agent-dev-kit -> ~/codex -> ~/.codex` source-to-live 边界 |
| 把本报告内容写入 `AGENTS.md` | reject | 根 `AGENTS.md` 是低 token 入口，不承载长报告 |
| 在 ADK core 新增 Codex 专属 target | reject | Codex 是 external handoff target，不是 direct tool target |
| 新增平行 skill 解决架构治理 | reject for Phase 1 | 现有 `adk-planning-execution-loop` 和 `adk-repo-drift-remediation` 已覆盖本任务 |
| 将本轮直接推进到 source-to-live apply | reject for Phase 7 | 用户选择本轮落地深度为 root commit 收口；live apply 需要独立授权和完整 source-to-live 证据 |

## Evidence Index

| Command | Exit Code | Result Summary | Layer |
|---|---:|---|---|
| `rtk git status --short` | 0 | root dirty 包含 `OpenSpec`, `superpowers`, `vibeflow` | baseline |
| `rtk bash -lc 'cd agent-dev-kit && git status --short'` | 0 | baseline before Phase 3: no output, ADK worktree clean; current closeout state is recorded by later `check-subrepo-state` evidence | ADK baseline |
| `rtk scripts/check-doc-sync.sh .` | 0 | docs and governance files in sync | root governance |
| `rtk scripts/check-agents-coverage.sh .` | 0 | active=7, missing_path=0 | root governance |
| `rtk scripts/check-token-budget.sh . --summary-json` | 0 | `status=pass` | token governance |
| `rtk scripts/check-adk-target-evidence.sh .` | 0 | checked=19 | root/ADK evidence |
| `rtk scripts/check-adoption-matrix-status.sh .` | 0 | adoption matrix status pass | source decision |
| `rtk bash agent-dev-kit/scripts/devkit.sh goal check --summary-json` | 0 | goals=4, failures=0 | ADK goal |
| `rtk bash agent-dev-kit/scripts/devkit.sh capability health --summary-json` | 0 | capabilities=7, failures=0 | ADK capability |
| `rtk bash agent-dev-kit/scripts/devkit.sh workflow-closure --profile core --summary-json` | 0 | profiles=core, exportable=4 | ADK workflow |
| `rtk bash agent-dev-kit/scripts/devkit.sh perf budget --summary-json` | 0 | budgets=3, warnings=0 | ADK performance |
| `rtk scripts/check-runtime-targets.sh . --summary-json` | 0 | enabled_targets=1, candidate_targets=3 | runtime registry |
| `rtk scripts/check-runtime-health.sh . --profile minimal --summary-json` | 0 | codex-home minimal health pass | runtime health |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 1 | before fix: `unexpected_dirty=3`, `stale_baseline=3` | reference state |
| `rtk scripts/generate-reference-dirty-triage.sh .` | 0 | before fix: all three fingerprints match, baseline expired | reference state |
| `rtk scripts/generate-reference-dirty-triage.sh . --out reports/reference-dirty-triage-2026-07-11.md --json-out reports/reference-dirty-triage-2026-07-11.json` | 0 | after fix: report written, status=pass | reference state |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 0 | after fix: `known_dirty=3`, `unexpected_dirty=0`, `stale_baseline=0` | reference state |
| `rtk scripts/check-reference-dirty-triage.sh . --summary-json` | 0 | report=`reports/reference-dirty-triage-2026-07-11.json`, failures=[] | reference state |
| `rtk scripts/check-architecture-reports.sh . --summary-json` | 0 | `reports=1`, `failures=[]` | architecture governance |
| `rtk tests/test_architecture_reports.sh` | 0 | pass fixture and missing-heading negative fixture behaved as expected | architecture governance |
| `rtk scripts/check-doc-sync.sh .` | 0 | docs and governance files are in sync after script/test registration | root governance |
| `rtk scripts/check-token-budget.sh . --summary-json` | 1 | before README compression: `max_root_lines=528` exceeded budget | token governance |
| `rtk scripts/check-token-budget.sh . --summary-json` | 0 | after README compression: `status=pass`, `max_root_lines=515` | token governance |
| `rtk scripts/check-all.sh --quick` | 0 | Phase 2 quick gate passed, `55/55`, includes `check-architecture-reports.sh` | root governance |
| `rtk scripts/check-adk-harden-readiness.sh .` | 0 | harden readiness passed, ADK full regression `47/47` | ADK/root governance |
| `rtk bash agent-dev-kit/tests/test_templates.sh` | 0 | template tests passed, `15/15`, includes TargetArchitectureReport template | ADK template |
| `rtk bash agent-dev-kit/scripts/quality-gate-check.sh check-artifacts --verbose` | 0 | target architecture template has artifact/status/owner fields | ADK template |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | 0 | strict validation passed after template addition | ADK validation |
| `rtk bash agent-dev-kit/scripts/devkit.sh workflow-closure --profile core --summary-json` | 0 | core workflow closure remains pass | ADK workflow |
| `rtk bash agent-dev-kit/scripts/devkit.sh token-budget --summary-json` | 0 | ADK token budget remains pass after template addition | ADK token governance |
| `rtk bash agent-dev-kit/tests/run_all.sh` | 0 | ADK full regression passed, `47/47` | ADK validation |
| `rtk scripts/check-adk-harden-readiness.sh .` | 0 | harden readiness passed after ADK template addition, ADK full regression `47/47` | ADK/root governance |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 1 | after Phase 3 ADK changes: `known_dirty=3`, `unexpected_dirty=1`, `stale_baseline=0`; unexpected dirty is current `agent-dev-kit` worktree | root closeout |
| `rtk scripts/evidence-bundle.sh . --format json --fail-on-needs-fix` | 1 | evidence bundle `status=needs-fix` because `subrepo_state` failed while `agent-dev-kit` is dirty | root closeout |
| `rtk scripts/check-all.sh --quick` | 1 | after Phase 3 ADK changes: `53/55`; failed `check-evidence-bundle.sh` and `check-subrepo-state.sh` | root closeout |
| `rtk git commit -m "feat(templates): 增加目标架构报告模板"` in `agent-dev-kit` | 0 | committed ADK template landing as `14a5739` | ADK closeout |
| `rtk scripts/check-adk-lock.sh .` | 0 | after staging parent gitlink/adk.lock: lock, gitlink and manifest match `14a5739` | root closeout |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 0 | after subrepo closeout: `known_dirty=3`, `unexpected_dirty=0`, `stale_baseline=0` | root closeout |
| `rtk scripts/check-evidence-bundle.sh .` | 0 | evidence bundle gate ready after subrepo closeout | root closeout |
| `rtk scripts/evidence-bundle.sh . --format json --fail-on-needs-fix` | 0 | status=pass, `agent_dev_kit_head=14a5739` | root closeout |
| `rtk scripts/check-all.sh --quick` | 0 | root quick gate passed, `55/55` | root closeout |
| `rtk scripts/check-architecture-reports.sh . --summary-json` | 0 | after V2 review sections: `reports=1`, `failures=[]` | V2 architecture governance |
| `rtk tests/test_architecture_reports.sh` | 0 | after V2 review sections: architecture report checks behave as expected | V2 architecture governance |
| `rtk scripts/check-doc-sync.sh .` | 0 | docs and governance files remain in sync after V2 status update | V2 root governance |
| `rtk scripts/check-token-budget.sh . --summary-json` | 0 | after V2 review sections: `status=pass`, `max_root_lines=515` | V2 token governance |
| `rtk scripts/check-adk-lock.sh .` | 0 | after V2 review sections: lock, gitlink and manifest still match `14a5739` | V2 root closeout |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 0 | after V2 review sections: `known_dirty=3`, `unexpected_dirty=0`, `stale_baseline=0` | V2 root closeout |
| `rtk scripts/check-evidence-bundle.sh .` | 0 | after V2 review sections: evidence bundle gate ready | V2 root closeout |
| `rtk scripts/check-all.sh --quick` | 0 | after V2 review sections: root quick gate passed, `55/55` | V2 root closeout |
| `rtk scripts/check-architecture-reports.sh . --summary-json` | 0 | after V3 operating model and landing protocol: `reports=1`, `failures=[]` | V3 architecture governance |
| `rtk tests/test_architecture_reports.sh` | 0 | legacy report without Architecture Operating Model, SSOT Matrix and Landing Protocol is rejected | V3 architecture governance |
| `rtk scripts/check-doc-sync.sh .` | 0 | docs and governance files remain in sync after V3 README/script documentation updates | V3 root governance |
| `rtk scripts/check-token-budget.sh . --summary-json` | 0 | after V3 redesign: `status=pass`, `max_root_lines=515` | V3 token governance |
| `rtk scripts/check-adk-lock.sh .` | 0 | after V3 redesign: lock, gitlink and manifest still match `14a5739` | V3 root closeout |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 0 | after V3 redesign: `known_dirty=3`, `unexpected_dirty=0`, `stale_baseline=0` | V3 root closeout |
| `rtk scripts/check-evidence-bundle.sh .` | 0 | after V3 redesign: evidence bundle gate ready | V3 root closeout |
| `rtk scripts/check-all.sh --quick` | 0 | after V3 redesign: root quick gate passed, `55/55` | V3 root closeout |

## Completion Audit

| Requirement | Current Evidence | State |
|---|---|---|
| 架构终态设计文档 | 本报告包含 Current Architecture Map、Target Architecture、Responsibility Boundary、Issue Map、Phase Roadmap、Implementation Tasks、Verification Gates、Rejected Options、Evidence Index、Goal Closure State | proven |
| 可执行落地任务表 | `Implementation Tasks` 按 A/B/C 与 P0/P1/P2 记录目标文件、停止条件和验证命令 | proven |
| 第一阶段落地实现 | `reports/architecture/`, `reports/current-status.md`, `subrepos/dirty-baseline.tsv`, reference dirty triage report 已落地并通过对应门禁 | proven |
| 长期维护能力增强 | Phase 2 架构报告门禁和 Phase 3 ADK 中立模板已落地；`check-architecture-reports`, `test_architecture_reports`, ADK template/artifact/validate/run_all 均有通过证据 | proven |
| V2 全维度终态设计完善 | `V2 Review Matrix`、`External Evidence Refresh`、`Target Architecture Delta` 与 `Next Implementation Backlog` 已补齐目标、功能、性能、可维护性、可扩展性、安全、验证、知识沉淀和运行态交付审查 | proven |
| V3 架构再设计落地 | `Architecture Operating Model`、`SSOT Matrix` 和 `Landing Protocol` 已进入本报告，并由 `check-architecture-reports` 与 `test_architecture_reports` 强制检查 | proven |
| 所有修改都有命令级验证证据 | 本报告 Evidence Index 与 `reports/current-status.md` 记录通过和负结果；子仓提交、父仓 gitlink/adk.lock 同步、evidence bundle 和 root quick gate 均已通过 | proven |
| `llm_agent` 与 `agent-dev-kit` 职责边界更清晰 | `Target Architecture` 与 `Responsibility Boundary` 明确治理仓、中立 ADK 资产、runtime handoff 和 Knowledge Feedback 分层 | proven |
| 后续 agent 可恢复推进 | `Goal Closure State`、`reports/current-status.md`、`reports/architecture/README.md` 和仓内 Knowledge Hub candidate 提供恢复入口 | proven |

## Goal Closure State

- goal_statement: 长期资产级架构优化设计，并分阶段落地 `llm_agent` 与 `agent-dev-kit`。
- completion_claim: Phase 1 architecture design/baseline remediation, Phase 2 architecture-report gate, Phase 3 ADK neutral target-architecture template, V2 full-dimensional design review, V3 operating-model/SSOT/landing-protocol redesign, external official-practice evidence refresh, and subrepo/gitlink/adk.lock closeout are implemented and directly verified; root aggregate quick gate is PASS. This changeset targets L2 source-committed landing only.
- required_evidence: architecture report, implementation task table, V2 review matrix, V3 operating model, SSOT matrix, landing protocol, external evidence refresh, target architecture delta, next implementation backlog, dirty baseline gate, architecture report gate/test, root doc/token gates, ADK template/artifact/strict validation, ADK full regression, subrepo commit, adk.lock/gitlink consistency, evidence bundle pass, root aggregate closeout evidence.
- claimant: Codex
- verifier: completion gate in a later turn, using current command evidence.
- open_items: no required open items for the design-and-source-commit goal; owner review for Hub candidate, future ADK neutral asset improvements, source-to-live dry-run/apply, and Hub promotion remain follow-up actions requiring explicit owner decision.
- retry_budget: 3 verification repair loops per gate.
- staleness_threshold: dirty baseline review expires on 2026-07-18.
- heartbeat: Phase 1, Phase 2, Phase 3, V2 design review, V3 architecture redesign and subrepo closeout are implemented and re-verified.
- stop_condition: pass; root aggregate quick gate restored to 55/55 after subrepo closeout.
