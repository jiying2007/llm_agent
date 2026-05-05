# Observe 二次吸收任务包（Wave4，2026-05-02）

## 目标

一次性推进更多 `observe` 高价值项，把“模板参考/资产池参考”转成可执行资产，并保证每个任务包至少覆盖 Agent/Skill/Workflow 一层。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-10 | `codex-skill-spec` | Workflow + Skill + Agent | spec 链路交付 runbook、requirements/spec 追溯门禁 |
| OPKG-11 | `Migrationed_skills` | Workflow + Skill + Agent | skill 候选筛选 runbook、安装范围与归属决策门禁 |
| OPKG-12 | `prompts` | Workflow + Skill + Agent | prompt 演进 runbook、before/after 回归证据门禁 |
| OPKG-13 | `codex-cookbook` | Workflow + Skill + Agent | lead-agent 收敛 runbook、模式切换与轻量工件模板 |
| OPKG-14 | `agency-agents-zh` | Workflow + Skill + Agent | 角色收敛语义补强、放行最小条件与收敛结论门禁 |

## OPKG-10：Spec 链路交付（codex-skill-spec）

1. Workflow：
- `global-dev-kit/docs/runbooks/spec-chain-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 O）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/requirements-triage/SKILL.md`
  - 增加 `Spec Chain Decision` 输出字段。

3. Agent：
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
  - 增加 spec 三段链路映射硬约束。

## OPKG-11：Skill 候选筛选（Migrationed_skills）

1. Workflow：
- `global-dev-kit/docs/runbooks/skill-curation-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 P）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`
  - 增加 `Skill Intake Decision` 与安装范围核验。

3. Agent：
- `global-dev-kit/agents/architecture-planner/AGENTS.md`
  - 增加 `global-ready/project-bound` 安装范围判定。

## OPKG-12：Prompt 演进交付（prompts）

1. Workflow：
- `global-dev-kit/docs/runbooks/prompt-evolution-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 Q）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - 增加 prompt 回归证据字段与失败样例要求。

3. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加 before/after 对比缺失即 `needs-fix` 规则。

## OPKG-13：Lead-Agent 收敛交付（codex-cookbook）

1. Workflow：
- `global-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 R）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 增加推进模式与轻量三工件输出模板。

3. Agent：
- `global-dev-kit/agents/architecture-planner/AGENTS.md`
  - 增加模式判断与切换条件输出。

## OPKG-14：角色收敛语义补强（agency-agents-zh）

1. Workflow：
- 复用 `global-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md`
  - 强化“先模式判断、再执行、后收敛”的统一路径。

2. Skill：
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 补充收敛条件，避免持续分析空转。

3. Agent：
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加收敛结论与可放行最小条件门禁。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md` 的证据列：
  - `codex-skill-spec`
  - `Migrationed_skills`
  - `prompts`
  - `codex-cookbook`
  - `agency-agents-zh`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave4 已把“模板链路、技能候选池、prompt 演进、lead-agent 收敛、角色语义”五类 `observe` 高价值项并行压实为可执行资产，进一步缩小“参考项”与“实装项”之间的差距。
