# MCP 2026-07-28 独立 Owner Activation Decision Request

## 状态

`completed`。owner `leiwenjun` 已选择 `ACTIVATE`，decision ID：
`mcp-act-2026-07-31-leiwenjun`。

正式机器可读记录：
`agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/owner-activation-decision.json`。

## 请求

owner `leiwenjun` 已对 candidate `epc-c6f947d482aa8aa0c78f` 作出新的独立 activation
decision。四项技术前置条件已完成，active protocol governance contract 已切换为
`2026-07-28`；runtime 与 Tasks/Apps/extensions 仍全部关闭。

## 技术结论

| Gate | Result |
|---|---|
| schema compatibility fixture | PASS |
| version-pinned client/server smoke | PASS |
| auth boundary verification | PASS |
| rollback smoke | PASS |

验证绑定 `github.com/modelcontextprotocol/go-sdk v1.7.0-pre.3`、SDK commit
`827f90ba0c13edb546028df42fadc9f1211a4ff2` 和 digest-pinned Go 1.25.1 image。
offline 阶段使用 Docker `--network=none` 和容器内 loopback。

## Owner 可选结论

- `ACTIVATE`：只提升 `2026-07-28` protocol governance contract；runtime 和所有 feature
  继续 disabled。
- `HOLD`：保留 evidence，继续 active `2025-11-25`。
- `REJECT`：记录拒绝理由，继续 active `2025-11-25`。

## Evidence

- ADK change：
  `agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/`
- verification：
  `agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/verify-report.md`
- review：
  `agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/review-report.md`
- decision contract：
  `agent-dev-kit/schemas/mcp-protocol-activation-decision.schema.json`

## 已知限制

Go SDK 是 pre-release；loopback evidence 不覆盖真实 IdP、proxy、跨 SDK、性能或长稳。
根工作区 quick aggregate 为 49/54，失败属于过期 reference baseline、stale artifact hash、
gitlink/lock 状态和当前合法 dirty 变更。因此只能声明 MCP 固定范围技术就绪，不能声明
整个工作区全绿。

## Owner response

- decision：`ACTIVATE`
- rationale：接受当前固定版本技术证据及已披露的预发布和单SDK验证风险，同意仅激活协议
  治理契约，runtime 与 Tasks、Apps、extensions 继续保持关闭。
