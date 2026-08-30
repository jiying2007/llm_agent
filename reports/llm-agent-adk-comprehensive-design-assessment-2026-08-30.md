# llm_agent / agent-dev-kit 全面设计评估归档（2026-08-30）

- 状态：`reviewed-needs-fix / provenance-remediation-applied / release-not-ready`
- Topic：`llm-agent-adk-comprehensive-design-assessment`
- Source：2026-08-30 当前会话的只读仓库评估、命令验证与官方/开源一手资料复核
- Captured at：2026-08-30（Asia/Hong_Kong）
- Last verified：2026-08-30
- 范围：`llm_agent`、`agent-dev-kit` 及其声明式 source-to-live、runtime target、Knowledge Hub handoff 边界
- 非目标：不替代 `manifests/product_maturity_scorecard.json`；不启用 MCP/Hook/Plugin，不发布、不推送、不执行 source-to-live，不把本地候选外推为 runtime/field/M5 认证
- 脱敏：未保存 prompt、完整会话、raw log、凭证、私有端点、cache、runtime state 或个人身份推断

## 1. 执行摘要

### 1.1 后续实施更新

Owner 随后批准把平台收敛变更定义为 `5.0.0-rc.1` 本地候选并创建 ADK 子仓本地提交。当前结果：

- 当前 ADK commit：`12bfeaf1f85b297628b57ac15d12eedc849e3919`（`fix(release): 收紧候选溯源与验证调度`），已推送至 `origin/main`。
- 已落地 routing IR v2、平台中立 core、Workflow IR、Runtime Control V2、target contract v2、Trace/Agent Value/Evidence Graph/Run Evidence/Effect Comparator 和维护性 evidence candidate。
- ADK host full suite：68/68；受控 Python 3.11.15/3.12.13 quick：各 29/29，routing：30/30，wheel 与 dependency audit 通过。
- 本地 `5.0.0-rc.2` clean-commit-bound source distribution build/check 通过；ADK source 已 push，未执行 tag、远端 release 或 source-to-live。
- Claude Code 2.1.138 由 repository owner 显式裁决为默认通过；机器证据标为 `owner-attested`、`runtime_measured=false`，不冒充 native conformance 或双 runtime campaign。
- 原 `4.0.0 -> 5.0.0-rc.1` rehearsal 已被全面复审判定无效：previous artifact 混入 5.x working-tree 内容，正式 4.0 artifact 当前不可用。
- 根仓 quick working-tree gate 为 55/55；父仓集成提交 `048793d` 已推送。tag、release 和 source-to-live 仍需独立授权。
- ADK Python 3.11.15/3.12.13 full parity 各 68/68、routing 30/30、wheel/audit 通过；根仓最终回归结果以 release evidence 为准。
- 父仓 gitlink 提交后 release-clean quick gate 为 54/54，lock/gitlink/current-status/M5 declaration 全部一致。
- 复审整改已落地：release build 绑定 clean commit/tree，dirty/unbound snapshot 不可发布；M5 policy v2 校验 previous release continuity；exact 4.0 target-contract hard-cut source transition 通过；Codex/Claude evidence 增加当前身份和 freshness；5.x campaign 使用独立 identity；release harden 强制 Python 3.11+。
- 最终 supported full parity：Python 3.11.15、3.12.13 各68/68，routing30/30、wheel、security、performance和dependency audit通过；稳定content snapshot `96dd21e4...`。
- Token/流程优化已落地：active-doc budget恢复pass；local-CI成功只输出摘要、失败展开120行；full parity生成content-tree receipt并连续复验两次；harden复用receipt跳过重复full；diff classifier输出L1-L4并延迟clean-commit-only release动作；Runtime Control idle在repo规则中为not-applicable。
- 最终门禁：Token budget pass（active doc 512/520，累计AGENTS估算2520）；root regression 23/23、working-tree quick55/55；harden消费receipt并跳过第二次双Python full。

下文第 3 节的门禁与规模数据保留为评估开始时的证据快照；本节和 ADK 内 `docs/changes/adk-platform-convergence-v1/verification-evidence.md` 是实施后的新鲜边界。

