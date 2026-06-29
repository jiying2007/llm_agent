# OSS Security Review: oh-my-codex

- 日期：2026-06-29
- 范围：本地只读审查
- 结论：允许 submodule 观察，禁止默认运行时启用

## 主要风险面

| 风险 | 判断 | 边界 |
|---|---|---|
| 全局安装 | `npm install -g oh-my-codex` 会改变用户运行环境 | 本仓不执行安装 |
| 沙箱绕过 | README 推荐路径包含 `--madmax` 说明 | 不吸收为默认策略 |
| tmux/HUD/runtime state | 会创建和维护运行态状态 | 不启用 runtime |
| plugin/hooks/MCP | 可能影响 Codex 行为和权限边界 | 不启用 hooks/MCP/plugin |
| 外部通知/集成 | 可能涉及凭证和外部服务 | 未审查前禁止 |

## 允许范围

- 阅读 README、package scripts、release protocol。
- 提取 method-only 治理模式。
- 在报告中引用本地路径和 commit。

## 禁止范围

- 不运行 `omx`。
- 不运行 `npm install`、`npm run setup`、`omx setup`。
- 不写入 `~/.codex`、`~/.omx` 或用户 shell profile。
