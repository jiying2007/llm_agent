# Root 检查入口兼容修复

## 目标与基线

按 Owner 已冻结的 R1/R2/R3 范围修复三个既有 Root 集成缺口。独立维护工作树以 source-only 升级提交 `eddb3a2baf1158c016c8326694412d2231bcc1c1` 为基线，消费 ADK 11.3.11；不修改该升级的 Gitlink 或当前状态说明。

1. source-pin 包装入口消费通用位置 root，并继续支持既有 flag-only 调用，将实际校验交给 `tools.control_plane.adk_interface`。
2. stale-reference 测试中的合成负例采用既有字符串拼接方式，避免测试源码本身成为 active 陈旧引用；生成的负例仍被真实扫描器拒绝。
3. Root validation plan 与 harden receipt 调用使用 pinned ADK 接受的 Python 3.12 选择器，保留 full 模式、receipt 校验及失败传播。

## 验收

- 用实际 Git fixture 和实际 CLI 验证默认/位置/flag-only root、空格/相对路径、非仓库 cwd；校验失败和参数错误保留原退出码及输出。
- 原始 fixture 产生的陈旧命令仍被检出；真实 Root scanner 通过；扫描规则和路径范围不变。
- 实际 plan 命令和 harden receipt 参数通过 pinned ADK `--dry-run`；不支持的选择器仍返回 2。该证据只说明调用兼容，不声明 Docker parity 或 receipt 有效。
- 保留修改前 RED 与修改后 GREEN；仅做必要定向验证及一次 Root quick 对照。

## 非目标

不修改 ADK、Root pin/current-status、门禁策略、失败预算或历史资格。缺少活动 `~/codex`、过期 reference baseline 与历史 M5 失败保留原样。无 commit、push、live apply 或网络写入授权。
