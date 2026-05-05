# Observe 二次吸收任务包（Wave2，2026-05-02）

## 目标

继续把 `observe` 高价值项转成可执行资产，并保证每个任务包至少覆盖 Agent/Skill/Workflow 一层。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-04 | `hermes-agent` | Workflow + Agent | 大型工程交付 runbook、跨模块 ownership 与关键触点规则 |
| OPKG-05 | `AUBB-Server` | Workflow + Agent + Skill | 证据索引交付 runbook、Evidence Index 门禁 |
| OPKG-06 | `arthas` | Workflow + Agent + Skill | 发布链路专项门禁、贡献规范检查项 |

## OPKG-04：大型工程边界治理（hermes-agent）

1. Workflow：
- `global-dev-kit/docs/runbooks/large-platform-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 J）
- `global-dev-kit/docs/agent-skill-catalog.md`（场景路由新增）

2. Agent：
- `global-dev-kit/agents/application-engineer/AGENTS.md`
  - 增加 module ownership map 与关键触点约束。

## OPKG-05：证据索引交付（AUBB-Server）

1. Workflow：
- `global-dev-kit/docs/runbooks/evidence-index-delivery.md`
- `global-dev-kit/docs/workflows.md`（场景 K）

2. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - 增加 Evidence Index 缺失即 `needs-fix` 规则。

3. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - 增加证据索引化步骤与输出模板字段。

## OPKG-06：贡献与发布门禁（arthas）

1. Workflow：
- `global-dev-kit/docs/runbooks/release-hardening.md`
  - 增加 release gate 与 contribution checklist 验收项。

2. Agent：
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加发布链路专项验证与贡献清单门禁。

3. Skill：
- `global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`
  - 增加 Evidence Index、Release Gate Decision 与发布脚本触发条件。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md` 的证据列：
  - `hermes-agent`
  - `AUBB-Server`
  - `arthas`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave2 已把 `delivery` 维度的三项高价值 `observe` 转为可执行资产，进一步减少“只参考、不实装”的积压。
