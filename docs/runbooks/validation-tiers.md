# Validation Tiers

先运行：

```bash
rtk python3 -m tools.codex_assets.validation_plan --root . --summary-json
```

计划以diff fingerprint绑定L1-L4最小验证面：L1文档/证据，L2定向测试，L3共享代码/合同，L4版本、release、M5和lock。L4的build/rehearsal只允许在clean commit执行；working tree阶段只完成源码、负例和supported parity，不产生release authority。

成功结果只保留摘要与receipt；原始日志只在失败时有界展开。snapshot、工具定义或image漂移后receipt立即失效，不得跨快照复用。

执行阶段只维护临时checkpoint/receipt；长期release evidence在源码与验证稳定后一次生成。push后的状态变化使用小型publication receipt，不重复改写大报告主体。

## 快照边界

计划返回 `snapshot_contract=managed-diff-v2`。指纹绑定 baseline tree、受管 diff、未跟踪文件内容/执行位、符号链接目标和受管 dirty 子仓自己的内容快照。父仓中的 `<commit>-dirty` 字样不能单独证明子仓内容未变。

参考仓、团队输出和根 `.cache/` 在读取与 hash 前排除，仍保留于 `excluded_paths` 供审查；这些根仓排除策略不下传到 ADK 内部同名产品目录。符号链接只读取链接目标文本，不跟随到外部文件。

`--staged` 只绑定 index diff 和所引用 gitlink，不把子仓未暂存内容计入 staged 证据。它不意味着工作树已验证。全仓受管 gitlink 变化继续保守使用 L4，不能以本轮任务较小掩盖既有集成 dirty。

本指纹只用于 diff 验证计划；它不是原子文件系统快照，也不绑定解释器、容器、依赖和验证器版本，不可替代 supported-full receipt 或 release/source-to-live identity。并发编辑期间必须重新生成计划；旧版指纹不复用。
