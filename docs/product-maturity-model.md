# 产品成熟度模型

`llm_agent` 与 `agent-dev-kit` 的目标是成熟的 Agent 资产平台与参考实践吸收工作区，不是通用 LLM/Agent runtime。成熟度判断必须覆盖产品目标、架构、功能、效果、性能、安全、发布、维护、扩展、体验和长期资产，不能只看治理闭环数量。

## 产品边界

### `llm_agent`

- 负责参考源注册、不可变快照分析、结构化决策候选、跨仓证据聚合和 ADK 落地编排。
- 不直接运行外部参考仓代码，不从 dirty 工作树吸收内容，不自动修改 ADK。
- 不以报告数量或矩阵条目数量作为产品效果证明。

### `agent-dev-kit`

- 负责 Agent、Skill、Workflow、Profile 和治理契约的结构化建模、解析、导出、安装、验证、评测与发布。
- 是平台中立的资产编译与交付控制面，不包含 LLM 推理循环、会话调度器或生产 Agent runtime。
- Codex 是 external source-to-live handoff，不是 direct export target；Claude Code、Hermes Agent、OpenCode 是 direct targets。

## M0-M5 等级

| Level | 名称 | 判定 |
|---|---|---|
| M0 | Absent | 能力不存在，或只有不可执行描述。 |
| M1 | Implicit | 有零散脚本/经验，但无 SSOT、稳定接口或失败语义。 |
| M2 | Designed | 目标、契约、边界和验收已设计，尚未形成端到端实现证据。 |
| M3 | Implemented | 核心路径已实现并有定向测试；仍缺发布、真实运行效果或长期运行证据。 |
| M4 | Release-ready | 接口、回滚、安全、性能、CI、回归和发布制品均有可重复证据，无未处置 blocker。 |
| M5 | Field-proven | 至少一个代表性真实环境持续运行，效果、故障、升级、回滚和维护成本都有经过复核的现场证据。 |

单个维度可以达到 M4；产品整体等级取关键维度短板，不做简单平均。没有现场证据时不得声称 M5。

### 实现等级、证据等级与有效等级

每个维度同时记录三个不同语义的等级：

- `implementation_level`：代码和本地控制面已实现到的最高等级。
- `evidence_level`：已有 source/test/runtime/field 证据可支持的最高等级，且不得高于实现等级。
- `effective_level`：前两者的较低值，是对外成熟度声明和整体短板计算的唯一依据。兼容字段 `level` 仅保留为实现侧投影，不得替代 `effective_level`。

状态必须与等级差距一致：`verified` 只允许用于实现等级与证据等级相等且当前有效等级无开放证据缺口的维度；`verified_local` 表示本地证据已支持有效等级，但仍有明确的远端、runtime、operator 或 field 缺口；`partially_verified` 表示已有部分证据，但进入下一层所需证据尚不完整。实现等级高于证据等级时禁止标记为 `verified`。

### 软件侧 M5-ready 与 M5 certified

`M5-ready` 是 M4 之后的认证准备状态，不是新的成熟度等级。它要求软件控制面已经具备可执行的 campaign、writer lock、升级回退、现场账本、append-only hash chain、预算门禁和 fail-closed certifier。它不允许把自测、fixture 或本地 rehearsal 当作最终现场证明。

软件侧 `M5 certified` 还必须同时满足：

- 至少 60 个任务、Codex/Claude 两个 runtime、baseline/adk 两个条件和 3 次 trial 的认证 campaign 通过；模型、CLI、成本、latency、token、结果 hash 与置信门禁完整。
- 至少两个有真实 field 事件的软件仓，其中至少一个是独立于本产品的真实仓。
- 至少两个 human operator 实际贡献现场事件，不能只在 ledger 中声明身份。
- 至少一个 independent pilot 的 ledger 跨度和事件观测跨度都达到 30 天。
- 同一 independent pilot 覆盖 workload、upgrade、rollback、fault、recovery、maintenance 和 review，并满足结构化 metric 契约。
- RC 先达到 `eligible-for-final`，随后只做必要版本提升、完整回归和最终 `3.1.0` 制品验证；不得先发布 final 再补现场证据。

