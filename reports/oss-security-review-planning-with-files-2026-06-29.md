# OSS Security Review: planning-with-files

- 日期：2026-06-29
- 范围：本地只读审查
- 结论：允许 submodule 观察，禁止默认 hook 启用

## 主要风险面

| 风险 | 判断 | 边界 |
|---|---|---|
| hook 自动注入 | 会把文件内容反复注入上下文 | 不安装 hooks |
| Stop gate | 可能阻塞自然结束 | 仅吸收条件化设计 |
| 项目根写文件 | 会产生计划文件和进度文件 | 不默认写入 |
| prompt injection | 外部内容写入计划后可能被重复注入 | 高风险输入必须摘要和脱敏 |
| 跨平台 shell/PowerShell | 脚本运行面复杂 | 不执行脚本 |

## 允许范围

- 阅读 README、SKILL.md、docs/codex.md、docs/evals.md。
- 提取文件状态模型和安全边界。
- 记录 commit 与本地路径。

## 禁止范围

- 不运行 `npx skills add`。
- 不复制 `.codex/hooks.json`。
- 不启用 PreToolUse、PostToolUse、Stop 或 PreCompact hooks。
