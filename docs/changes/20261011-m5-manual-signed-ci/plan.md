# M5 受信手动完整 CI 采集计划

- work_item_kind: implementation
- implementation_permission: 用户已全部授权源码修复、提交推送PR合并和有界真实证据采集
- exit_gate: 精确main受信手动事件、显式force、全部required jobs成功、真实签名回执；任何缺项blocked
- handoff_target: 真实runtime与同baseline qualification
- retry_budget: 每个外部操作一次，未知写结果先对账
- staleness_threshold: final/main身份变化须重新核验，不重标旧证据
- retention: 脱敏结论Provider reviewing；原始凭据与完整会话不归档

## 目标与根因

PR194已合并到main455df932；该mainCI成功，但tools-only影响未要求integration-deep，因此签名rootCI job跳过。既有workflow_dispatch可强制完整集成，但签名job和producer/consumer仅接受push，无法取得该基线的正式签名CI回执。

## 实施

仅允许canonical main的push，或显式require_adk_integration=true的workflow_dispatch。保留contract/doc-sync/integration/integration-summary全部success前提、同一certificate identity与issuer。producer从真实GITHUB_EVENT_NAME记录event，手动事件必须有env精确true，并签入integration_forced booleantrue；consumer要求同一签名字段及全success，不把manual重标push。既有push回执保持兼容，不扩大ADK promotion事件规则。

## 分阶段验收

1. producer/consumer正负例与workflow条件回归；独立复审、准备目标与Runtime门禁。
2. 授权提交推送创建PR；核最新CI后match-head合并，不触碰原主仓dirty或live。
3. 最终main显式dispatch require_adk_integration=true；只有完整集成和签名实际成功才下载验证rootCI receipt。无自动retry，不发emptycommit改变基线。

## 现实边界

没有专用runtime主机时可评估本机一次性runner。已只读验证本机Linuxx64、Codex登录状态和bwrap只读隔离；未注册runner、部署服务、复制凭据、dispatch模型或声称humanpilot。真实field/owner不能自动生成，环境保护和实际执行身份仍须分别验收。
