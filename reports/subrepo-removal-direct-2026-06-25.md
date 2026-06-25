# 参考子仓直接移除记录

- 日期：2026-06-25
- 范围：`Migrationed_skills`、`auto-research`、`codex-cookbook`、`Trellis`、`dotfiles`、`AUBB-Server`、`arthas`、`agent-browser`、`agency-agents-zh`、`agent-skills`、`ai-coding-guide`、`hermes-agent`、`hermes-collaboration-skill`、`mattpocock-skills`、`prompts`、`skills`、`superpowers-zh`
- 决策：吸收可复用方法后，从本地参考子仓中移除，治理记录保留为 `removed`

## 移除依据

| 仓库 | 直接移除原因 | 已吸收内容 | 保留证据 |
|---|---|---|---|
| `Migrationed_skills` | 旧分级为 C，资产模板化严重；持续 dirty baseline 成本高于后续收益 | 历史技能池候选筛选机制 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/skill-curation-delivery.md` |
| `auto-research` | 旧分级为 C，分级报告已判禁用；仅保留研究留痕方法即可 | 负结果留痕与复盘机制 | `subrepos/adoption-matrix.md`、`reports/weekly-change-report.md` |
| `codex-cookbook` | 旧分级为 C；Codex 协作模板已经沉淀，不再需要本地仓持续跟踪 | 分层触发、三段式写法、cookbook 任务样例 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md` |
| `Trellis` | 已有 reject/done 记录；知识管理方向保留 optional-pilot 边界即可 | 知识图谱、状态上下文、可选 pilot 边界 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/optional-pilot-boundary.md` |
| `dotfiles` | 配置治理方法已吸收；本地 dirty baseline 维护成本高于收益 | 最小变更、环境基线校验 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/config-baseline-governance.md` |
| `AUBB-Server` | 业务样本方法已吸收；不再需要持续保留完整后端样本 | 业务闭环验证证据写法 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/evidence-index-delivery.md` |
| `arthas` | 成熟工程门槛已吸收；目标域不同，完整仓持续跟踪收益有限 | 贡献规范、发布质量门槛 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/release-hardening.md` |
| `agent-browser` | 已有 reject/done 记录；浏览器操作模式保留为可选边界，不再保留本地仓 | Accessibility-tree 快照压缩、ref 交互范式、CLI-first 工具设计 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/optional-pilot-boundary.md` |
| `agency-agents-zh` | 角色术语已吸收；角色过细会增加治理噪音 | 角色职责矩阵与术语体系 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md` |
| `agent-skills` | 技能生命周期方法已吸收；无需继续完整跟踪多平台资产池 | 技能触发路由与生命周期映射 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/agent-skill-catalog.md` |
| `ai-coding-guide` | 场景导览方法已吸收；知识类仓库长期跟踪收益有限 | 场景化工作流导览与风险提示 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/bugfix-delivery.md` |
| `hermes-agent` | 大仓工程结构方法已吸收；完整仓体量大且维护成本高 | 目录职责、测试入口、发布脚本治理 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/large-platform-delivery.md` |
| `hermes-collaboration-skill` | 协作模板已吸收；内容较少，不再需要本地仓持续跟踪 | 多人协作文档模板与 runbook 化结构 | `subrepos/adoption-matrix.md`、`agent-dev-kit/optional-skills/adk-cross-team-handoff/SKILL.md` |
| `mattpocock-skills` | 技能组合范式已吸收；后续以归档报告和 ADK runbook 为证据 | 小技能组合范式与 deprecated 分层治理 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/skill-curation-delivery.md` |
| `prompts` | 轻量演进机制已吸收；提示词资产个体偏好强，不宜长期跟踪 | 提示词资产轻量演进机制 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md` |
| `skills` | CLI 目录约定已吸收；生态资产质量不均，不再保留完整仓 | skills CLI 目录约定与安装入口 | `subrepos/adoption-matrix.md`、`agent-dev-kit/docs/runbooks/feature-delivery.md` |
| `superpowers-zh` | 中文表达已吸收；继续保留 `superpowers` 主仓即可覆盖流程基线 | 中文触发词与流程表达标准化 | `subrepos/adoption-matrix.md`、`agent-dev-kit/AGENTS.md` |

## 同步动作

- 从 `.gitmodules` 移除对应 submodule 入口。
- 在 `subrepos/registry.csv` 标记 `enabled=no,status=disabled`。
- 在 `manifests/subrepo_lifecycle.json` 标记 `state=removed` 并记录移除原因。
- 从 `subrepos/dirty-baseline.tsv` 移除对应观察基线。
- 在 `subrepos/adoption-matrix.md` 追加 reject/done 记录。
