# superpowers-openspec-team-skills 治理覆盖说明

## 定位

`superpowers-openspec-team-skills` 是 Superpowers 与 OpenSpec 组合工作流参考源，用于评估显式 opt-in、记忆闭环和团队技能包设计。

## 使用边界

- 默认只读分析，不直接安装到 `~/.codex`。
- 任何采纳都必须走 `llm_agent -> agent-dev-kit -> ~/codex -> ~/.codex` 链路。
- 上游 workflow 是 explicit opt-in 语义，不能直接升级为默认全局行为。

## 修改约束

- 优先保持上游原貌；除根仓托管治理覆盖文件外，不改动上游内容。
- 可迁移内容应先记录来源、取舍和不采纳原因，再落到 `agent-dev-kit` 标准资产。
- 文档文件保持 `100644`，只有实际可执行脚本保留 executable bit。