`llm_agent` 与 `agent-dev-kit` 的产品方向总体正确：

- `llm_agent` 负责外部实践观测、不可变来源分析、采纳决策、证据和成熟度治理。
- `agent-dev-kit` 负责 Agent、Skill、Workflow、Profile、Target 和治理契约的结构化建模、编译、导出、安装、验证、评测与发布。
- 两者都不应扩张为通用 LLM 推理循环、生产会话调度器或通用 Agent runtime。

系统已进入平台演进的第二阶段。第一阶段解决“能力、规则和门禁是否存在”；第二阶段需要解决：

1. 多套 SSOT 和路由语义是否收敛。
2. 资产数量增长是否带来认知熵和维护负担。
3. 本地 source/test 证据是否能转化为真实 runtime/field 效果。
4. Profile、Workflow、MCP、Hook 和 Plugin 是否具备清晰的控制面/执行面边界。
5. 证据能否低成本保鲜、自动失效并支持独立复核。

综合判断：

- 当前 `M3` 仍是合理产品等级。
- `5.0.0-rc.2` 已形成 source-committed、source-pushed、clean-artifact-built、diagnostic-transition-verified 候选；这仍不等于正式 release continuity、live 或 M5 certified。
- 下一阶段不应优先增加 Agent、Skill、Manifest、Checker 或报告，而应优先统一 IR、瘦身 core、补齐真实运行证据和删除冗余资产。

## 2. 评估范围和方法

### 2.1 评估维度

本次覆盖：

- 存在目标、产品边界和用户价值
- 设计原则、领域模型、SSOT 和兼容策略
- 总体架构、跨仓职责和 source-to-live
- 功能、性能、可靠性、安全和操作体验
- 测试、评测、发布、回滚和现场证据
- Agent、Skill、Profile、Workflow
- MCP、Hook、Plugin、Automation
- 迭代、外部实践吸收、知识治理和长期资产
- 可维护性、Token/上下文成本和控制面熵

### 2.2 证据方法

- 读取根仓与 ADK 规则、README、成熟度模型、scorecard、manifest、架构报告和 runbook。
- 读取 typed core、matcher、Agent/Workflow 示例和 MCP/Hook 合同。
- 运行当前轻量/严格门禁、capability health、workflow closure、harness readiness 和本地 benchmark。
- 构造组合否定路由反例，检查现有合成集未覆盖的边界。
- 对照 OpenAI Harness/App Server/Symphony、MCP 2026-07-28、OpenTelemetry GenAI、Temporal、Microsoft Agent Framework、PydanticAI、LangGraph 和 Google ADK 的官方资料或源码仓。
- 区分历史验证基线、当前命令结果、实现能力和 field evidence，不用旧报告覆盖当前失败。

## 3. 当前资产与新鲜验证

### 3.1 资产规模

当前盘点结果：

| 资产 | 规模 |
|---|---:|
| ADK Agent | 13 |
| core Skill | 56 |
| optional Skill | 9 |
| 一等 Workflow | 7 |
| Profile | 9 |
| direct target | 3 |
| root shell script | 约 89 |
| ADK shell script | 53 |
| ADK shell test | 68 |
| ADK Python test file | 3 |
| ADK docs file | 420 |
| root report（维护性预算口径） | 313 |
| `manifest.json` | 2853 行 |
| `manifest.yaml` | 2177 行 |
| ADK typed core | 约 8841 行 Python |

### 3.2 当前门禁

