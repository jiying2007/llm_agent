# 来源到实际实现与验收

本映射按 Owner 的明确吸收指令建立。十二项来源的原始 URL、固定 revision、未知许可证和静态依赖审查保存在 sources.json；collector 只生成 review-required candidate，独立 decision 保存在 decisions.jsonl。第三方内容没有复制到生产资产。

## 决策与生产投影

十二项来源和九项 ENHANCE、三项 OBSERVE 的原始决定全部保留。生产采纳表只登记 EXT-06、EXT-08、EXT-09、EXT-11 在 ADK 8.0.39 的实际代码承接；EXT-01、EXT-03、EXT-04、EXT-05、EXT-07 是本轮研究与验收方法，EXT-02、EXT-10、EXT-12 是选型观察，分别通过本映射、runbook 和原 decision ledger 留存。后八项没有新增生产 Agent/Skill/Workflow intake package，也不声明生产 intake 已完成。

此前将十二项统一投影为 `llm_agent + done` 与既有 reference lifecycle 合同不符。原 `review-evidence.json` 和执行日志保留为当时文件快照的审查历史；该审查遗漏了 upstream-intake-readiness 与 observe-intake-depth 两个入口，不能作为更正后矩阵的验收。原矩阵修正的实际七项门禁结果及六文件快照保存在 `review-projection-correction.json`，对应远端提交 `64c5192f2d6aaacf65143223f03190564032facc`。随后完整回归发现新增根 reports 文档使严格维护预算失败。其分析已合并到本文件的生产承接章节；最新来源与维护预算修复须由新的 `review-consolidation.json` 复核，历史审核不迁移为当前文件绑定。

## 方法映射

| 来源 | 决策 | 既有 owner 与实际落点 | 验收依据 | 保留的限制 |
|---|---|---|---|---|
| EXT-01 OpenAI Skill evals | ENHANCE | evidence-driven-optimization 第 1/4 节；现有 ADK effect/repository campaign | 三组缺陷均保留原失败、修复结果和正常控制；执行完成与实际效果分开 | 未重新全量认证 Skill；没有真实模型收益测量 |
| EXT-02 OpenAI deprecations | OBSERVE | runbook 第 6 节；sources.json dependency_audit | 指定执行面静态搜索没有发现活跃调用，原匹配逐项分类 | 仅在已读两仓范围成立；不是生产外部配置的全面证明 |
| EXT-03 Anthropic evals | ENHANCE | runbook 第 1/3/4 节；现有 G21/G22/M5 证据合同 | 使用真实可观察文件、退出、进程和产物结果；保留失败分母 | fixture pass 不提高 Native、效果或产品资格 |
| EXT-04 Anthropic harness | ENHANCE | runbook 第 2/3 节；现有 validation-plan | 有风险的共享边界全回归；小范围审查反馈只做必要回归再整合 | 本轮没有证明所有既有 harness 组件的净收益 |
| EXT-05 Addy Skill evals | ENHANCE | runbook 第 1/3 节；既有 matcher 与 effect 流程 | 明确结构、词法路由、运行成功和效果的不同解释 | 没有新增 catalog、runner 或付费 CI |
| EXT-06 Matt Codebase Design | ENHANCE | ADK atomic_io/release_contract；Root process_budget | Native 重复输出写入收敛到既有 atomic_io；Gate 复用 bounded runner；publish 复用 canonical verifier | 模块行数和文件数量不充当收益分数 |
| EXT-07 Cursor benchmark | ENHANCE | runbook 第 4 节；现有 effect-trial 比较 | 缓存反例证实 HEAD 不足以代表全部输入；九项生产缓存禁用 | 没有把快速失败、no-op 或局部时长包装成效率改善 |
| EXT-08 Cursor idempotence | ENHANCE | ADK compiler/native_campaign/atomic_io；现有 release/promotion | 全输出预检、staging、补偿和保留恢复材料的确定性回归；远端写入前后按精确标识读回 | 单文件替换及多文件补偿不等于任意中断点的跨系统事务 |
| EXT-09 OpenAI safety | ENHANCE | runbook 第 6 节；ADK release_artifacts/archive_io/release_contract | 固定 Git commit/tree/blob 来源、完整 source digest 与发布权威分别校验 | 生产投影仅覆盖实际 release 来源完整性控制；没有新增通用 prompt-injection 防护或引入 Agent Builder |
| EXT-10 LangGraph | OBSERVE | runbook 第 5 节；现有恢复 owner | 明确 checkpoint、重放、观察到的失败补偿和崩溃窗口 | 没有引入 LangGraph；没有 exactly-once 声明 |
| EXT-11 GitHub immutable release | ENHANCE | ADK release_artifacts/archive_io/release_contract；Root adk_promotion | 固定 Git 来源、完整 source 摘要、同字节三资产验证；真实远端闭环另由发布记录证明 | local pass 不能代替签名、immutable 状态或产品资格 |
| EXT-12 GitHub lockfiles | OBSERVE | runbook 第 6 节；既有 SHA-pinned workflow | 保留 Enterprise Cloud/公开预览/零新增费用边界 | 未采用不构成缺陷；没有升级计划或第二套依赖权威 |

