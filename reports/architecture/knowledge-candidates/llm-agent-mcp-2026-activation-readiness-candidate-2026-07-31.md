# Knowledge Candidate：MCP 协议激活应拆分技术就绪与独立 Owner 决策

## Metadata

- project：llm-agent / agent-dev-kit
- type：validation / decision
- date：2026-07-31
- review_status：candidate
- sensitivity：internal-non-secret
- source change：
  `agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/`

## 可复用结论

协议 final metadata、compatibility evidence、active protocol、runtime enablement 和可选
feature enablement 必须是五个独立状态。metadata 刷新不能隐式成为 compatibility；
technical readiness 通过也不能隐式成为 activation。

有效的 MCP protocol activation gate 至少包含：

1. 显式 JSON Schema draft 的正负 fixture；
2. 固定 SDK version/revision/checksum 与固定 build image digest；
3. 真实 client/server discovery、list、call 行为 smoke；
4. issuer、audience、scope、expiry、no-token-passthrough 的 auth boundary；
5. 旧协议正向可用、候选协议 fail-closed 的 rollback smoke；
6. 独立 owner 的 ACTIVATE/HOLD/REJECT 决策合同。

## 证据边界

本次通过证据只绑定 Go SDK `v1.7.0-pre.3`、offline container loopback、stateless
Streamable HTTP 和本地 synthetic auth verifier。它不能替代真实 IdP、反向代理、跨 SDK、
性能、长稳或生产 rollout evidence。

## 关键治理模式

- `final_compatibility_claim` 必须与狭义 `compatibility_scope` 和不可变 evidence identity
  一起读取。
- owner `ACTIVATE` 可以只授权 protocol governance contract；runtime 与
  Tasks/Apps/extensions 应保持独立 false。
- 实现者不得代签 owner decision。
- 失败实验与错误假设应保留在 negative-results，避免下一轮重复踩坑。
- 全仓 aggregate 失败必须与 scoped technical evidence 分开陈述，不能用局部绿灯冒充
  整体可合并。

## 本次决策结果

- owner：`leiwenjun`
- decision：`ACTIVATE`
- decision ID：`mcp-act-2026-07-31-leiwenjun`
- active protocol：`2026-07-28`
- active scope：`protocol-governance-contract-only`
- runtime / Tasks / Apps / extensions：全部 disabled
- rollback target：`2025-11-25`

## 复用条件与失效条件

- 新 SDK version/tag、protocol revision 或 container digest 出现时，旧证据失效并需重跑。
- 引入真实 IdP、proxy、不同 transport 或 feature enablement 时，需要独立扩展证据。
- owner decision 前 source/package evidence 超过 1 天，必须刷新 freshness。

## 排除内容

- 不归档 synthetic bearer 值、原始 session、cache、容器层或外部 credential。
- 不把本 candidate 当作已经批准的 activation decision。