| 命令 | 结果 | 证据边界 |
|---|---|---|
| `rtk scripts/check-all.sh --quick --working-tree` | 53/55 | 两项失败均为 28 条官方来源到期 |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | fail | 28 条 OpenAI 官方来源在 2026-08-24 至 2026-08-26 到期 |
| `rtk bash agent-dev-kit/scripts/devkit.sh capability health --summary-json` | 62 checked / pass | Python 3.8.10，仅 development evidence |
| `rtk bash agent-dev-kit/scripts/devkit.sh workflow-closure --profile core --summary-json` | 4/4 pass | Python 3.8.10，仅 development evidence |
| `rtk bash agent-dev-kit/scripts/devkit.sh harness-loop-engineering --summary-json` | 995 checked / pass | 本地合同验证 |
| `rtk bash agent-dev-kit/scripts/devkit.sh harness readiness --root agent-dev-kit --summary-json` | 6 pass、1 not-applicable | field evidence 仍为 not-verified |
| `rtk scripts/check-maintainability-budgets.sh --strict --summary-json` | pass | 表示未超过预算，不表示结构已轻量 |

当前系统解释器为 Python 3.8.10，仓库声明要求 Python 3.11+。因此本轮 ADK 命令虽有多个局部 pass，也不能升级为 release evidence。

### 3.3 本地性能基准

五次 development-only benchmark：

| 操作 | P95 |
|---|---:|
| manifest validate | 约 99 ms |
| profile resolve | 约 5 ms |
| export plan | 约 81 ms |
| target contract check | 约 195 ms |
| CLI cold start | 约 578 ms |
| 10 次 export plan | 约 822 ms |
| 10 次 native export I/O | 约 922 ms |
| 10 次 export plan peak memory | 约 281 KiB |

结论：本地控制面性能已较好。后续性能重点应转向端到端任务成本、人工等待、并发冲突、checkpoint/replay 和真实 runtime 效率。

## 4. 综合成熟度判断

| 维度 | 判断 | 说明 |
|---|---|---|
| 目标和产品边界 | 强 | 两仓职责清晰，拒绝通用 runtime 扩张是正确方向 |
| 设计和领域模型 | 中上 | 资产类型完整，但 SSOT、镜像和派生视图偏多 |
| 架构和解耦 | 中上 | intake、control plane、target、source-to-live 边界较成熟 |
| 本地功能完整性 | 强 | 编译、导出、安装、回滚、评测和发布均有真实实现 |
| 结果有效性 | 弱到中 | native runtime、独立仓、第二操作者和长期现场证据未闭环 |
| Agent/Skill 路由 | 中 | 资产丰富，但三套路由语义和组合否定误判仍存在 |
| Profile | 中 | 继承/闭包门禁成熟，core 仍混有嵌入式资产 |
| Workflow | 中 | 一等 Workflow 有合同，执行语义仍较依赖 Markdown/runbook |
| MCP | 强治理、弱运行 | 协议、认证、回滚成熟，默认 runtime disabled 正确 |
| Hook/Plugin/Automation | 中下 | 有审计合同，尚非 active 可编译运行资产 |
| 测试 | 本地强、现场弱 | 确定性回归充分，真实运行和多轮语言边界不足 |
| 性能 | 本地强 | 控制面快，真实模型/工具/人工成本未系统量化 |
| 安全和供应链 | 强 | 默认禁用、版本锁定、凭证边界和负例较完善 |
| 可维护性 | 中下 | 数量预算有效，但脚本、报告、大模块和规则面已经偏重 |
| 长期资产 | 中 | provenance/freshness 强，真实反馈和自动淘汰仍弱 |

## 5. 主要问题和优化方向

### 5.1 统一路由 IR

当前路由事实分布在：

- `manifest.json:routing.intents`（45 条）
- `skill_routing_matrix`（14 个场景）
- Skill frontmatter 的 `triggers/non_triggers`

运行 matcher 的全局路径主要使用短语匹配。明确指定单个 Skill 时会先检查 `non_triggers`；全局 routing 和遍历 Skill fallback 没有统一应用否定语义。

已复现反例：

| 输入 | 当前结果 | 期望 |
|---|---|---|
| 长任务但只做只读分析且无需执行计划 | `adk-planning-execution-loop` | readonly assessment 或 abstain |
| 根因不明但不要调试只做架构评估 | `adk-systematic-debugging` | architecture assessment |
| 准备发布但只需要解释现状不执行发布 | `adk-release-versioning` | readonly explanation |

建议建立唯一 `routing-ir/v2`：