## 审查缺陷与代码变更追溯

| 缺陷 | 代码 owner | 需求与可复验依据 |
|---|---|---|
| ADK-01 ignored 或 index 隐藏漂移污染合格构建 | distribution/release_artifacts | agent-dev-kit/docs/changes/20261023-release-contract；固定 tree/blob、Git attributes、replace refs 和 mode 回归 |
| ADK-02 公开 publish 与正式发布合同不一致 | release / distribution/release_contract | 同变更；改名版本拒绝、三资产集合、上传字节快照和 dry-run 反例 |
| ADK-03 tar 内 source 漂移未完整核验 | distribution/archive_io | 同变更；source count/digest/embedded manifest、重复和异常成员、有界读取 |
| ADK-04 Native 多输出互相覆盖 | native_campaign_contract / atomic_io | agent-dev-kit/docs/changes/20261023-output-boundaries；相同路径、硬链接、输入输出别名、父子重叠 |
| ADK-05 Native 晚发失败与非普通文件 | native_campaign / atomic_io | 同变更；执行前预检、编码/staging 失败不触碰目标、后项失败恢复、恢复失败保留备份 |
| ADK-06 export 同根链接清理错误目录 | compiler / installation_contract | 同变更；原始路径和 inode 检查、writer lock、同根及根外 no-clobber 反例 |
| ROOT-R1 Git 路径错误与无效比较 | control_plane/impact | docs/changes/20261023-gate-correctness；NUL/UTF-8/rename/raw path 和公共 CLI 空 base 回归 |
| ROOT-R2 后代进程晚写与无界输出 | control_plane/gate_runner / process_budget | 同变更；真实进程组 timeout、stdout/stderr 预算及正常退出控制 |
| ROOT-R3 不完整输入缓存旧 PASS | control_plane/gate_runner / manifests/gates.json | 同变更；实际 production 图同 HEAD 暂存区变化反例，纯 fixture 缓存保留 |
| METHODS-REVIEW-01 GitHub 文件来源归属错误 | codex_assets/practice_intake | 本变更；通过 collector 修复后重生 ledger，保持完整 URL、revision、candidate/decision 关联 |

