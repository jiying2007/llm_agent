# 增量 CI 的真实输入覆盖

## 目标与边界

修复 2026-10-24 全面审查 F3。冻结 Root 候选 `64c5192f2d6aaacf65143223f03190564032facc`、main `7ba2d71e210955464839d5177c0f7d6a86ac072b`。用户授权按建议全部优化落地，并沿用已授权自动审核、受保护提交和合并。

报告、fixtures、subrepos、schemas 与打包配置变化必须触发实际消费它们的检查。真正无关的说明文字仍保留轻量路径，不新增平行 CI 框架或提高预算。

## 验收

- 单独新增 reports 文件导致维护预算失败时必须调度该检查。
- 单独修改 adoption matrix 导致 removal 摘要过期时必须调度对应检查。
- schema、fixture、pyproject 和相关治理输入均有明确覆盖。
- rename/delete/异常 Git 路径继续失败关闭；无关普通文档可解释地 NOT_REQUIRED。
- 恢复上一轮八文件整理成果后严格报告数为 320；保留原始失败及审核历史。
