# OSS Deep Assessment: planning-with-files

- 日期：2026-06-29
- 评估层级：git submodule active reference
- 生命周期：monthly observe

## 深度结论

`planning-with-files` 值得长期观察，因为它提供了可实证的长任务状态管理模式。它的价值不在于替代 ADK 计划流程，而在于提醒 ADK 对以下问题持续收口：

- 长任务跨上下文丢失后的恢复；
- 计划正文和执行证据的分层；
- 压缩前的状态 flush；
- 完成声明和未完成 phase 的 gate；
- 多计划并行时的 active plan 选择。

## 不进入默认运行时的原因

ADK 默认应该轻量、低噪音。`planning-with-files` 的 hook 和文件写入适合长任务，不适合简单问答、小修小改或只读分析。

## 观察指标

- hooks 安全边界是否继续收紧；
- attestation 和 active plan 是否有更轻量实现；
- Codex 官方 hooks 适配是否稳定；
- 是否有新的 eval 证明质量收益大于 token/文件成本。