路径为仓库相对路径。ADK 已发布的精确主线为 `415590db44e88979185efb850e2339a3f95411ef`，版本 8.0.39；Root 的 `adk.lock` 与子模块指向该来源。真实发布及主线 CI 分别见 [v8.0.39](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.39) 和 [main CI 39955902743](https://github.com/jiying2007/agent-dev-kit/actions/runs/39955902743)。Root 更正后提交、独立复审和受保护 CI 仍以对应的新鲜记录为准。

## 关闭条件

采纳表的 done 遵循既有生产 intake 合同，不能由尾注重定义为“方法已经讨论”。本轮四项生产投影须指向真实 ADK 代码及本 change 的分析，其余八项在原 ledger 中保持可追溯。代码问题须具有独立 Spec/Quality 审查和新鲜回归，组件交付须有受保护 PR、精确主线 CI、immutable 三资产和 Root pin 的读回。缺真实 Native receipts、G22 trials、LTA field events 或当前 Product M5 authority 时继续由原检查器返回 blocked/conditional；本映射不生成它们。

本轮没有实际调用收费模型，也没有新增外部评估框架。现有 Native executor 的 asyncio transport 清理告警已在输出变更中保留为独立未关闭事项，不能用输出写入修复覆盖该观察。

## 生产承接与适用边界

### 范围与实际来源

本分析承接 Owner“全面吸收，全面优化，落地闭环”的授权，对十二项来源分别说明实际落点和限制。来源 URL、固定 revision 或内容摘要、许可证未知项、采集范围保存在 `docs/changes/20261023-evidence-methods/sources.json`；原始十二条 candidate、独立 decision 和 9 ENHANCE / 3 OBSERVE 决定保持不变。

本轮代码增强已随 ADK 8.0.39 发布，精确来源为 `415590db44e88979185efb850e2339a3f95411ef`，tree 为 `51d400e80ba555a49ca85fcfefbd74f7fe499072`。发布证据为 [PR #220](https://github.com/jiying2007/agent-dev-kit/pull/220)、[实际 main CI](https://github.com/jiying2007/agent-dev-kit/actions/runs/39955902743) 和 [v8.0.39](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.39)。Root 接入的原始签名材料在 `reports/promotion/agent-dev-kit/`；组件发布不授予 Native、G22、现场或 Product M5 资格。

第三方材料只作为方法输入，没有复制、安装或执行第三方资产。下述生产映射复用本仓已有实现和职责，没有新增 Agent、Skill、Workflow、评估框架或收费服务。

### 四项实际生产承接

#### EXT-06：按完整责任复用既有模块

适用于 Native 多文档输出和公开 release publish 的重复责任。`agent-dev-kit/src/agent_dev_kit/native_campaign.py` 通过 `agent-dev-kit/src/agent_dev_kit/atomic_io.py` 承担统一输出校验、staging 和补偿；`agent-dev-kit/src/agent_dev_kit/release.py` 复用 `agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 的 canonical verifier。

该增强由 `agent-dev-kit/agents/architecture-planner/AGENTS.md` 的责任划分、`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md` 的调用者合同和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md` 的验证与发布职责承接。具体改动和独立审核在 `agent-dev-kit/docs/changes/20261023-output-boundaries/` 与 `agent-dev-kit/docs/changes/20261023-release-contract/`。确定性反例覆盖调用者正常输出、重复/别名输出、后项写入失败和发布合同不一致。

适用收益是统一实际责任与错误处理；不以文件数、模块行数或假设的 token 节省证明生产效率改善。Root 的 process_budget 复用仍在原实现映射中，不伪装成 ADK 新资产。

#### EXT-08：在实际失败路径上保证可恢复

`agent-dev-kit/src/agent_dev_kit/native_campaign_contract.py` 与 `agent-dev-kit/src/agent_dev_kit/atomic_io.py` 在写入前校验全集合的输出类型、别名和输入冲突，完成编码及 staging 后再发布；失败时补偿已替换项目，恢复失败则保留恢复材料。`agent-dev-kit/src/agent_dev_kit/compiler.py` 在 export 使用 writer lock，并在获得锁后复核原始路径身份。

既有承接职责为 `agent-dev-kit/agents/architecture-planner/AGENTS.md`、`agent-dev-kit/skills/adk-interface-contract-design/references/lifecycle-operation-contract.md`、`agent-dev-kit/skills/adk-interface-contract-design/references/tool-effect-contract.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。代码及真实反例见 `agent-dev-kit/docs/changes/20261023-output-boundaries/`。

这证明已观察到的文件操作失败可以按合同处理；跨文件补偿不等于任意断电点的崩溃原子性，也不证明远端 API exactly-once。远端未知结果仍按已有发布流程读回后决定是否重试。

#### EXT-09：来源数据与发布权威分别核验

本次生产增强限定为 release 来源完整性：`agent-dev-kit/src/agent_dev_kit/distribution/release_artifacts.py` 从冻结 Git tree 读取并验证 blob；`agent-dev-kit/src/agent_dev_kit/distribution/archive_io.py` 有界扫描完整 source inventory；`agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 对照 source 数量、摘要和嵌入 manifest。ignored、index 隐藏漂移、Git attributes、重复成员、路径或类型冲突不能仅凭表面 clean 状态进入合格资产。

既有职责为 `agent-dev-kit/agents/security-compliance-reviewer/AGENTS.md`、`agent-dev-kit/skills/adk-interface-contract-design/SKILL.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。实现与审核见 `agent-dev-kit/docs/changes/20261023-release-contract/`。不可信日志、外部标题和回执不能替代精确来源、签名主体与发行权威。

本分析不声称新增了通用 prompt-injection 防护或验证了所有模型安全行为；OpenAI 平台本身未被引入。方法来源与实际控制的覆盖范围保持分开。

#### EXT-11：完整发布集合与同字节验证

`agent-dev-kit/src/agent_dev_kit/release.py` 的公开 publish 对 captured archive snapshot 进行 canonical verification，并使用同一份已验证字节形成 tar、checksum 和 release-contract 三资产；dry-run 不写输出。`agent-dev-kit/src/agent_dev_kit/distribution/release_contract.py` 仍是实际合同 owner，改名版本、source 漂移和异常 tar 会被原验证器拒绝。

既有职责为 `agent-dev-kit/agents/build-release-engineer/AGENTS.md`、`agent-dev-kit/skills/adk-release-versioning/SKILL.md` 和 `agent-dev-kit/workflows/release-hardening/WORKFLOW.md`。实现、测试和独立审核见 `agent-dev-kit/docs/changes/20261023-release-contract/`。实际 GitHub immutable 状态、签名和主线执行由上列发布及 CI 记录分别证明，不由本报告或 release 标题推断。

这些 Agent/Skill/Workflow 路径说明既有职责承接关系，不是新生成的执行回执，也不声明每个 Workflow 步骤在本次独立运行。实际执行只以原始测试、review、CI 和发布证据为准。

### 五项研究与验收方法

以下 ENHANCE 决定保留在原 ledger 和 `docs/changes/20261023-evidence-methods/implementation-map.md`，操作说明进入 `docs/runbooks/evidence-driven-optimization.md`。它们用于本轮问题定义与验收，不登记为新生产 intake package。

| 来源 | 本轮实际采用 | 适用边界与后续验证 |
|---|---|---|
| EXT-01 OpenAI Skill evals | 分开记录路由、执行、正确产物与真实效果；用原失败和正常对照验收缺陷 | 没有重新认证全部 Skill；真实效果沿原 effect campaign 采样 |
| EXT-03 Anthropic evals | 以最终文件、退出码、进程和发布状态验收，保留失败与重试分母 | 测试通过不增加 Native、G22 或产品资格；真实 campaign 仍需实际任务 |
| EXT-04 Anthropic harness | 根据共享边界风险选择独立审查与回归，对局部反馈只补相应验证 | 本轮没有逐个证明所有 harness 组件的净收益，后续消融需固定输入与预算 |
| EXT-05 Addy Skill evals | 分开解释结构校验、词法路由近似、执行成功与行为效果 | 没有新 catalog 或 runner；组件有无对照须使用真实任务且保留完整分母 |
| EXT-07 Cursor benchmark | 先确认实际工作与产物；缓存反例暴露九项生产缓存输入不完整并禁用 | 只确认正确性修复，没有端到端效率、模型成本或人工时间改善的测量结论 |

### 三项选型观察与重新进入条件

这三项保持原 OBSERVE decision；未建立生产 observe intake package，因此不出现在生产 adoption matrix。以后需要生产吸收时仍须完成原 Agent/Skill/Workflow 深度、报告、合法性和运行证据要求。

| 来源 | 当前观察结论 | 重新进入评审的条件 |
|---|---|---|
| EXT-02 OpenAI deprecations | 在 sources.json 指定静态扫描面未发现活跃托管 Evals / Agent Builder 调用，作为选型约束 | 发现真实活跃调用或平台边界变更时，核对当前官方状态、实际调用者及迁移需求；未扫描的外部部署保持未知 |
| EXT-10 LangGraph checkpointers | 复用关于 checkpoint、重放与外部副作用的语义分析，没有引入框架 | 真实故障证明现有恢复 owner 无法满足需求，并有可比较收益、维护成本与副作用控制证据时再评审 |
| EXT-12 GitHub workflow lockfiles | 继续已有 full SHA pin；按已核来源保持 Enterprise Cloud 公开预览观察 | 重新核实官方状态、确认已具备资格且零新增费用，再进行限定工作流兼容性试验；当前没有升级或购买动作 |

### 发现、纠正与关闭要求

工作树 quick 检查发现，原十二条生产矩阵行全部使用 `llm_agent + done`。既有 reference lifecycle 只在真实 reference-repository onboarding 时允许 Root 作为该生产目标；九项 adopt 不满足生产目标及本地证据要求，三项 observe 也没有生产 intake 所需的深度包。原矩阵尾注不能重新定义 done。

本次修正只把四项真实 ADK 代码增强投影到生产矩阵，其余八项完整保留在原 candidate/decision/map。原 `docs/changes/20261023-evidence-methods/review-evidence.json`、requirements/design/tasks 和执行日志保持历史原件；前次方法审核遗漏上述两个 gate，历史 PASS 不继承为本次更正验收。

前次矩阵更正的独立复审绑定了当时独立报告、矩阵 Markdown/JSONL、implementation map、runbook 和 removal fixture 共六份文件，并实际运行了以下七个原始入口；该历史记录保留在 `review-projection-correction.json`：

- `rtk bash scripts/check-upstream-intake-readiness.sh .`
- `rtk bash scripts/check-observe-intake-depth.sh .`
- `rtk bash scripts/check-adoption-matrix-structured.sh .`
- `rtk bash scripts/check-adoption-matrix-status.sh .`
- `rtk bash scripts/check-adoption-evidence-integrity.sh .`
- `rtk bash scripts/check-adoption-real-assets.sh . --summary-json`
- `rtk bash tests/test_reference_repository_removal.sh`

矩阵 JSONL 由原 exporter 生成，removal pass fixture 的 adoption_decision 摘要由原 planner 计算；不改变门禁或测试断言。新提交的全量回归、受保护 PR CI 与实际 main CI 独立留证。本报告不预填尚未运行的更正后结果。

当前缺少本机声明运行环境、过期 dirty baseline 及旧 M5 资格的门禁结果仍依其原权威报告，不能用本次矩阵修正、ADK 发布或 PR CI 绿色消除。复审时间沿原变更节奏或 2026-11-22 之前进行；该日期不表示创建了自动任务。

## 文档整合与严格维护预算

`64c5192f2d6aaacf65143223f03190564032facc` 的远端 CI 39965536971 与同树本地完整回归均在 `test_maintainability_budgets` 失败：先完成 41 组，root-report-count 实测 321，超过 warning_limit 320；strict 模式正确拒绝 warning。唯一增量是本轮新建的 `reports/evidence-methods-absorption-2026-10-23.md`。

本次将该分析完整合并到已有 implementation map，移除重复的根 reports 载体，并将矩阵证据更新到本文件及既有真实 ADK 代码。原报告及独立审核仍可从 [固定历史提交](https://github.com/jiying2007/llm_agent/blob/64c5192f2d6aaacf65143223f03190564032facc/reports/evidence-methods-absorption-2026-10-23.md) 回读。没有移动旧报告、排除目录、改变统计规则或提高任何预算。原 12 candidate/decision、9 ENHANCE/3 OBSERVE、4/5/3 分流和适用边界保持不变。

文档整合后的独立复审须绑定当前矩阵 Markdown/JSONL、implementation map、runbook、removal fixture 共五份文件，以及原报告删除和内容合并事实。除上述七个原始 intake/matrix/removal 入口外，还必须执行 `rtk bash tests/test_maintainability_budgets.sh`。旧 CI 与本地 41/1 失败、未执行的两个 quick、已归档的本轮测试临时产物分别保留；最新完整回归和实际主线结果由后续精确提交证据给出。
