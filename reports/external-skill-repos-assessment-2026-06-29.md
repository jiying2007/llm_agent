# 外部 skill 仓库评估与吸收决策

- 日期：2026-06-29
- 范围：`agent-skills`、`andrej-karpathy-skills`、`awesome-agent-skills`、`claude-skills`、`mattpocock-skills`、`oh-my-codex`、`planning-with-files`
- 输入来源：本地 clone 只读盘点 + 用户补充清单
- 数据边界：用户补充的星标与 GitHub API 日期为 2026-06-05 口径，本次未联网复核，不写入当前事实字段
- 决策原则：按需吸收，不全量安装；外部 runtime、hook、MCP、自动写操作先审查；优先 method-only 回灌 ADK

## 总体结论

| 仓库 | 决策 | 长期跟进 | 原因 |
|---|---|---|---|
| `oh-my-codex` | observe | 是 | Codex goal、worktree、doctor、plugin bundle、release evidence、session state scope 与本机 Codex 资产链路相关 |
| `planning-with-files` | observe | 是 | 文件化计划、上下文恢复、attestation、PreCompact/Stop gate 直接对应长任务连续性 |
| `mattpocock-skills` | adopt-method-only | 抽样 | 加强 `grill-me + brainstorm` 开场组合，但不恢复完整仓长期跟进 |
| `agent-skills` | observe-light | 抽样 | 生命周期和质量门禁已吸收，后续只看新型 eval、routing、hook 增量 |
| `andrej-karpathy-skills` | archive-only | 否 | 四原则已被全局 AGENTS 与 ADK 规则覆盖 |
| `awesome-agent-skills` | discovery-only | 否 | 索引型清单，适合作候选发现，不适合作本地参考仓 |
| `claude-skills` | selective-only | 否 | 大型 skill 池，按域候选审查，不全量跟进或安装 |

## `grill-me + brainstorm` 增强要求

本次明确增强需求探索开场组合：

1. 先 `brainstorm`：在不写代码、不改文件的前提下发散 2 到 4 个可行方向，说明取舍。
2. 再 `grill-me`：围绕目标、非目标、用户、边界、术语、验收、验证方式进行追问。
3. 输出压缩：把长 PRD 或口头需求压缩为 3 到 7 条可验收标准。
4. 共享语言：若项目存在长期术语，输出 `CONTEXT.md`/术语表候选，但不默认写文件。
5. 退出条件：足够清晰后转入 `adk-requirements-triage` 或 `adk-task-breakdown`；仍不清晰则列阻塞问题。

这不是安装 Matt Pocock 全套 skill，而是把其“需求没搞懂先拷问”和 Superpowers 的 brainstorm 阶段迁移为 ADK 原生需求探索纪律。

## 用户补充清单的吸收判断

| 项 | 处理 |
|---|---|
| Superpowers + Karpathy + Matt + Agent Skills 作为起步组合 | 方法层认可，但本仓已有 ADK-first 路由；不叠加全套外部 runtime |
| `everything-claude-code` | 继续高风险参考，不全量安装；原因是上下文和自动加载成本高 |
| Composio | 外部写操作和凭证边界高风险；只在具体工具链需求下进入安全审查 |
| `claude-skills` | 候选池，不作为长期参考仓 |
| awesome 系列索引仓 | discovery feed，不作为默认依赖 |

## 已落地资产

- `subrepos/registry.csv`：新增 `oh-my-codex`、`planning-with-files` submodule active reference；新增 `andrej-karpathy-skills`、`awesome-agent-skills`、`claude-skills` disabled 记录。
- `subrepos/adoption-matrix.md`：新增 6 条 2026-06-29 决策行。
- `manifests/subrepo_lifecycle.json`：补齐 active-reference、watch、archive-only 生命周期记录。
- 本报告及 `oh-my-codex`、`planning-with-files` 的 analysis / absorption / security / deep-assessment 证据报告。

## 不做事项

- 不执行 `npx skills add`、`/plugin install`、`npm install -g`。
- 不启用 OMX、planning hooks、Stop gate、MCP 或外部写操作。
- 不把用户补充的星标数据当作当前已核验事实。
