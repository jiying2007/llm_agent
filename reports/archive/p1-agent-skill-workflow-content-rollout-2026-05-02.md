# P1 落地记录：Agent/Skill/Workflow 内容层纠偏（2026-05-02）

## 背景

在初版压实后，`gdk` 的门禁与治理脚本已较完整，但内容层（Agent/Skill/Workflow）吸收深度不足，存在“`observe` 多、实装少”的落差。

## 本轮目标

把“参考子仓优点”从治理层映射推进到内容层实装，重点补齐三类场景：

1. 缺陷修复闭环
2. 重构风险压实
3. 跨团队交接契约

## 本轮改动

1. Workflow 层
- 新增 runbook：
  - `global-dev-kit/docs/runbooks/bugfix-delivery.md`
  - `global-dev-kit/docs/runbooks/refactor-hardening.md`
- 更新：
  - `global-dev-kit/docs/runbooks/README.md`
  - `global-dev-kit/docs/workflows.md`（新增场景 F/G）
  - `global-dev-kit/docs/agent-skill-catalog.md`（新增 Scenario Routing）

2. Skill 层
- `global-dev-kit/skills/task-breakdown/SKILL.md`
  - 增加 `handoff token`（`ready_to_handoff` + receiver）约束。
- `global-dev-kit/optional-skills/cross-team-handoff/SKILL.md`
  - 增加 `section ownership` 与签收字段要求。

3. Agent 层
- `global-dev-kit/agents/requirements-analyst/AGENTS.md`
  - 增加跨团队 handoff contract 必备输出。
- `global-dev-kit/agents/code-review-governor/AGENTS.md`
  - 增加“缺陷修复禁止无关重构”与“缺少交接契约不得放行”规则。

4. 治理证据回填
- 更新 `subrepos/adoption-matrix.md` 的以下行证据：
  - `agency-agents-zh`
  - `agent-skills`
  - `hermes-collaboration-skill`
  - `ai-coding-guide`

## 验证命令与结果

1. `rtk global-dev-kit/tests/run_all.sh` -> PASS
2. `rtk scripts/check-doc-sync.sh .` -> PASS
3. `rtk scripts/check-adoption-matrix-status.sh .` -> PASS
4. `rtk scripts/check-gdk-harden-readiness.sh . --require-pilot --skip-full-suite` -> PASS

## 结论

本轮已完成从“治理脚本压实”为主，向“Agent/Skill/Workflow 内容层实装”推进的纠偏落地。后续可继续把 `observe` 高价值项分批升级为可执行资产。
