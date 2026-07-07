# Active Reference Repo 深度吸收实施报告

## 摘要

- 实施日期：2026-07-07
- 候选来源：`reports/reference-repo-deep-absorption-recommendations-2026-07-06.md`
- 范围：active 参考仓的 P0/P1/P2 method-only 实践压实
- 排除：`agent-dev-kit` 仍是应用/落地仓，不作为参考仓来源；未启用或 vendor 任何外部 runtime、hook、MCP、browser automation、GBrain、Feishu/Lark 或 Scale runtime

## 已压实项

| Source | Capability | Landing |
|---|---|---|
| OpenSpec | canonical command resolution parity | `agent-dev-kit/manifests/external_agent_pattern_contracts.json`; `agent-dev-kit/scripts/check-external-agent-patterns.sh`; `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` |
| vibeflow | project overview freshness | `agent-dev-kit/manifests/external_agent_pattern_contracts.json`; `agent-dev-kit/skills/adk-repo-drift-remediation/SKILL.md` |
| planning-with-files | plan completeness and attestation readback | `agent-dev-kit/manifests/external_agent_pattern_contracts.json`; `agent-dev-kit/optional-skills/adk-planning-execution-loop/SKILL.md`; `agent-dev-kit/templates/context/continuity-attestation.md` |
| vibeflow | browser verification evidence gate | `agent-dev-kit/manifests/external_agent_pattern_contracts.json`; `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` |
| scale-engine | third-party skill domain policy | `agent-dev-kit/manifests/external_agent_pattern_contracts.json`; `agent-dev-kit/manifests/skill_reproducibility_contracts.json`; `agent-dev-kit/scripts/check-openai-developers-governance.sh` |

## 关键决策

- 采用 `method-only`：只吸收合同字段、门禁形状和证据要求，不运行上游工具。
- 用现有资产承载：不新增平行 skill；补强 `verification-before-completion`、`repo-drift-remediation`、`planning-execution-loop` 和 manifest checker。
- 用脚本门禁固定：`check-external-agent-patterns.sh` 校验新 source、candidate、contract、quality gate；`check-openai-developers-governance.sh` 校验第三方 skill reproducibility 合同。
- 继续保持参考仓边界：`sync-subrepos.sh` 默认排除 `adk-core`，避免把 `agent-dev-kit` 当参考仓同步。

## 验证计划

本轮应至少运行：

- `rtk scripts/check-adoption-matrix-status.sh .`
- `rtk scripts/check-adoption-matrix-structured.sh .`
- `rtk scripts/check-adk-external-agent-patterns.sh .`
- `rtk scripts/check-adk-openai-developers-governance.sh`
- `rtk scripts/check-skill-metadata.sh .`
- `rtk scripts/check-doc-sync.sh .`
- `rtk agent-dev-kit/scripts/devkit.sh validate --quick`
- `rtk bash agent-dev-kit/tests/run_all.sh --quick --max-failure-lines 20`
- `rtk scripts/check-token-budget.sh . --summary-json`
- `rtk git diff --check`
- `rtk git -C agent-dev-kit diff --check`

## 剩余边界

- `OpenSpec` 与 `superpowers` 仍 dirty + behind；未做本地 reset/stash/pull。
- `OpenSpec stores/worksets` 大重构仍保持观察，不进入本轮压实。
- Browser verification 仅作为 evidence schema；真实浏览器/MCP runtime 仍需用户授权和单独安全审查。
