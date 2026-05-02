# Observe 二次吸收任务包（Wave7，2026-05-02）

## 目标

继续批量压实 `observe` 项，把“层级齐全”升级为“层级齐全 + intake 包证据齐全”，并完成剩余薄弱项的集中补强。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-24 | `agent-skills` + `skills` | Agent + Workflow + Skill | 技能生态触发矩阵与安装入口兼容约束补强 |
| OPKG-25 | `hermes-agent` | Skill + Workflow + Agent | 大仓关键触点字段补齐 |
| OPKG-26 | `codex` | Agent + Workflow + Skill | runtime 三联证据门禁补强 |
| OPKG-27 | observe 治理门禁 | Governance Script + Matrix | 深度检查新增 intake 包报告要求，矩阵证据批量规范化 |

## OPKG-24：技能生态路由补强（agent-skills + skills）

1. Agent：
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
  - 新增“技能生态场景必须提供触发矩阵 + 回退触发 + 安装入口兼容”约束。

2. Matrix：
- `agent-skills`、`skills` 行补齐 Agent 证据与 intake 包报告证据。

## OPKG-25：大型工程关键触点补强（hermes-agent）

1. Skill：
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 新增 `Large-Repo Touchpoints` 字段（scripts/entry/command-registry/shared-contract）。

2. Matrix：
- `hermes-agent` 行补齐 Skill 证据与 intake 包报告证据。

## OPKG-26：codex runtime 三联证据补强（codex）

1. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - codex runtime 场景缺 doctor/health/pilot 任一证据即 `needs-fix`。

2. Workflow：
- `global-dev-kit/docs/runbooks/codex-runtime-pilot.md`
  - 明确三联证据缺一不可。

3. Matrix：
- `codex` 行补齐 Agent 证据与 intake 包报告证据。

## OPKG-27：observe 证据质量门禁升级

1. Script：
- `scripts/check-observe-intake-depth.sh`
  - 在三层证据基础上，新增“必须包含 intake 包报告证据”校验。

2. Matrix 批量规范化：
- 为所有 `observe + done` 行补充对应 intake 包报告路径（wave1~wave6），不再只依赖 `weekly-change-report`。

3. 文档同步：
- `scripts/README.md` 同步为“必须附 intake 任务包报告证据”。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md`：
  - `agency-agents-zh`
  - `agent-skills`
  - `skills`
  - `hermes-collaboration-skill`
  - `codex-skill-spec`
  - `Migrationed_skills`
  - `hermes-agent`
  - `AUBB-Server`
  - `arthas`
  - `autonomous-vehicle-dev`
  - `prompts`
  - `dotfiles`
  - `vscode-codex-settings`
  - `codex`
  - `codex-cookbook`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-observe-intake-depth.sh .` -> PASS（15 行 observe+done 均通过）
5. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave7 完成了 observe 批量压实的证据质量升级：当前不仅满足 Agent/Skill/Workflow 三层齐全，还满足 intake 包报告证据齐全，后续可持续防回退。
