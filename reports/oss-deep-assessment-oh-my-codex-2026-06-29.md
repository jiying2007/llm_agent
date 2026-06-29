# OSS Deep Assessment: oh-my-codex

- 日期：2026-06-29
- 评估层级：git submodule active reference
- 生命周期：monthly observe

## 深度结论

`oh-my-codex` 值得长期观察，因为它的增量集中在 Codex 运行态边界和复杂任务状态治理，而不是普通 skill 文案。它与 `llm_agent` 的重叠点是：

- Codex live apply / plugin bundle / skill root 的边界；
- 长任务 goal 和状态恢复；
- 多 worker / worktree / session scope 的漂移修复；
- release 与 QA 证据完整性。

## 不进入 ADK core 的原因

ADK 应保持平台中立。OMX 是 Codex-specific runtime，不能直接进入 ADK core；只能作为 Codex profile 或 `~/codex` 控制面参考。

## 观察指标

- 是否出现新的 Codex 官方 hooks/plugin API 适配经验；
- 是否有 release protocol、doctor smoke、session scope 相关修复；
- 是否形成可转成 report-only gate 的稳定模式。
