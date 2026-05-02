# Observe 二次吸收任务包（2026-05-02）

## 目标

把 `observe` 中高价值项转为“可执行资产”，并确保每个任务包至少落到 Agent/Skill/Workflow 的一层，附回归证据。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-01 | `codex`（runtime-target） | Workflow + Skill | `codex-runtime-pilot` runbook、completion 前 runtime 证据门禁 |
| OPKG-02 | `agent-skills` + `skills` | Agent + Skill + Workflow | 路由判定增强、feature 流程接入 `catalog/match` |
| OPKG-03 | `hermes-collaboration-skill` | Agent + Skill + Workflow | 跨团队交接 runbook、handoff 签收门禁强化 |

## OPKG-01：codex runtime 闭环

1. Workflow：
- `global-dev-kit/docs/runbooks/codex-runtime-pilot.md`
- `global-dev-kit/docs/workflows.md`（场景 H）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - 增加 `~/.codex` 运行目标检查与命令模板。

## OPKG-02：skill 路由生命周期增强

1. Skill：
- `global-dev-kit/skills/requirements-triage/SKILL.md`
  - 增加 core/optional 路由建议输出。
  - 增加 `devkit.sh match` 命令入口。

2. Agent：
- `global-dev-kit/agents/architecture-planner/AGENTS.md`
  - 增加 core/optional 归属决策与路由理由约束。

3. Workflow：
- `global-dev-kit/docs/runbooks/feature-delivery.md`
  - 增加 `catalog/match` 预路由步骤和验收门禁。

## OPKG-03：协作交接压实

1. Workflow：
- `global-dev-kit/docs/runbooks/cross-team-handoff-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 I）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - 增加交接签收缺失即 `needs-fix` 的门禁规则。

3. Skill：
- `global-dev-kit/optional-skills/cross-team-handoff/SKILL.md`
  - 增加 section ownership 与 sign-off 字段要求（本轮继续沿用并对接 runbook）。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md` 的证据列：
  - `agent-skills`
  - `skills`
  - `hermes-collaboration-skill`
  - `codex`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

本轮 `observe` 高价值项已完成二次吸收任务包落地，改动已进入可执行资产层，不再停留在“仅参考/仅治理”状态。