权威策略、账本和入口分别是 `manifests/software_m5_policy.json`、`manifests/software_m5_pilot_ledger.json` 和 `scripts/software-m5.sh`。自试点启动后可使用 `field_status=self_pilot_active`，但在独立试点认证前必须保持 `terminal_mature=false`。

## 四层证据

| Layer | 含义 | 可接受证据 | 不可替代项 |
|---|---|---|---|
| source | 设计和实现存在 | 代码、schema、manifest、runbook、change artifact、diff | 不能证明行为正确 |
| test | 可重复契约成立 | 单元/集成/负向/回归/CI 结果 | 不能证明真实 runtime 效果 |
| runtime | 真实命令或模型运行成立 | 安装/回滚、制品构建、Codex/Claude 对照评测、source-to-live dry-run/apply | 不能证明长期现场稳定 |
| field | 真实项目与运维周期成立 | 设备/团队试点、故障与回滚记录、版本升级、人工成本和效果趋势 | 模拟 pilot、fixture、静态报告均不能替代 |

`status=verified` 必须带证据路径或可重放命令；无法执行时使用 scorecard 允许的未完成状态并写明 gap，不得用 `pass` 表示未执行。

## 十二个成熟度维度

1. **目标与产品边界**：用户、问题、非目标、成功标准和停止条件一致。
2. **架构与契约**：模块职责、数据模型、SSOT、接口和错误语义稳定。
3. **功能完整性**：发现、分析、决策、编译、导出、安装、回滚、评测、发布均有真实实现。
4. **结果有效性**：使用 ADK 相比 baseline 的路由、质量、安全或效率有可复核提升。
5. **可靠性与验证**：负向测试、回归、确定性、CI 和失败恢复覆盖关键路径。
6. **性能与成本**：平台自身时延、测试耗时、输出体积和模型调用成本有预算与基线。
7. **安全与供应链**：路径、symlink、凭证、权限、外部动作和依赖 pin 有阻断门禁。
8. **发布与回滚**：版本、制品、checksum、SBOM、backend、安装 receipt 和回滚都可重放。
9. **可维护性**：公共 CLI 收敛、重复脚本受控、文档与代码一致、状态可生成。
10. **扩展与兼容**：新增 target/profile/source 有显式 adapter、候选期、契约测试和 Major 策略。
11. **操作与开发体验**：帮助、错误、summary JSON、dry-run、非仓库 cwd 入口和审查产物清晰。
12. **长期资产与现场证据**：高价值结论可治理，过期/替代关系清楚，真实试点不被模拟证据冒充。

## 终态门禁

产品只有同时满足以下条件才可标记 `terminal_mature`：

- P0 维度全部达到 M4，且无 blocker 或未审查的自动外部写路径。
- deterministic eval、安装回滚、release build 和全量回归可重复通过。
- 至少两个真实 runtime 的 ADK/baseline 对照结果可复核，失败不会被吞掉。
- direct target 与 external handoff 边界没有漂移。
- 关键 action 固定 SHA，安全扫描没有未处置失败。
- 现场相关声明有 field evidence；没有现场证据时必须保留 `field_not_verified`。

M4 可用于发布资产平台；M5 只能用于明确完成真实试点的维度。当前权威状态由 `manifests/product_maturity_scorecard.json` 给出。

## 状态更新规则

- 先更新证据，再更新 scorecard，不允许反向补证据。
- 设计完成与实现完成分开记录；命令存在但返回占位成功不算实现。
- 每个 `verified` 状态至少关联 source/test/runtime 中适用的两层证据，且 `implementation_level == evidence_level == effective_level`。
- field gate 只在有真实设备、团队或发布记录时改变；模拟测试永远保持 `field_not_verified`。
- 当前任务和剩余门禁进入 `manifests/product_maturity_task_pack.json`，一次性过程不写入长期规则。
- 软件 M5 事件只能追加，修改历史行会破坏 hash chain 并触发阻断；operator 只保存匿名稳定 ID，不保存姓名、邮箱或凭证。
