# Validation Tiers

先运行：

```bash
rtk python3 -m tools.codex_assets.validation_plan --root . --summary-json
```

计划以diff fingerprint绑定L1-L4最小验证面：L1文档/证据，L2定向测试，L3共享代码/合同，L4版本、release、M5和lock。L4的build/rehearsal只允许在clean commit执行；working tree阶段只完成源码、负例和supported parity，不产生release authority。

成功结果只保留摘要与receipt；原始日志只在失败时有界展开。snapshot、工具定义或image漂移后receipt立即失效，不得跨快照复用。

执行阶段只维护临时checkpoint/receipt；长期release evidence在源码与验证稳定后一次生成。push后的状态变化使用小型publication receipt，不重复改写大报告主体。
