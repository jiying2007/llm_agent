# Superpowers v6 吸收决策报告

## 来源与读取状态

| Source | Status | Notes |
|---|---|---|
| https://github.com/obra/superpowers/releases | direct web read | 核验到 latest 为 `v6.1.1`，发布时间为 2026-07-02；v6 系列包含 v6.0.0、v6.0.2、v6.0.3、v6.1.0、v6.1.1。 |
| https://raw.githubusercontent.com/obra/superpowers/main/RELEASE-NOTES.md | direct web read | 读取 v6.0.0 到 v6.1.1 release notes，作为本次吸收主证据。 |
| local `superpowers/` checkout | read-only local check | 本地 `superpowers` 子仓 `main...origin/main [behind 2]` 且大量 dirty；本次不重置、不合并、不覆盖子仓内容。 |

## 可复用主张

| Claim | Local applicability | Decision | Landing |
|---|---|---|---|
| 子代理任务评审从两个 reviewer 合并为一个 reviewer，同时输出 spec verdict 与 quality verdict，并增加 `cannot-verify-from-diff`。 | 高；ADK 已有并行治理和 review loop，可直接增强。 | adopt | `adk-parallel-agent-governance`、`adk-code-review-loop` |
| 子代理 handoff 使用文件传递 task brief / review package / report，避免大 diff 长期占用高成本上下文。 | 高；与 ADK token/context 治理一致。 | adopt | `adk-parallel-agent-governance` |
| reviewer 必须只读、带文件行证据，父 Agent 不得要求忽略发现或预设严重级别。 | 高；降低 AI review 被 controller 诱导的风险。 | adopt | `adk-parallel-agent-governance`、`adk-code-review-loop` |
| 计划中显式下沉 Global Constraints 和 per-task Interfaces，并做计划预检。 | 高；补强 ADK 任务拆解合同。 | adopt | `adk-task-breakdown` |
| worktree 和 SDD scratch 从全局目录/`.git` 转到项目本地受忽略目录。 | 高；符合本仓不写 `.git` 和保护用户改动的规则。 | adopt | `adk-worktree-governance` |
| Codex 插件禁用 hooks 必须显式 `hooks: {}`，打包需可复现并拒绝 dirty worktree。 | 高；直接补强 ADK plugin/marketplace 合同。 | adopt | `plugin_marketplace_contracts.json`、`hooks_runtime_audits.json` |
| Brainstorming visual companion 增加 session key、路径 sandbox、dotfile/symlink 拒绝和 no-store/deny-framing。 | 中；ADK 当前没有同类 sidecar server。 | archive-only | 作为未来本地 web companion 安全基线，不新增 runtime。 |
| 新 harness 支持 Kimi Code、Pi、Antigravity；Gemini CLI 移除。 | 低到中；当前 ADK tool targets 不含这些 harness。 | observe | 不调整默认 target；后续有用户需求再做 intake。 |

## 全盘比对

- 重复检查：ADK 已有 `adk-parallel-agent-governance`、`adk-code-review-loop`、`adk-task-breakdown`、`adk-worktree-governance` 和 plugin marketplace contract；不新增 Superpowers 平行 skill。
- 冲突检查：本次保持 adk-first，不恢复 Superpowers 默认 fallback；Codex hooks 变更作为 manifest audit，不启用 hook。
- 冗余检查：v6 的 harness install 文档、visual companion runtime 和上游测试框架不复制到本仓。
- 架构影响：无目录结构变更；只更新现有 skill、manifest、采纳矩阵和本报告。

## 吸收结果

- `agent-dev-kit/skills/adk-task-breakdown/SKILL.md`：新增计划预检、Global Constraints、Interfaces 和 right-sizing 规则。
- `agent-dev-kit/skills/adk-parallel-agent-governance/SKILL.md`：新增单 reviewer 双 verdict、文件化 handoff、模型/能力档位、reviewer 防诱导和最终广域审查。
- `agent-dev-kit/skills/adk-code-review-loop/SKILL.md`：新增 `cannot-verify-from-diff`，并要求 spec/quality verdict、只读审查和 whole-diff/branch 视角。
- `agent-dev-kit/skills/adk-worktree-governance/SKILL.md`：新增项目本地 worktree、scratch/ledger 不写 `.git`、gitignore coverage 和 provenance cleanup。
- `agent-dev-kit/manifests/plugin_marketplace_contracts.json`：新增 Codex plugin `hooks: {}` 禁用策略和可复现打包要求。
- `agent-dev-kit/manifests/hooks_runtime_audits.json`：新增 no-hooks manifest audit。
- `subrepos/adoption-matrix.md` 与 `.jsonl`：记录 v6 四类采纳决策。

## 剩余风险

- 本次没有同步或清理 `superpowers/` 子仓 dirty 状态；该状态应单独做子仓同步/收口。
- 没有启用 Kimi Code、Pi、Antigravity，也没有移除任何本地 Gemini 历史文件；这些属于后续 runtime target intake。
- visual companion 安全模型只归档为方法，不代表 ADK 已有同类 server 可用。
