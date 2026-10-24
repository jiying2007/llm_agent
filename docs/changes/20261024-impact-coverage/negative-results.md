# 整合负结果

- 原输入映射的真实负例保存在 `evidence/impact-consumers-red.json` 与 `evidence/impact-readme-red.json`，不修改原件。
- 共享配置和 README validator 合入工作树后的首次 24 测有两项断言失败：原 shell 将 Python validator stdout/stderr 重定向，新增轻量检查提前失败后不会再走到后续 Python assert 的 README 提示。保留 shell 非零断言，将明确 README 诊断断言放到实际常驻 gate 命令输出；不改变生产检查或降低失败要求。
- 首次 contract profile 的 status-projection 正确拒绝已变更的 gates 摘要；后续通过 canonical status projection 只刷新派生来源字段，保留历史验证日期与 release_authorized=false。
- 原沙箱全量回归在 check-all 同进程证据测试中无法读取真实父进程 `/proc/<pid>/stat`；同一未改测试在宿主执行退出 0。后续宿主全量回归通过前 47 项，在 registration 的 chmod 555 故障注入失败：当前 uid 0 仍可写该目录。保持原检查、测试及门禁，使用普通用户隔离副本复验，不以 root 的权限行为改写产品语义。
- 全量测试在 ADK 子模块生成的 `reports/runtime/root-native-campaign-*/receipt.json` 为本轮夹具产物，已移到工作区外的本轮验证目录保留；不提交为真实运行回执。
