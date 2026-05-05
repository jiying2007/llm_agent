# Observe 二次吸收任务包（Wave6，2026-05-02）

## 目标

把剩余 `observe` 项中“缺层证据”的条目一次性压实到 Agent/Skill/Workflow 三层齐全，并升级治理门禁为“三层硬校验”。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-20 | `agent-skills` + `skills` | Agent + Workflow + Skill | 技能路由触发矩阵与安装入口兼容约束补到 Agent 层 |
| OPKG-21 | `hermes-agent` | Skill + Workflow + Agent | 大仓触点清单补到 `task-breakdown`，闭环大型工程交付路径 |
| OPKG-22 | `codex` | Agent + Workflow + Skill | codex runtime 三联证据门禁（doctor/health/pilot）补到 Agent 与 runbook |
| OPKG-23 | observe 治理门禁 | Governance Script | `check-observe-intake-depth` 升级为三层齐全硬校验 |

## OPKG-20：技能生态路由补 Agent 层（agent-skills + skills）

1. Agent：
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
  - 新增“技能生态场景必须给触发矩阵 + 安装入口兼容说明”规则。

2. Matrix 回填：
- `subrepos/adoption-matrix.md` 行：
  - `agent-skills`
  - `skills`
  - 新增 Agent 证据路径。

## OPKG-21：大型工程补 Skill 层（hermes-agent）

1. Skill：
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 新增 Large-Repo Touchpoints（scripts/entry/command-registry/shared-contract）字段。

2. Matrix 回填：
- `subrepos/adoption-matrix.md` 行：
  - `hermes-agent`
  - 新增 Skill 证据路径。

## OPKG-22：codex runtime 补 Agent 层（codex）

1. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - 新增 codex runtime 三联证据缺失即 `needs-fix`。

2. Workflow：
- `global-dev-kit/docs/runbooks/codex-runtime-pilot.md`
  - 验收门禁新增“三联证据必须齐全”。

3. Matrix 回填：
- `subrepos/adoption-matrix.md` 行：
  - `codex`
  - 新增 Agent 证据路径。

## OPKG-23：observe 深度门禁升级

1. Script：
- `scripts/check-observe-intake-depth.sh`
  - 由“至少一层”升级为“必须 Agent+Skill+Workflow 三层齐全”。

2. 文档同步：
- `scripts/README.md`
  - 同步说明为“三层硬校验”。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md`：
  - `agent-skills`
  - `skills`
  - `hermes-agent`
  - `codex`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-observe-intake-depth.sh .` -> PASS（15 行 observe+done 全部三层齐全）
5. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave6 已完成“剩余 observe 缺层项”批量压实，当前 `observe+done` 行均满足 Agent/Skill/Workflow 三层证据要求，并由脚本持续守护。
