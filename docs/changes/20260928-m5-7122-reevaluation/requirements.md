# ADK Software M5 重评准备

## 授权与目标

用户最初选择从 ADK 7.12.2 启动 Software M5 重新评估。受保护 PR 的版本前进门禁及 main CI 修复将最终可推广源码提升为 7.12.4；根仓 exact pin 与当前 main 签名推广已同步。此决定授权本地评估入口修复、证据前置核验和评估计划；不等于批准未知费用模型调用、签名豁免、产品资格升级或 rollover `--apply`。

## 验收

- 根仓 measured runtime-smoke 收集器调用当前 ADK `scripts/devkit.sh`，执行时显式限定结果数并要求未知费用确认。
- 收集器拒绝缺少任务快照、grader、逐例提示词摘要、观测模型或源 Manifest 身份的旧版/伪造报告。
- 只读/fixture 验证通过；真实 Codex smoke、签名 bundle、root integration run 和 Software M5 certifier 分别形成新证据后才可执行事务 rollover。
- Python 3.11 根仓入口保持兼容；ADK Python 3.8 原生行为不得受影响。

本批不修改 `software_m5_policy.json`、scorecard 或当前状态声明，不生成 synthetic production evidence。
