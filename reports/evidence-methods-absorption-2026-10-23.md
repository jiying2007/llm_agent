# 2026-10-23 外部方法吸收与生产投影更正

## 范围与实际来源

本报告承接 Owner“全面吸收，全面优化，落地闭环”的授权，对十二项来源分别说明实际落点和限制。来源 URL、固定 revision 或内容摘要、许可证未知项、采集范围保存在 `docs/changes/20261023-evidence-methods/sources.json`；原始十二条 candidate、独立 decision 和 9 ENHANCE / 3 OBSERVE 决定保持不变。

本轮代码增强已随 ADK 8.0.39 发布，精确来源为 `415590db44e88979185efb850e2339a3f95411ef`，tree 为 `51d400e80ba555a49ca85fcfefbd74f7fe499072`。发布证据为 [PR #220](https://github.com/jiying2007/agent-dev-kit/pull/220)、[实际 main CI](https://github.com/jiying2007/agent-dev-kit/actions/runs/39955902743) 和 [v8.0.39](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.39)。Root 接入的原始签名材料在 `reports/promotion/agent-dev-kit/`；组件发布不授予 Native、G22、现场或 Product M5 资格。

第三方材料只作为方法输入，没有复制、安装或执行第三方资产。下述生产映射复用本仓已有实现和职责，没有新增 Agent、Skill、Workflow、评估框架或收费服务。

## 四项实际生产承接

### EXT-06：按完整责任复用既有模块

适用于 Native 多文档输出和公开 release publish 的重复责任。`agent-dev-kit/src/agent_dev_kit/native_campaign.py` 通过 `agent-dev-kit/src/agent_dev_kit/atomic_io.py` 承担统一输出校验、staging 和补偿；`agent-dev-kit/src/agent_dev_kit/release.py` 复用 `agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 的 canonical verifier。

该增强由 `agent-dev-kit/agents/architecture-planner/AGENTS.md` 的责任划分、`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md` 的调用者合同和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md` 的验证与发布职责承接。具体改动和独立审核在 `agent-dev-kit/docs/changes/20261023-output-boundaries/` 与 `agent-dev-kit/docs/changes/20261023-release-contract/`。确定性反例覆盖调用者正常输出、重复/别名输出、后项写入失败和发布合同不一致。

适用收益是统一实际责任与错误处理；不以文件数、模块行数或假设的 token 节省证明生产效率改善。Root 的 process_budget 复用仍在原实现映射中，不伪装成 ADK 新资产。

### EXT-08：在实际失败路径上保证可恢复

`agent-dev-kit/src/agent_dev_kit/native_campaign_contract.py` 与 `agent-dev-kit/src/agent_dev_kit/atomic_io.py` 在写入前校验全集合的输出类型、别名和输入冲突，完成编码及 staging 后再发布；失败时补偿已替换项目，恢复失败则保留恢复材料。`agent-dev-kit/src/agent_dev_kit/compiler.py` 在 export 使用 writer lock，并在获得锁后复核原始路径身份。

既有承接职责为 `agent-dev-kit/agents/architecture-planner/AGENTS.md`、`agent-dev-kit/skills/adk-interface-contract-design/references/lifecycle-operation-contract.md`、`agent-dev-kit/skills/adk-interface-contract-design/references/tool-effect-contract.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。代码及真实反例见 `agent-dev-kit/docs/changes/20261023-output-boundaries/`。

这证明已观察到的文件操作失败可以按合同处理；跨文件补偿不等于任意断电点的崩溃原子性，也不证明远端 API exactly-once。远端未知结果仍按已有发布流程读回后决定是否重试。

### EXT-09：来源数据与发布权威分别核验

本次生产增强限定为 release 来源完整性：`agent-dev-kit/src/agent_dev_kit/distribution/release_artifacts.py` 从冻结 Git tree 读取并验证 blob；`agent-dev-kit/src/agent_dev_kit/distribution/archive_io.py` 有界扫描完整 source inventory；`agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 对照 source 数量、摘要和嵌入 manifest。ignored、index 隐藏漂移、Git attributes、重复成员、路径或类型冲突不能仅凭表面 clean 状态进入合格资产。

既有职责为 `agent-dev-kit/agents/security-compliance-reviewer/AGENTS.md`、`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。实现与审核见 `agent-dev-kit/docs/changes/20261023-release-contract/`。不可信日志、外部标题和回执不能替代精确来源、签名主体与发行权威。

本报告不声称新增了通用 prompt-injection 防护或验证了所有模型安全行为；OpenAI 平台本身未被引入。方法来源与实际控制的覆盖范围保持分开。

### EXT-11：完整发布集合与同字节验证

`agent-dev-kit/src/agent_dev_kit/release.py` 的公开 publish 对 captured archive snapshot 进行 canonical verification，并使用同一份已验证字节形成 tar、checksum 和 release-contract 三资产；dry-run 不写输出。`agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 仍是实际合同 owner，改名版本、source 漂移和异常 tar 会被原验证器拒绝。

既有职责为 `agent-dev-kit/agents/build-release-engineer/AGENTS.md`、`agent-dev-kit/skills/adk-release-versioning/SKILL.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。实现、测试和独立审核见 `agent-dev-kit/docs/changes/20261023-release-contract/`。实际 GitHub immutable 状态、签名和主线执行由上列发布及 CI 记录分别证明，不由本报告或 release 标题推断。

这些 Agent/Skill/Workflow 路径说明既有职责承接关系，不是新生成的执行回执，也不声明每个 Workflow 步骤在本次独立运行。实际执行只以原始测试、review、CI 和发布证据为准。

## 五项研究与验收方法

以下 ENHANCE 决定保留在原 ledger 和 `docs/changes/20261023-evidence-methods/implementation-map.md`，操作说明进入 `docs/runbooks/evidence-driven-optimization.md`。它们用于本轮问题定义与验收，不登记为新生产 intake package。

| 来源 | 本轮实际采用 | 适用边界与后续验证 |
|---|---|---|
| EXT-01 OpenAI Skill evals | 分开记录路由、执行、正确产物与真实效果；用原失败和正常对照验收缺陷 | 没有重新认证全部 Skill；真实效果沿原 effect campaign 采样 |
| EXT-03 Anthropic evals | 以最终文件、退出码、进程和发布状态验收，保留失败与重试分母 | 测试通过不增加 Native、G22 或产品资格；真实 campaign 仍需实际任务 |
| EXT-04 Anthropic harness | 根据共享边界风险选择独立审查与回归，对局部反馈只补相应验证 | 本轮没有逐个证明所有 harness 组件的净收益，后续消融需固定输入与预算 |
| EXT-05 Addy Skill evals | 分开解释结构校验、词法路由近似、执行成功与行为效果 | 没有新 catalog 或 runner；组件有无对照须使用真实任务且保留完整分母 |
| EXT-07 Cursor benchmark | 先确认实际工作与产物；缓存反例暴露九项生产缓存输入不完整并禁用 | 只确认正确性修复，没有端到端效率、模型成本或人工时间改善的测量结论 |

## 三项选型观察与重新进入条件

这三项保持原 OBSERVE decision；未建立生产 observe intake package，因此不出现在生产 adoption matrix。以后需要生产吸收时仍须完成原 Agent/Skill/Workflow 深度、报告、合法性和运行证据要求。

| 来源 | 当前观察结论 | 重新进入评审的条件 |
|---|---|---|
| EXT-02 OpenAI deprecations | 在 sources.json 指定静态扫描面未发现活跃托管 Evals / Agent Builder 调用，作为选型约束 | 发现真实活跃调用或平台边界变更时，核对当前官方状态、实际调用者及迁移需求；未扫描的外部部署保持未知 |
| EXT-10 LangGraph checkpointers | 复用关于 checkpoint、重放与外部副作用的语义分析，没有引入框架 | 真实故障证明现有恢复 owner 无法满足需求，并有可比较收益、维护成本与副作用控制证据时再评审 |
| EXT-12 GitHub workflow lockfiles | 继续已有 full SHA pin；按已核来源保持 Enterprise Cloud 公开预览观察 | 重新核实官方状态、确认已具备资格且零新增费用，再进行限定工作流兼容性试验；当前没有升级或购买动作 |

## 发现、纠正与关闭要求

工作树 quick 检查发现，原十二条生产矩阵行全部使用 `llm_agent + done`。既有 reference lifecycle 只在真实 reference-repository onboarding 时允许 Root 作为该生产目标；九项 adopt 不满足生产目标及本地证据要求，三项 observe 也没有生产 intake 所需的深度包。原矩阵尾注不能重新定义 done。

本次修正只把四项真实 ADK 代码增强投影到生产矩阵，其余八项完整保留在原 candidate/decision/map。原 `docs/changes/20261023-evidence-methods/review-evidence.json`、requirements/design/tasks 和执行日志保持历史原件；前次方法审核遗漏上述两个 gate，历史 PASS 不继承为本次更正验收。

更正后的独立复审须绑定本报告、矩阵 Markdown/JSONL、implementation map、runbook 和 removal fixture 的新摘要，并实际运行以下原始入口：

- `rtk bash scripts/check-upstream-intake-readiness.sh .`
- `rtk bash scripts/check-observe-intake-depth.sh .`
- `rtk bash scripts/check-adoption-matrix-structured.sh .`
- `rtk bash scripts/check-adoption-matrix-status.sh .`
- `rtk bash scripts/check-adoption-evidence-integrity.sh .`
- `rtk bash scripts/check-adoption-real-assets.sh . --summary-json`
- `rtk bash tests/test_reference_repository_removal.sh`

矩阵 JSONL 由原 exporter 生成，removal pass fixture 的 adoption_decision 摘要由原 planner 计算；不改变门禁或测试断言。新提交的全量回归、受保护 PR CI 与实际 main CI 独立留证。本报告不预填尚未运行的更正后结果。

当前缺少本机声明运行环境、过期 dirty baseline 及旧 M5 资格的门禁结果仍依其原权威报告，不能用本次矩阵修正、ADK 发布或 PR CI 绿色消除。复审时间沿原变更节奏或 2026-11-22 之前进行；该日期不表示创建了自动任务。