- `task_mode`
- `intent`
- `negated_intents`
- `risk`
- `mutation_permission`
- `profile_availability`
- `required_evidence`
- `abstain_reason`

从该 IR 生成 intents、矩阵文档和测试，不再手工维护平行语义。执行裁决仍由确定性规则、schema 和 owner approval 完成，LLM 只生成候选理解。

### 5.2 瘦身平台中立 core

当前 `core` 仍包含：

- `driver-engineer`
- `adk-driver-implementation`
- `adk-driver-bringup-checklist`
- `adk-unit-test-embedded`
- `adk-static-analysis-c-cpp`

建议拆为：

- `core-minimal`：路由、需求、计划、架构、调试、测试策略、验证和 review。
- `software-general`：通用应用实现、API、构建和测试。
- `embedded-fullstack`：驱动、BSP、RTOS、C/C++、HIL/SIL、OTA 和现场维护。
- `release-hardening`、`team-core`：保留为叠加 Profile。

Profile 应从静态列表演进为“capability query → 最小闭包 → 冲突求解 → profile lock”。安装资产集合与单任务实际加载集合应分离。

### 5.3 控制面和执行面分离

目标结构：

```text
llm_agent：Practice Observatory / Decision / Evidence Registry
        ↓
agent-dev-kit：Asset Graph / Compiler / Policy / Eval / Release
        ↓
Runtime Adapter SPI：Codex / Claude / OpenCode / Hermes
        ↓
外部 Runtime / Scheduler：thread、model、tool、checkpoint、concurrency
        ↓
Evidence Bus：trace、cost、outcome、human intervention、fault、rollback
        ↺ 回灌 llm_agent 与 ADK
```

ADK 不实现通用 Agent loop。未来 Codex adapter 优先面向 App Server；scheduler、issue polling、worktree lifecycle 等保持外部执行面职责。

### 5.4 Workflow IR

建议将 Workflow 从“manifest + Markdown 合同”升级为 `workflow-ir/v2`：

- node/stage 输入输出 schema
- transition condition
- retry/timeout/cancel
- idempotency key
- side-effect class
- approval/owner gate
- checkpoint/resume
- compensation/rollback
- evidence emitted
- concurrency group
- terminal state

`WORKFLOW.md` 作为 IR 的人类可读投影。Durable execution 语义可参考 Temporal、Microsoft Agent Framework、LangGraph 和 PydanticAI，但不引入其 server/worker/runtime 依赖到 ADK core。

### 5.5 真实效果评测

当前 24 个 OOD/adversarial case 能证明既有合成集通过，但不能覆盖组合否定、多轮变化和真实语言分布。

建议测试阶梯：

1. schema/unit/property
2. asset compilation golden
3. routing contrastive/negation/abstention/metamorphic
4. target conformance 和 native discovery/load/trigger/rollback
5. 多 runtime baseline/ADK 对照 campaign
6. 独立仓库、操作者和长期 field evidence

建议核心效果指标：

- `task_success_rate`
- `first_pass_success`
- `human_interventions_per_task`
- `time_to_trustworthy_change`
- `escaped_defect_rate`
- `rollback_rate`
- `evidence_freshness_cost`
- `wrong_skill_cost`
- `abstain_precision`
- tool/context cache hit

Skill、报告、PR 或 Token 数量不作为质量 KPI。

### 5.6 维护性从数量预算升级为价值预算

当前预算允许的热点仍较大：

- root 最大 shell：666 行
- root 最大 Python：2078 行
- ADK 最大 shell：1747 行
- ADK 最大 Python：1054 行
- root report：313，warning limit 为 320

建议新增：

- 模块 fan-in/fan-out
- change coupling 和 churn
- 重复契约字段
- 同一结论的 SSOT 数量
- checker 重复扫描率和执行时间
- owner concentration
- inactive/unused Skill 比例
- 资产 invocation/outcome
- 删除和合并收益

优先按领域边界重构：`source_freshness`、`routing`、`evidence`、`release`、`campaign`。不得仅机械拆文件。

