# 实施设计

## 正式组件晋升

ADK 8.0.37 修复 Manifest 消费端提前退出导致的管道失败，以及 Harness 默认日期与 UTC 审核日期不一致的问题。正式源为 commit `19a89bab07c42f4fe506bafe5b8c8e64e1e1baf3`、tree `4d6f92286ce32aee3afec88399301be6dce7c07a`、manifest blob `4d7517e2938948e3990b7a820a8444185b856012`。

先保持 Root index 干净，仅允许 ADK checkout 差异，再由 `scripts/promote-adk.sh` 原子更新六条既有路径：gitlink、`adk.lock`、interface lock、current-status projection、promotion evidence 和 Sigstore bundle。随后运行既有 promotion verifier，核对锁定声明、工作流证书身份和 OIDC issuer。说明修订在该事务成功后单独加入。

## 五处说明同步

| 文件 | 说明位置 | 现有行为的准确表述 |
| --- | --- | --- |
| `manifests/comprehensive_optimization_backlog.json` | G22 implementation target | v6、逐资产决定、source-pinned 独立委派 AI 审核 |
| 同上 | G22 blocking condition | 真实执行、签名、全资产覆盖与实际委派 AI 审核共同构成终局条件 |
| `manifests/long_term_asset_qualification.json` | LTA-04 acceptance | summary review 两种模式；未解决的 blocking 风险或 hold 阻断 |
| `docs/runbooks/solo-maintainer-continuity.md` | 日常连续性说明 | 可验证的 summary review |
| 同上 | 终局规则 | 明确 registered-human / policy-authorized owner-delegated-ai |

G22 v6 的 review mode 仍固定为 owner-delegated-ai；LTA 的双模式仅适用于摘要审核。当前实现、schema、原始授权日期、审核策略、现场数据和资格阈值沿用现有定义。

## 可复核交付

本地与正式发布包逐字节比较，使用正式前后版本执行隔离安装、升级与回滚演练。最终 Root 验证计划覆盖从基线 `d89d2cdd23b799bb89ee3d069f6ea78d921fae90` 开始的整个变更。最终 head / main / release-clean 结果在本次 Root PR 最终正文与审计原件中记录，避免为补写后续结果不断改变已审核源码。
