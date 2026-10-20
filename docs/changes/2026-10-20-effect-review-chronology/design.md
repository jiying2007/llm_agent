# G22 Owner 评审时间顺序：设计

复用 effect_preregistration 已完成验证的预注册、campaign/receipt 观测与收据签名时间，返回 latest_evidence_at。effect_readiness 将该值与成功 replay 的 receipt_set.as_of 和 aggregation_window.through 取最大值，作为 evidence_completed_at。

Owner 校验器要求 reviewed_at 不早于该下界；结果附带下界，方便核对。签名验证仍由既有实现完成，不增加另一套解析或信任入口。

## 迁移与回滚

输入 schema 与摘要绑定不变。历史评审如存在不可能的时间线，应由真实 Owner 查证并更正，不能自动回填时间。

回滚需整体回滚生产调用链与相关回归，不得绕过验签、替换真实 evidence 或将测试数据写入有效证据索引。