### 5.7 Agent 契约化

Agent 文档应区分：

- 稳定职责和权限边界
- 可验证输入输出合同
- 示例性、领域性经验参数

固定 CPU/内存比例、稳态时长、soak 时长，或“单体到微服务再到事件驱动”等内容只能作为可覆盖 playbook 示例，不能成为通用 core invariant。

建议每个 Agent 声明：

- `role_contract`
- `input_schema`
- `output_schema`
- `permission_envelope`
- `tool_capabilities`
- `decision_authority`
- `handoff_contract`
- `required_evidence`
- `assumption_scope`
- `evaluation_suite`

只有形成独立权限、上下文、工具或评价边界的角色才应成为新 Agent。

### 5.8 MCP、Hook、Plugin 和 Automation

MCP 当前 2026-07-28 governance-only 策略合理：

- stateless core
- auth hardening
- schema/transport/negative boundary
- legacy rollback
- `active_runtime_enabled=false`
- Tasks、Apps、extensions 默认 false

继续保持默认无 MCP。只有真实外部数据/动作需求才启用，并为每个 server/tool 声明 transport、auth、scope、read/write/destructive、deny-path、rate limit、idempotency 和 data classification。

Hook 当前已有事件、输出字段、并发风险、side-effect policy、deny-path 和 `hooks: {}` 默认关闭合同。未来若一等资产化，必须：

- deterministic、短超时、幂等
- 明确 fail-open/fail-closed
- side effect 与 approval 分级
- 不保存 prompt/secret
- 可禁用、可回滚、可追踪
- 不用 Hook 代替 Workflow engine

Plugin/Automation 先保持 candidate package 和 external handoff，不默认安装、调度或写运行目录。

### 5.9 Evidence Graph

建议把文件式证据连接为内容寻址图：

```text
source revision
  → decision
  → asset version
  → compiled bundle hash
  → runtime target/version
  → execution trace
  → evaluation outcome
  → release/rollback
  → retirement decision
```

每个节点记录 owner、verified_at、expires_at、content hash、environment、evidence layer、sensitivity、superseded_by 和 retention policy。

OpenTelemetry GenAI 继续作为可选、版本锁定 adapter；ADK native evidence 保持 SSOT。外部语义约定快速变化时不得直接覆盖本地稳定合同。

## 6. 分阶段路线图

### P0：恢复可信基线并停止横向扩张

1. 刷新或重新分级 28 条过期官方来源。
2. 固化默认 Python 3.11/3.12 开发环境。
3. 统一 routing IR，增加组合否定和 abstain 回归。
4. 将嵌入式资产移出 core。
5. 给 Runtime Control 增加 task-mode artifact applicability。
6. 修复规则文档悬空引用。

验收：支持 Python 下 strict validate 通过；三条已知路由反例不再误命中；core 不含嵌入式专属资产。

### P1：统一 IR、Adapter 和遥测

1. 实现 asset graph / workflow IR。
2. 建立 runtime adapter SPI。
3. 选择一个 native target 完成 discovery/load/trigger/rollback conformance。
4. 建立统一 run/trace/eval schema。
5. 将 Hook、Plugin、Automation 建为 candidate-only 一等资产类型。
6. 将大型 shell 逻辑迁入 typed core。
7. 为 Agent/Skill/Profile 增加使用率、误路由和 outcome 指标。

验收：同一 IR 可渲染至少两个 target；trace 能关联 asset bundle、runtime、tool、成本、结果和人工介入；默认权限不扩大。

### P2：真实运行和现场证明

1. 完成至少两个 runtime 的 baseline/ADK 对照 campaign。
2. 在独立真实仓库完成不少于 30 天 pilot。
3. 至少两位操作者实际贡献事件。
4. 覆盖 upgrade、rollback、fault、recovery、maintenance、review。
5. 根据真实结果合并或退役低价值 Agent/Skill/Profile。
6. 再判断是否需要 durable execution backend。

验收沿用现有 Software M5 policy；fixture、自试点和静态报告不得替代独立 field evidence。

