# Wave A 来源仓分拣结果（2026-05-21）

## 范围与方法

- 范围：`hermes-agent`、`mattpocock-skills`、`Trellis`、`agent-browser`、`codex-cookbook`、`agent-skills`、`skills`、`superpowers`、`hermes-collaboration-skill`。
- 统计窗口：最近 30 天。
- 指标：治理相关文件（`AGENTS/SKILL/README/workflow/scripts`）提交数 + 当前 adoption 决策。
- 说明：`agent-dev-kit` 不在本分拣范围内（其角色为目标仓，走压实闭环）。

## 分拣清单

| 来源仓 | 30天相关提交数 | 最近提交日期 | 当前决策 | 分拣结论 | 下一步动作 |
|---|---:|---|---|---|---|
| hermes-agent | 174 | 2026-04-26 | adopt | 高优先 re-intake | 提取脚本治理与大仓模块边界改进点，形成 2 条落地候选 |
| mattpocock-skills | 31 | 2026-04-30 | adopt | 高优先 re-intake | 提取 skill 编排与文档结构演进点，形成 2 条落地候选 |
| Trellis | 25 | 2026-05-02 | reject | 维持 reject + optional 试点 | 仅做会话/任务上下文 optional 试点，不入 core |
| agent-browser | 1 | 2026-05-13 | reject | 维持 reject + optional 试点 | 仅做快照压缩/ref 交互 optional 试点，不入 core |
| codex-cookbook | 2 | 2026-04-25 | adopt | 轻量复核 | 检查是否有新模板值得纳入 runbook |
| agent-skills | 1 | 2026-04-27 | adopt | 轻量复核 | 检查触发词/路由映射是否有增量 |
| skills | 1 | 2026-04-22 | adopt | 轻量复核 | 检查 CLI 兼容约束是否需更新 |
| superpowers | 1 | 2026-04-23 | adopt | 轻量复核 | 检查流程门禁是否有新硬约束 |
| hermes-collaboration-skill | 1 | 2026-04-28 | adopt | 轻量复核 | 检查协作 handoff 模板是否需补充 |

## 输出分组

### G1：高优先 re-intake（进入 Wave B 候选池）

- `hermes-agent`
- `mattpocock-skills`

### G2：维持 reject + optional 试点（不入 core）

- `Trellis`
- `agent-browser`

### G3：轻量复核（保持 adopt，按需更新证据）

- `codex-cookbook`
- `agent-skills`
- `skills`
- `superpowers`
- `hermes-collaboration-skill`

## 对 Wave B 的输入

1. 从 G1 各提炼 1~2 条高收益落地点，总计 2~3 条。
2. G2 只产出 optional 试点边界与验收条件，不改核心路由。
3. G3 仅在发现实质增量时更新 adoption 证据，否则维持现状。
