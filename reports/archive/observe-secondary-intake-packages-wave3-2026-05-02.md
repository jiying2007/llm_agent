# Observe 二次吸收任务包（Wave3，2026-05-02）

## 目标

继续把 `observe` 高价值项转成可执行资产，并保证每个任务包至少覆盖 Agent/Skill/Workflow 一层。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-07 | `autonomous-vehicle-dev` | Workflow + Skill + Agent | 迁移阶段交付 runbook、阶段门禁模板、里程碑回退锚点规则 |
| OPKG-08 | `dotfiles` | Workflow + Skill + Agent | 配置基线治理 runbook、配置漂移门禁、配置审查规则 |
| OPKG-09 | `vscode-codex-settings` | Workflow + Skill + Agent | codex 设置审计 runbook、运行态加载核验、审计结论门禁 |

## OPKG-07：阶段式迁移交付（autonomous-vehicle-dev）

1. Workflow：
- `global-dev-kit/docs/runbooks/migration-stage-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 L）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/release-versioning/SKILL.md`
  - 增加阶段门禁决策输出与回退锚点约束。

3. Agent：
- `global-dev-kit/agents/build-release-engineer/AGENTS.md`
- `global-dev-kit/agents/architecture-planner/AGENTS.md`
  - 增加迁移里程碑、阶段退出条件与回退锚点要求。

## OPKG-08：配置基线治理（dotfiles）

1. Workflow：
- `global-dev-kit/docs/runbooks/config-baseline-governance.md`
- `global-dev-kit/docs/workflows.md`（场景 M）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`
  - 增加 Config Drift Decision 门禁与失败判定。
- `global-dev-kit/skills/requirements-triage/SKILL.md`
  - 增加迁移/配置判定输出字段。

3. Agent：
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加配置摘要缺失、行为影响缺失即 `needs-fix` 规则。

## OPKG-09：codex 设置审计（vscode-codex-settings）

1. Workflow：
- `global-dev-kit/docs/runbooks/codex-settings-audit.md`
- `global-dev-kit/docs/workflows.md`（场景 N）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - 增加 codex 配置“声明 vs 运行态加载”核验步骤与模板字段。

3. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - 增加配置审计场景缺证据即 `needs-fix` 规则。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md` 的证据列：
  - `autonomous-vehicle-dev`
  - `dotfiles`
  - `vscode-codex-settings`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave3 已把迁移与配置治理维度的三项高价值 `observe` 转为可执行资产，`Agent/Skill/Workflow` 三层均新增可落地门禁与审计路径。
