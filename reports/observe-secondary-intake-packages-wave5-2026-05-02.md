# Observe 二次吸收任务包（Wave5，2026-05-02）

## 目标

在 Wave4 的内容层落地基础上，进一步做“机器可判定压实”：把 spec/prompt/skill/收敛要求接入自动校验与回归测试，确保后续迭代不会回退到“仅文档约束”。

## 任务包总览

| 任务包 | 来源 observe 项 | 落地层 | 关键产物 |
|---|---|---|---|
| OPKG-15 | `codex-skill-spec` | Workflow + Script + Test | `check_change_governance.sh` + `workflow` 接入 + 专项回归 |
| OPKG-16 | `prompts` | Skill + Agent + Script | prompt 回归证据从文本门禁升级为自动校验链路 |
| OPKG-17 | `Migrationed_skills` | Workflow + Gate | skill intake 归属/安装范围纳入 review 门禁与变更校验 |
| OPKG-18 | `codex-cookbook` + `agency-agents-zh` | Agent + Skill + Script | 收敛模式与轻量工件要求进入自动校验 |
| OPKG-19 | `global-dev-kit` | Governance Gate | observe 吸收深度检查接入压实主门禁 |

## OPKG-15：变更工件治理自动校验（codex-skill-spec）

1. Script：
- `global-dev-kit/scripts/check_change_governance.sh`
  - 校验 proposal/tasks/checklist/negative-results 中的关键段落与门禁行。

2. Workflow：
- `global-dev-kit/scripts/workflow.sh`
  - `verify` 阶段接入 `check_change_governance.sh`。
  - `propose` 模板新增 spec/install-scope/prompt-regression/convergence 段落。

3. Test：
- `global-dev-kit/tests/test_change_governance.sh`
- `global-dev-kit/tests/run_all.sh` 接入新测试。

## OPKG-16：Prompt 回归门禁自动化（prompts）

1. Skill：
- `global-dev-kit/skills/verification-before-completion/SKILL.md`
  - `Prompt Regression Evidence` 字段已要求。

2. Agent：
- `global-dev-kit/agents/test-validation-engineer/AGENTS.md`
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 缺少 before/after 与失败样例直接 `needs-fix`。

3. Script 联动：
- `check_change_governance.sh` 强制 checklist 含 prompt 回归证据项。

## OPKG-17：Skill Intake 门禁自动化（Migrationed_skills）

1. Skill：
- `global-dev-kit/skills/commit-pr-quality-gate/SKILL.md`
  - `Skill Intake Decision` + `global-ready/project-bound` 门禁。

2. Workflow：
- `global-dev-kit/scripts/workflow.sh` proposal/checklist 模板新增安装范围与依赖边界字段。

3. Script 联动：
- `check_change_governance.sh` 强制 checklist 含 Skill Intake 归属行。

## OPKG-18：收敛模式门禁自动化（codex-cookbook + agency-agents-zh）

1. Agent：
- `global-dev-kit/agents/architecture-planner/AGENTS.md`
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加模式判断、收敛结论与放行最小条件约束。

2. Skill：
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 增加轻量三工件与收敛条件输出。

3. Script 联动：
- `check_change_governance.sh` 强制 tasks/checklist 中出现收敛结论字段。

## OPKG-19：observe 吸收深度门禁（global-dev-kit）

1. 新增治理脚本：
- `scripts/check-observe-intake-depth.sh`
  - 要求 `observe + done` 行至少具备 Agent/Skill/Workflow 一层证据，并附 `reports/` 证据。

2. 压实主门禁接入：
- `scripts/check-gdk-harden-readiness.sh`
  - 默认执行 observe 深度检查（支持 skip flag）。

3. 文档同步：
- `scripts/README.md`
- `scripts/check-doc-sync.sh`

## 治理证据回填

- 更新 `subrepos/adoption-matrix.md` 中 `global-dev-kit` 行证据。

## 回归与门禁证据

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-observe-intake-depth.sh .` -> PASS
5. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

Wave5 已把 Wave4 的“内容门禁”进一步压实为“自动门禁 + 回归测试”，后续迭代可持续、可复核、可防回退。
