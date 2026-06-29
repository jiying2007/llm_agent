# OSS Absorption Plan: planning-with-files

- 日期：2026-06-29
- 决策：method-only observe
- 不复制代码，不安装 hooks。

## 可吸收方向

| 方向 | 目标资产 | 做法 |
|---|---|---|
| 三文件状态模型 | `adk-planning-execution-loop` / context handoff | 将 task/findings/progress 映射到 ADK artifact 模板 |
| active plan | long task state contract | 借鉴 `.active_plan` 指针思想，但保持 ADK manifest 化 |
| attestation | verification gate | 对高风险计划引入 hash/版本校验候选 |
| PreCompact 提醒 | context compress handoff | 压缩前要求 flush evidence |
| Stop gate | completion gate | 只在强目标且有未完成验收时提醒，不默认阻塞 |

## 拒绝项

- 不安装 `.codex/hooks.json` 或全局 hooks。
- 不默认生成 `task_plan.md`、`findings.md`、`progress.md`。
- 不把所有 5+ tool call 任务都升级成文件计划。

## 下一步

若后续要实装，应优先改 ADK artifact 模板和 completion gate，而不是导入外部 shell 脚本。
