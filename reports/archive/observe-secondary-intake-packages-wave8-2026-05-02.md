# Observe 二次吸收任务包（Wave8，2026-05-02）

## 目标

继续推动 `observe` 项压实，从“有证据”升级为“证据字段结构化且可机器复核”，并把规则同步到 Agent/Skill/Workflow 三层。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-28 | `AUBB-Server` | Agent + Skill + Workflow | 命令级 Evidence Index 结构化门禁（字段强校验） |
| OPKG-29 | `arthas` + `dotfiles` + `vscode-codex-settings` + `prompts` | Agent + Skill + Workflow | 配置/Prompt 证据字段统一，负结果证据硬约束 |

## OPKG-28：命令级 Evidence Index 结构化门禁（AUBB-Server）

1. Workflow：
- `global-dev-kit/scripts/workflow.sh`
  - `propose` 模板新增命令级 Evidence Index 区块。
- `global-dev-kit/scripts/check_change_governance.sh`
  - 强制校验命令级 Evidence Index 段落与表头字段。
- `global-dev-kit/tests/test_workflow.sh`
  - 新增模板字段回归断言。
- `global-dev-kit/docs/runbooks/evidence-index-delivery.md`
  - 同步命令级字段与负结果证据要求。

2. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - 增加命令级 Evidence Index 字段规范与质量门禁。

3. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
  - 缺少命令级字段或负结果证据，结论固定 `needs-fix`。

## OPKG-29：配置/Prompt 证据字段统一（arthas + dotfiles + vscode-codex-settings + prompts）

1. Agent：
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 强制要求命令级 Evidence Index；配置/Prompt 场景缺负结果证据不得放行。

2. Skill：
- `global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`
  - 证据模板统一为命令级字段，新增负结果证据门禁。

3. Workflow：
- `global-dev-kit/docs/runbooks/config-baseline-governance.md`
  - 增加声明配置 vs 运行态加载对比与命令级 Evidence Index 要求。
- `global-dev-kit/docs/runbooks/prompt-evolution-delivery.md`
  - 增加命令级 Evidence Index 与失败样例联动门禁。

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md`：
  - `AUBB-Server`
  - `arthas`
  - `prompts`
  - `dotfiles`
  - `vscode-codex-settings`
  - `global-dev-kit`

## 回归与门禁证据

1. `rtk global-dev-kit/tests/test_workflow.sh` -> PASS
2. `rtk global-dev-kit/tests/test_change_governance.sh` -> PASS
3. `rtk global-dev-kit/tests/run_all.sh` -> PASS
4. `rtk scripts/check-doc-sync.sh .` -> PASS
5. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
6. `rtk scripts/check-observe-intake-depth.sh .` -> PASS（15 行 observe+done）
7. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave8 把 Evidence Index 升级为命令级结构化资产，并在 Agent/Skill/Workflow 三层统一口径，继续降低后续迭代回退风险。
