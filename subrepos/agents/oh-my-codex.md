# oh-my-codex 治理覆盖说明

## 定位

`oh-my-codex` 是 Codex 工作流运行层参考源，用于观察 goal、worktree、doctor、plugin bundle、release evidence 和 state scope 设计。

## 使用边界

- 默认只读分析，不安装外部 runtime、daemon、hook、MCP server 或全局插件。
- 可借鉴内容只吸收为 ADK method-only 规则和 llm_agent report-only 治理证据。
- 不复制 OMX 脚本实现，不直接写入 `~/.codex`、用户 shell 配置或 tmux 会话。

## 修改约束

- 优先保持上游原貌；除根仓托管治理覆盖文件外，不改动上游内容。
- 采纳时必须区分 Codex runtime 经验、ADK core 资产和本地 llm_agent 控制面。
- 文档文件保持 `100644`，只有实际可执行脚本保留 executable bit。
