# 当前源码与历史资格的严格边界

`llm_agent` 是不自行发布组件的研究/控制工作区；`agent-dev-kit` 是不可变组件 Release 的权威。两者的组件可发布性、当前产品资格、实际 runtime 和长期现场证据是不同事实。

## 优先读取哪一份权威

- **源码身份**：`adk.lock`、`manifests/adk_interface.lock.json` 与 gitlink 一致性。
- **当前消费资格**：`reports/current-status.md` 的 generated-current-source-projection，结合真实 `software-m5-certify` 校验；`release_authorized=false` 不得被 historical scorecard 代替。
- **历史产品 M5**：`manifests/product_maturity_scorecard.json` 及 `reports/current-status.md` 的 Last Verified Product Baseline，只适用于其固定源码和当时的证据。
- **组件发布**：ADK GitHub immutable Release、签名推广与精确制品 digest；不自动产生新的 field/product 资格。
- **长期资格**：`manifests/long_term_asset_qualification.json`。LTA-04 只接受实际独立现场日志、完整摘要和注册人类 owner 审核。

## 状态判定

1. 当前 ADK commit 与历史候选不相同时，即使 PR/CI/Release 成功，Root 仍为 `HISTORICAL_NOT_AUTHORIZED`。
2. Product M5 的历史 `pass` 在 LTA qualification layers 中显式标记 `historical-last-verified-product-m5-baseline`，不代表当前源码可用。
3. 真实 30 天窗口届满仅解除时间条件，不产生 `PASS`；即便当前观察事件数为零，也须由真实摘要、事件集合闭环与 owner 审核证明。
4. `--as-of` 时间旅行输出为 `simulated_pass`，`terminal_qualified=false`；不得作为真实 owner/field/release 记录。
5. 证据缺失、过期、模型 identity 为 alias 或只完成 deterministic fixture 时，要保留 blocked/not-measured/inconclusive；禁止补默认零值、复制历史 receipt 或静默提升资格。

## 稳定消费而非追随 HEAD

团队日常运行目标应绑定一个已批准的 ADK 版本、来源 commit/tree、已审核 profile 组合、目标 adapter 和回滚点；新主线先独立验证、重新测量与审核，随后才更新稳定消费基线。不要为方便快速更新而降低 exact-source 约束，也不要为单次未授权候选重复制造额外发布权威。

## 效果门禁与实际收益

现有 `docs/runbooks/effect-readiness.md` 是 G22 唯一效果证据入口：固定相同任务/模型 revision/控制条件，比较原生运行时基线、按需 ADK 与新候选。记录最终正确性、错误路由、人工返工、耗时和真实 token。软件准备好不等于效果验证成功；不为追求“终态”生成模型未执行的 trial/receipt 或 owner decision。
