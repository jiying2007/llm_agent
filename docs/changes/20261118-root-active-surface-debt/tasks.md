# 执行与审查

- [x] 固定 Root main 与 ADK 11.4.4 精确身份，核查 runtime target Manifest。
- [x] 逐个检查 Root 现行 scripts/、CI 和现行 runbook 的旧版本及恢复入口。
- [x] 删除已失效和危险的两条旧脚本，收敛 AGENTS/README/部署及质量门禁说明。
- [x] 增补阻止退役脚本回流的确定性回归。
- [ ] PR exact-head 原 CI 与影响报告。
- [ ] 受保护合并及 actual-main 签名 CI 回执。
- [ ] 需要 ADK 新发行时，以原晋级工具另行生成 Root 消费事务，不篡改此变更的资格状态。

## 回滚
回退仅通过另一个受保护 PR 撤销本变更；不恢复无源的目录写入脚本，不移动发行标签，不改历史原始证据。
