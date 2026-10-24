# 审查优化交付与 ADK 8.0.40 接入

## 授权与冻结基线

用户已授权“按建议全部优化落地”，沿既有独立审核、受保护 PR、提交、合并和发布流程自动推进。Root 前一阶段已由 PR #270 合入 `9c5dd7840548a36dd78969e5fd7dbd208cf78a21`，tree `0f21141482de5574f96aa6561c32d3b560cdf6b6`；该基线锁定正式 ADK 8.0.39 / `415590db44e88979185efb850e2339a3f95411ef`。本 change 在新的隔离分支、升级前冻结。

## 目标与范围

在 ADK 的 bundle 验证、归档信任边界、共享进程与 smoke 修复完成独立审核并正式发布 8.0.40 后，用唯一 canonical promotion 事务接入精确已发布来源。六项事务路径保持为 gitlink、adk.lock、interface lock、current-status 和两份原始 promotion 文件。已有 Root F3、八文件整理及前次审查证据保留原始来源身份；本 change 另行记录交付与接入的实际证据。

风险等级 E3。不修改保护规则、预算阈值、签名 identity/issuer、CI required checks、Native authority 或产品放行规则；不使用付费模型资源。

## 验收条件

- ADK 新版本来自受保护 main 的精确 SHA，实际 main CI 成功，annotated tag 不移动，正式 Release 为 immutable 且三资产完整。
- 原始 main promotion evidence ZIP、JSON 和 Sigstore bundle 保持原字节；正式发布资产、checksum、release contract、干净源码重建及签名均对应同一版本/commit/tree。
- 8.0.39 → 8.0.40 安装、升级、回滚演练通过；旧文件字节、模式与 receipt 恢复。
- canonical promotion 先 dry-run，再 apply，六路径原子暂存；原 applied-not-verified 回执保留，后续验证另列，不改写历史状态。
- Root 原始全量回归与消费者检查、独立 Spec/Quality 审核、精确候选 CI、合并后实际 main CI 均成功。
- 缺少真实 Native、G22、LTA、field 与 Product M5 证据的状态如实保留；source/test PASS 不推导产品资格。
