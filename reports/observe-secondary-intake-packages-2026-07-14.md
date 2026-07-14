# Observe Secondary Intake Packages（2026-07-14）

## 目的与边界

本报告为 Agent Client Protocol（ACP）与 Agent2Agent Protocol（A2A）的 secondary intake package。两项均为 `observe-method-only`：只记录协议范围、架构/Skill/Workflow 映射、复审触发器和风险边界，不引入 SDK、transport、server、client、connector、submodule 或外部写权限。

共同边界：

- `runtime_enabled=false`，`install_scope=none-method-only`。
- 不声明 ACP/A2A compatibility，不运行 conformance suite。
- 不自动发现、连接或调用远程 Agent。
- 不创建 credential，不修改网络、MCP 或 runtime 配置。
- 外部 AgentCard、message、artifact、schema 和 capability metadata 一律视为 untrusted input。

## Package 1：Agent Client Protocol v1

### 来源与状态

- 官方仓库：https://github.com/agentclientprotocol/agent-client-protocol
- 官方文档：https://agentclientprotocol.com/get-started/introduction
- 复核日期：2026-07-14；`expires_at=2026-09-12`。
- 许可证：Apache-2.0。
- 当前判断：wire protocol stable version 为 `1`；schema artifact release version 与 wire protocol version 必须分开处理；remote-agent support 仍在演进。

### ASW 分层

- Agent：`agent-dev-kit/agents/architecture-planner/AGENTS.md`，负责判断是否真的出现 editor-agent transport 架构需求。
- Skill：`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md`，用于冻结 initialize/version/capability、message schema、error 与 compatibility contract。
- Workflow/Runbook：`agent-dev-kit/docs/runbooks/upstream-intake.md`，用于来源、license、security、runtime boundary、验证和回退审批。

### 激活触发器

只有同时满足以下条件，才允许从 observe 进入独立 proposal：

1. 出现明确的 editor/IDE client 与 coding-agent server 组合，且现有 target export 无法满足。
2. 固定 ACP `protocolVersion`、schema artifact version、capability negotiation 和兼容范围。
3. 定义 local stdio 或 remote HTTP/WebSocket transport；remote 模式必须另做 auth、TLS、egress 和 tenant boundary review。
4. 提供正负 compatibility fixtures、failure/timeout/cancel 行为和 rollback。
5. owner 明确批准 dependency、install scope 与 runtime activation。

### 风险与回退

- 权限：编辑器文件/terminal 能力不得从 capability metadata 自动升级。
- 凭证：本地 stdio 默认无网络凭证；remote 凭证只能来自 runtime secret store。
- deny path：secret、credential、用户级 runtime state 和工作区外路径默认拒绝。
- 日志：只记录 protocol version、method、status 和 redacted IDs，不记录 prompt、diff 正文、文件内容或 token。
- 回退：禁用 adapter，恢复原生 target export/CLI handoff；不迁移持久数据。

## Package 2：Agent2Agent Protocol 1.0.0

### 来源与状态

- 官方规范：https://a2a-protocol.org/latest/specification/
- 官方仓库：https://github.com/a2aproject/A2A
- 复核日期：2026-07-14；`expires_at=2026-09-12`。
- 许可证：Linux Foundation 项目，Apache-2.0。
- 当前判断：latest released specification 为 `1.0.0`，覆盖 Agent discovery、interaction modalities、task 和 artifact；与 MCP 的 tool/resource 连接职责互补，不应混为一层。

### ASW 分层

- Agent：`agent-dev-kit/agents/architecture-planner/AGENTS.md`，负责判断是否存在独立、跨框架、跨网络 Agent 协作需求。
- Skill：`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md`，用于冻结 Agent Card、task/message/artifact、version 与 error contract。
- Workflow/Runbook：`agent-dev-kit/docs/runbooks/upstream-intake.md`，用于协议/SDK 供应链、安全、验证、owner approval 和 rollback。

### 激活触发器

只有同时满足以下条件，才允许从 observe 进入独立 proposal：

1. 出现无法用本地 subagent handoff 或 MCP tool contract 表达的跨 Agent 业务需求。
2. 固定协议版本、binding、Agent Card schema、task lifecycle、artifact integrity 与 compatibility matrix。
3. 完成 peer identity、authentication、authorization、discovery allowlist、replay protection、rate/operation caps 和 audit 设计。
4. 对 Agent Card、message、artifact 做 schema validation、prompt-injection 防护和 size/content limits。
5. 提供本地 fake peer 的正负 conformance fixtures、kill switch、failure containment 和 rollback。

### 风险与回退

- transport：默认不监听端口、不开放 discovery、不访问 remote Agent。
- 凭证：peer credential 必须按目标环境单独授权，不进入仓库或 trace。
- 工具：remote Agent 不继承本地 tool、filesystem 或 user approval。
- deny path：工作区外文件、secret、credential、runtime state 默认拒绝。
- 日志：只保留 version、peer pseudonymous ID、task state、artifact digest 和 redacted failure，不存 message/artifact 正文。
- 回退：关闭 A2A binding，终止未完成 task，保留摘要证据，回到本地 handoff；外部副作用需独立 compensating action。

## 当前落点与验证

- 来源、candidate 和 watch contract：`agent-dev-kit/manifests/external_agent_pattern_contracts.json`。
- runtime-negative fixture：`agent-dev-kit/fixtures/agent-ecosystem-standards/fail/interop-runtime-enabled.json`。
- 跨 manifest 门禁：`agent-dev-kit/scripts/check-agent-ecosystem-standards.sh`。
- 总体调研与 adopted contracts：`reports/agent-ecosystem-standards-absorption-2026-07-14.md`。

当前没有 runtime、dependency、install 或 compatibility 产物；这正是 observe package 的通过条件。
