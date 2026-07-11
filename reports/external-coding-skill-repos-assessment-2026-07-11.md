# 2026-07-11 外部 Coding Skill / Agent 仓库吸收评估

- 状态：report-only + metadata watch update
- 输入：用户提供的两篇推荐清单摘录
- 核验时间：2026-07-11
- 核验方式：GitHub 页面/API 元数据 + 本地 registry/adoption/lifecycle 账本
- 本次边界：不安装 skill，不启用插件市场，不克隆新 submodule，不执行第三方 runtime，不写入 `agent-dev-kit` 核心资产

## 关键结论

1. 原文星标数据不能直接作为当前事实。GitHub 当前显示多个仓库数据已变化，且 `affaan-m/everything-claude-code` 当前重定向为 `affaan-m/ECC`。
2. 本仓已长期跟踪或吸收过其中一批核心来源：`superpowers` 已是 active-core；`planning-with-files` 已是 active-reference；`mattpocock-skills`、`agent-skills`、`andrej-karpathy-skills`、`awesome-agent-skills`、`claude-skills` 已有 2026-06-29 决策记录。
3. 本次不恢复“全量安装/全量克隆”策略。适合长期跟踪的活跃仓库先进入 `watch` 或继续 active；只有经过 analysis、duplicate check、security review、onboarding plan 后，才考虑升级为 active-reference subrepo。
4. 外部工具链仓库如 `ComposioHQ/composio` 涉及凭证、hosted service 和 open-world 写操作，本次判定为 security-review-only，不纳入子仓。

## 当前候选决策

| 仓库 | 当前事实摘要 | 本地既有状态 | 本次决策 | 子仓动作 |
|---|---|---|---|---|
| `obra/superpowers` | GitHub API 显示 MIT、active、2026-07-10 push，约 251k stars | active-core | 继续月度跟踪 | 不新增 |
| `mattpocock/skills` | GitHub 页面显示 MIT、约 165k stars、v1.1.0 发布于 2026-07-08 | previously removed after absorption | sampled watch | 暂不恢复 submodule |
| `addyosmani/agent-skills` | GitHub 页面显示 MIT、约 76.8k stars、0.6.3 发布于 2026-07-03 | disabled/removed after absorption | observe-light watch | 暂不恢复 submodule |
| `affaan-m/ECC` | GitHub API 显示 MIT、active、2026-07-09 push，约 228k stars | report-only historical reference | high-risk watch | 先做安全评审，不装 |
| `ComposioHQ/composio` | GitHub 页面显示 MIT、约 29.2k stars、工具链连接能力强 | only method references | reject for subrepo | 具体集成时单独审查 |
| `alirezarezvani/claude-skills` | GitHub 页面显示 MIT、约 22.1k stars、v2.9.0 发布于 2026-05-28 | watch/selective-only | continue watch | 不全量安装 |
| `jeremylongshore/claude-code-plugins-plus-skills` | GitHub 页面显示 MIT、约 2.5k stars、2026-07-10 release | new | watch as catalog | 不装 CLI |
| `VoltAgent/awesome-agent-skills` | GitHub 页面显示 MIT、约 27.8k stars，README 声明不作安全担保 | watch/discovery-only | continue watch | discovery feed only |
| `hesreallyhim/awesome-claude-code` | GitHub 页面显示约 49.7k stars、license summary 为 View license | new | owner-requested watch | discovery feed only |
| `ComposioHQ/awesome-claude-skills` | GitHub 页面显示 Apache-2.0 文本、约 67.4k stars | new | watch as catalog | discovery feed only |
| `rohitg00/awesome-claude-code-toolkit` | GitHub 页面显示 Apache-2.0、约 2.3k stars、latest release 2026-05-11 | new | owner-requested watch | discovery feed only |
| `multica-ai/andrej-karpathy-skills` | GitHub API 显示 no license；内容与本仓 AGENTS/ADK 规则重叠 | archive-only | keep rejected/archive-only | 不跟踪 |

## 吸收到本地治理的规则

- 对“高星”不直接采纳：星标只进入 scoring 的 adoption signal，不覆盖 license、维护、供应链、唯一性和本地重复度。
- 对“大型 skill 池/marketplace”只做 discovery feed：禁止全量安装、全量 clone、自动加载上下文。
- 对“仍在快速更新”的方法论仓库使用 sampled watch：只看新增机制、hook/runtime 边界、eval/quality gate 和可验证模板，不复制全文。
- 对外部动作平台使用 security-review-only：需要凭证、hosted service、MCP、browser 或 open-world 写操作时，必须先写 transport、凭证边界、deny-path、日志脱敏和 rollback 方案。

## 推荐升级队列

| 优先级 | 仓库 | 推荐下一步 | 通过条件 |
|---|---|---|---|
| P0 | `mattpocock/skills` | 采样复核 v1.1.0 中 `implement`、`code-review`、`domain-modeling` 的新增契约 | 只吸收可验证流程，不恢复全量 submodule |
| P0 | `addyosmani/agent-skills` | 复核 0.6.3 与 ADK 生命周期/质量门禁差异 | 发现新的 eval、security 或 release gate 才升级 |
| P1 | `affaan-m/ECC` | 先写 security review，再判断是否 quarantine clone | 明确 hooks、MCP、memory、install surface 均可隔离 |
| P1 | `jeremylongshore/claude-code-plugins-plus-skills` | 作为 marketplace catalog 做抽样质量评估 | 不执行 ccpi，不安装插件 |
| P2 | awesome 系列索引仓 | 合并为 discovery feed | 不作为本地 runtime 或默认依赖 |

## 不采纳项

- 不安装用户清单中的任何 skill 或 plugin。
- 不把 `Karpathy Guidelines` 重新提升为活跃仓；四原则已被本仓全局规则和 ADK skill 覆盖。
- 不把 `ComposioHQ/composio` 作为普通子仓长期跟踪；只有出现明确 GitHub/DB/Stripe 等集成需求时才做专门安全评审。
- 不把文章中的“必装组合”写成全局规则；本仓继续保持 adk-first，Superpowers 仅在已有 active-core 框架内作为方法参考。

## 证据与产物

- 候选 ledger：`reports/oss-discovery-candidates-2026-07-11.jsonl`
- 评分摘要：`reports/oss-score-report-2026-07-11.md`
- Registry 元数据：`subrepos/registry.csv`
- Lifecycle 元数据：`manifests/subrepo_lifecycle.json`
- Adoption 决策：`subrepos/adoption-matrix.md`

## 后续门禁

若要把某个 watch 候选升级为 active-reference subrepo，需要补齐：

1. `reports/oss-analysis-<repo>-2026-07-11.md`
2. `reports/oss-duplicate-check-<repo>-2026-07-11.md`
3. `reports/oss-security-review-<repo>-2026-07-11.md`
4. `reports/oss-deep-assessment-<repo>-2026-07-11.md`
5. `reports/oss-onboarding-plan-<repo>-2026-07-11.{json,md}`
6. 本地 reviewed clone 或 mirror，且 `local-submodule` materialization 需显式审批。