## 7. 明确不采纳项

- 不把 ADK 重做成 LangGraph、Temporal、AutoGen 或 Google ADK。
- 不把所有 runbook 都转成 Skill 或 Workflow。
- 不因为协议支持就默认启用 MCP、Hook、Plugin 或 Tasks。
- 不同时推进全部 runtime 原生支持；先完成一个完整 conformance。
- 不新增与现有 manifest/report 平行的 SSOT。
- 不以总分掩盖 P0 短板。
- 不以更多 Agent、Skill、报告或状态字段表示成熟度提升。
- 不把 LLM 分类直接作为执行授权。

## 8. 风险和开放项

1. 官方来源集中到期导致 strict validate 和根 quick gate 当前失败。
2. 默认 Python 3.8.10 与声明的 Python 3.11+ 不一致。
3. 当前 synthetic eval 对已有规则拟合良好，但组合否定和真实多轮覆盖不足。
4. core 与 embedded profile 边界仍有历史混入。
5. Hook/Plugin/MCP 合同存在不代表运行态已启用或已验证。
6. 真实 native runtime、远端 CI/attestation、第二操作者、独立仓和 30 天 field evidence仍未闭环。
7. 报告数量接近 warning limit，新增长期材料需要 supersession/retention 决策。
8. 通用 Runtime Control final gate 对只读评估仍要求 implementation build/repo artifact，适用性模型需补强。

## 9. 外部来源与版权边界

以下仅用于方法和架构对照，不复制外部正文或代码：

| 来源 | URL | Retrieved at | 使用边界 |
|---|---|---|---|
| OpenAI Harness Engineering | <https://openai.com/index/harness-engineering/> | 2026-08-30 | 仓库知识、渐进披露、机械门禁和 entropy control |
| OpenAI Codex App Server | <https://openai.com/index/unlocking-the-codex-harness/> | 2026-08-30 | harness、thread、tool 和 client protocol 分层 |
| OpenAI Symphony | <https://github.com/openai/symphony/blob/main/SPEC.md> | 2026-08-30 | scheduler、workspace、workflow 和 agent protocol 边界 |
| MCP 2026-07-28 | <https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/blog/content/posts/2026-07-28-spec-ga/index.md> | 2026-08-30 | stateless core、extension、cache、auth 和 deprecation |
| OpenTelemetry GenAI | <https://github.com/open-telemetry/semantic-conventions-genai> | 2026-08-30 | trace/eval/MCP 可选适配器 |
| Temporal | <https://docs.temporal.io/> | 2026-08-30 | replay、activity、retry、idempotency 语义 |
| Microsoft Agent Framework | <https://learn.microsoft.com/en-us/agent-framework/workflows/checkpoints> | 2026-08-30 | checkpoint、resume 和 storage provider 边界 |
| PydanticAI Durable Execution | <https://pydantic.dev/docs/ai/capabilities/durable_execution/overview/> | 2026-08-30 | typed durable adapter 和 HITL |
| Google ADK Evaluation | <https://github.com/google/adk-docs/blob/main/docs/evaluate/index.md> | 2026-08-30 | session/multi-turn evaluation |

本报告不引入外部运行依赖，不复制第三方实现，不代表许可证、兼容性或生产采用决定。

## 10. 归档候选结论

- Archive Candidate Path：`reports/llm-agent-adk-comprehensive-design-assessment-2026-08-30.md`
- Reusable value：用于后续架构评审、P0/P1/P2 任务拆解、路由/Profile/Workflow 重构和真实 runtime campaign 设计
- Memory Candidate：`no`；仓库报告已是当前来源，不静默写 memory
- Promotion Candidate：`no`；建议尚未经过 owner review，也未写入机器 backlog 或 current architecture SSOT
- Supersedes：`none`；本报告为补充评估，不覆盖 `reports/architecture/` current report
- Product Gate Result：`needs-fix`；当前 strict/quick gate 存在官方来源 freshness blocker
- Archive Gate Target：文档同步、Token/维护性预算、repo quality 和 diff check
