# 外部方法研究：让既有资格证据持续可核对

## 结论与研究边界

本轮最值得吸收的是：用当前源码和输入摘要约束资格复核、保留失败阶段的客观材料、按真实日期准备复审输入。两仓已具备签名校验、配对效果统计、重复试验可靠性、脱敏轨迹契约和可恢复 campaign；再建同类平台不能补出缺失的真实运行或 Owner 判断。

研究核对时点为 **2026-10-20 03:06 UTC**，后续补核截至当日。先用 `rg` 阅读两仓源码、契约和 runbook，再使用联网搜索的 system1 核实官方现行资料并打开正文。下列 17 项来源均为官方文档、原始论文或上游源码。无公布日期的页面明确标为检索日快照，不把抓取时间冒充发布日期。

既有能力的审查基线：

| 仓库 | 精确提交 | Git tree |
| --- | --- | --- |
| Root `llm_agent` | `1badead06b2083d8c41a1854dec5aff74c0d0b42` | `5d6f86ec027683739ee2434e9e00576a6f1308da` |
| `agent-dev-kit` 8.0.34 | `da25a7d86a0efe61110f5d8d892c49ff80d91dcc` | `604e7deb38edc751d1c57ace431765a47c8a6d2a` |

本地 `~/codex` 源码和 Knowledge Provider 不可用，因此 OpenAI 相关方法回退到官方文档核对；本文不声称已通过该运行资产的 Provider/Execution Policy。本轮报告属于明确授权的技术优化研究，不形成外部实践的自动 ADOPT 记录，也不替任何真实资格填写 Owner 答案。代码、完整门禁和远端 CI 的完成状态以本变更的实际验证记录为准。

## 先去重：已经实现什么

| 方法 | 当前源码证据 | 本轮判断 |
| --- | --- | --- |
| 产物、源码、签名身份相互约束 | ADK `src/agent_dev_kit/sigstore_blob.py` 被 native/agent-value trust 共用；Root `m5_signature.py`、`m5_ci_contract.py`、`m5_runtime_receipt.py` 与 promotion 路径已约束精确来源 | 复用原 verifier 和信任边界。新复核报告需要显示来源与检查状态，不另造签名或自授信任。 |
| 真实配对 A/B 与统计判据 | ADK `effect_trials.py:52–77,96–145,148–216` 已冻结控制项、检验完整 trial 集合、按 task 配对 bootstrap、做 campaign 内多重比较校正，并区分 infra failure/无效/退化/不确定 | 缺口是实际代表性任务及受管测量，不是再加 bootstrap。独立任务数、预注册和原始受管结果仍须真实存在。 |
| 重复试验可靠性 | `effect_trials.py:219–229` 已输出 `all_trials_succeeded_rate`、`any_trial_succeeded_rate` 及 task/trial 数；不可测时明确缺失 | 已覆盖固定试验次数下“全部成功/至少一次成功”的问题。不能把换名为 `pass^k` 宣传成新增功能；也不能把更多重试当独立任务。 |
| 轨迹摘要与隐私 | `docs/runbooks/trace-summary-emitter.md` 与 `manifests/trace_eval_contracts.json` 已区分单次 run、缺失值和真实 outcome；拒绝 raw prompts/messages/tool args/results、秘密与未知字段 | 保留当前更严格的禁内容策略。只读资格聚合器不需要新 exporter 或原始对话。 |
| OTel GenAI 上游迁移 | `external_agent_pattern_contracts.json:206,214` 已记录 2026-09-21 复审；`trace_eval_contracts.json:351` 已指向专用新仓，固定已审 revision `cc07f722069974139dab497d80d145144b19daca`，Schema URL 未定 | 迁移已吸收。本轮没有确认必须修的失效旧链接；上游出现新 commit 本身不构成更新 pin 的理由。 |
| 可恢复执行与未知外部结果 | `native_campaign` 已有 prepare/run/finalize、精确命令与二进制绑定、输出/时间预算；Root G22 有可恢复 campaign；ADK `boundary_rehearsal.py` 对未知外部结果返回 `reconcile-required` | 不重造 durable engine。一次扫描失败需要保留已知结果，未知执行结果仍由既有 reconciliation 处理。 |
| Harness 复审 | ADK 既有七维 readiness，含 Owner、last_verified、next_action、过期 blocker 和 JSON/Markdown；gate 禁止 `--as-of` | 可以补当天定期采集与证据材料；不能通过自动改日期消除到期。 |

外部研究支持这些判断的依据分别见 S01–S09、S10–S14。源码行号对应上表精确基线，后续改动可能移动行号。

## 两条强方案比较

| 方案 | 能解决的问题 | 代价与局限 | 选择 |
| --- | --- | --- | --- |
| **A：复用原 certifier 的只读复核器** | 对六项现有资格采集当前事实，逐项报告阻塞；比较扫描前后源码/输入身份，拒绝把旧状态当当前结论 | 新增一个有界 CLI 与报告契约；无需数据库、worker、模型或新服务。报告只能观察现存证据，不能制造真实测量 | **本轮采用。** 借鉴 Kubernetes 当前/目标状态对照和 Condition 的观测版本语义，落实为本仓已有 JSON 入口的组合，见 S12–S13。 |
| **B：引入持久执行引擎** | LangGraph checkpoint 可保存线程执行状态；Temporal history/activity 适合跨 worker 的长时恢复及失败重试，见 S10–S11 | 需新的状态存储、worker、运维和 Python 兼容性验证；外部副作用仍需幂等键和未知结果核对，不能因有 history 就推导 exactly-once，见 S11、S14 | **观察，暂不采用平台。** 六个现有只读命令没有足够理由承担这些成本。以后真实长时执行跨进程丢失状态时，再以故障数据比较。 |

方案 B 有明确价值，但当前阻塞主要是证据缺失与语义审查，不是缺少另一套调度器。保留 Python 3.8、免费或自有资源的约束，优先从现有 typed core 和 CI 中实现方案 A。

## 立即吸收的四项方法

### P0：把“检查跑完”与“资格齐备”分开

S01 要求验证消费者预期的来源、配置与产物；S03 将测试结果和测试配置同时列为必要信息。S12–S13 的观测版本做法提示：状态必须能回答“依据哪个版本得到”。这些是方法依据，并不意味着本仓声明达到某个 SLSA 等级或采用 in-toto 原生格式。

落实到 `llm-ctl qualification-followup`：固定六项、固定 argv，复用各自原 certifier；保留有界原始 JSON、真实退出码、剩余证据和下一步。总体 `scan_status=complete|error` 与 `qualification_all_ready` 独立。正常得出 blocked 仍可完成扫描；超时、超量、重复 JSON key、schema 错误、异常退出和来源漂移属于扫描错误，不能被包装成普通待办。

报告使用真实 UTC，保留 `source_before`、`source_after`、`input_digest`、`source_consistent`。只有与实际来源一致才可消费；不能靠 artifact 名称、issue 状态或 workflow 绿色认定资格。一次命令失败仍收集其他项目。输出固定声明 `report_only=true`、`release_authorized=false`、`may_fill_owner=false`、`provider_execution_performed=false`。

成本：新增依赖和模型调用均为零；主要成本是有界子命令运行与现有 CI 时间。CI 是否产生费用取决于现有账户额度，不能承诺任意部署均免费。与引入执行平台相比，这是较小的实现和维护范围。

验收：检查顺序和数量固定；一个检查失败不丢其余结果；扫描中改变来源必须 error；不执行 provider、写信任注册、改资格文件、填 Owner 或关闭 issue；相同输入重复扫描不产生资格源变更。

### P0：给 Owner 准备可追溯的事实材料

S04、S15 支持把轨迹、实际 outcome、评分标准和人工语义判断区分开。应用于 ADK #201 时，复核材料应列出三个原始 change 的文件清单、摘要、当前来源、待答的 Spec/Quality 问题和未完成步骤。已有 stage 状态只能证明流程字段，不能自动回答设计是否合理、质量是否接受。

对于带到期日的证据，分别展示“签名在签署时可验证”“业务证据当前未过期”“适用于当前候选”三种事实。S02 解释了签名时间与短期证书验证；它没有替项目定义业务资格的有效期。材料不能重签历史输入、延长 expiry，或把已有签名等同于本轮 Owner 审查。

成本：只读文件清单与既有 typed 数据整理；无需模型裁判或第二个人工批准角色。本轮技术优化按已有授权执行，原任务要求的真实 Owner 语义答案仍由实际责任人提供。

验收：三个历史包的字节与摘要不变；所有未答语义项保持未答；当前时间或来源改变后能重新生成客观材料；报告成功不把资格变为通过。

### P1：让 Harness 复审依赖当天事实和实际证据

复用原七维 `harness readiness --gate`，采集真实当天日期、实际证据摘要、到期日和原 next_action。当前源码 push、定期 CI 和手动入口可以重新生成报告；所有触发只负责采集，不自动修改 last_verified、Owner 或期限。原 certifier 对缺失、过期的判断应完整保留。

这是 S12–S13 的状态复核方法在文档治理中的小范围应用。到期提示应指向需重审的具体维度和证据；不得仅依据定时任务成功就把七维标为新鲜。定期触发也不证明现场无中断运行。

成本：复用现有 CI 与 readiness，无新增平台、凭证或 provider 请求。验收重点是当天边界、证据 digest 变化、缺文件、未来日期、已过期输入，以及摘要失败时仍保留诊断。

### P1：native 失败后仍保留安全的阶段诊断

这是已确认的流程缺口：8.0.34 `.github/workflows/native-claude-conformance.yml:378–423` 的 candidate 打包和上传均受默认成功条件约束。认证、canary、finalize 或 production-loader 校验提前失败时，后续客观诊断材料可能没有保留下来。S16 确认 GitHub 默认应用 `success()`；其 `always()` 适合失败/取消时的有限日志步骤，不能随意用于取源等关键动作。

建议只为限时、allowlist 的诊断构建与上传启用失败保留：记录 run/source 身份、实际阶段状态、已完成步骤和已生成文件摘要。没有执行的步骤保持未执行；未知状态明确未知。原有认证、provider 执行、finalize、签名、候选信任构造继续遵守成功前提，失败材料没有 native 资格效力。

隐私边界很具体：原 workflow 的 secret helper/settings 位于 113–145 行，私有 commands/assertions 位于 159–226 行。不得上传整个 `RUNNER_TEMP`、完整 stdout/stderr、认证 helper、原始命令或断言内容。S17 说明自动秘密脱敏不是可靠的最后防线；应在生成诊断时只允许固定元数据字段。

成本：不增加真实模型调用次数；增加少量诊断与 artifact 空间。验收至少覆盖缺凭证、运行超时、部分 canary 结束、finalize/loader 失败、报告生成失败和取消状态；诊断不得伪造 receipt、通过记录或额外调用 provider。

## 观察与不采用

| 分类 | 方法 | 判断及重新评估条件 |
| --- | --- | --- |
| 观察 | OTel GenAI 新版本映射 | S07 已提示旧站点迁移，S08 上游仍在演进；本仓已迁移并固定审核版本。2026-10-20 读取 main 为 `547934afa90a34298441caf80c43b27255c3a292`，commit 时间 2026-10-18 02:49:01 UTC。仅在需要实际 adapter/exporter 或现有映射被明确废弃时复审，不自动追 main、不发明 Schema URL。 |
| 观察 | 更丰富的 pass^k 曲线或统计分层 | S05 可帮助解释可靠性，但当前已有固定 k 的全部/任意成功率及配对检验。先完成真实代表性 campaign，再由预注册问题决定是否增加分层、样本量或估计量。 |
| 保持现有边界 | 只记录必要 telemetry | S09 的演示允许 opt-in 内容采集；ADK 已更严格地禁止 raw 内容。不能为更漂亮的可视化降低这一边界，也不把未知 token/cost/outcome 填成零。 |
| 不采用 | 新云平台、遥测后端、评测整包、付费模型裁判 | 不能直接解决当前六项资格证据缺失；会增加依赖、运行成本或数据出口。本轮仅吸收方法和小范围 typed 实现。 |
| 不采用 | 自动 Owner 通过、自动延长到期、回填 30 日观察或补签资格 | 缺少真实事实，且会混淆技术验证与业务资格；CI、fixture、时间流逝或研究报告都不能补出这些证据。 |

## 六项资格的真实闭环条件

| 原任务 | 本轮技术优化提供什么 | 仍需由原权威验证的事实 |
| --- | --- | --- |
| [ADK #153 native](https://github.com/jiying2007/agent-dev-kit/issues/153) | 当前 readiness 与失败阶段客观诊断 | 真实 authenticated discovery/load/trigger、精确运行身份、签名与受管信任、production loader 验证。失败 artifact 不授予资格。 |
| [ADK #201 Owner 语义审查](https://github.com/jiying2007/agent-dev-kit/issues/201) | 三个历史包的可核验清单与未答问题 | 实际 Owner 对具体 Spec/Quality 问题作出判断；stage 字段、自动检查和 AI 建议不能代填。 |
| [ADK #205 Harness](https://github.com/jiying2007/agent-dev-kit/issues/205) | 当天七维诊断、摘要与期限材料 | 按真实证据完成需要的维度复审；只在实际完成后更新审核字段。 |
| [Root #236 current-source M5](https://github.com/jiying2007/llm_agent/issues/236) | 当前来源的诊断与明确阻塞 | 仅在原条件性产品资格任务需要时，由当前候选的原 M5 certifier 验证运行/现场/签名链；组件 Release 或 main CI 不授予 Product M5。 |
| [Root #154 G22 效果](https://github.com/jiying2007/llm_agent/issues/154) | 复用已有预注册、campaign、比较、materializer、受管 receipt replay 和测量入口 | 真实预注册 paired trials、全部当前资产覆盖、原始摘要 digest/控制项/时间约束及 Owner v5。当前空 canonical index 或 trust authorities 应显示阻塞，不被示例填充。 |
| [Root #67 LTA-04](https://github.com/jiying2007/llm_agent/issues/67) | 完整窗口和缺失材料诊断 | 基线现场 ledger 只有两条 `pilot_started`，仍缺末窗口 `pilot_observed` 与 canonical summary。已过 30 日不证明持续运行、零事故或实际审查。 |

技术闭环是“实现这些只读与失败保留能力，验证边界，按受保护流程集成”；资格闭环还要等待并验证上述真实证据。二者在报告与退出码中必须分别表达。

## 本轮建议的验证判据

1. **身份和不可变性：** 对六项输入采集精确 source/digest；扫描前后不一致时拒绝给出当前资格结论；历史包、Owner、信任和现场输入逐字节不变。
2. **完整性和错误保留：** 固定六项始终有可解释结果；timeout、输出超预算、重复 JSON key、未知 schema、异常退出不得静默吞掉；仍保留已完成项。
3. **时间语义：** 使用实际 UTC；不接受回溯时间让过期资格通过；签名时间、业务期限、采集时间独立；窗口届满但没有观察仍阻塞。
4. **执行与隐私：** 固定 argv、限定输出、最小 job 权限；报告路径不调用 provider，不写资格源；failed-native artifact 只含允许的客观元数据，不含 raw 内容或秘密。
5. **判定分离：** 扫描完成、测试通过、组件发布、原始 runtime 结果、Owner 答案和最终资格分别报告；fixture 测试只能证明工具行为。
6. **现有门禁：** 由实现方对实际变更 snapshot 执行仓库规定的定向和完整门禁；保留 Python 3.8 和原有预算。本文的研究结论不能代替测试或当前主线 CI receipt。

## 一手来源目录

每一行都已打开正文。S01–S17 是本文的来源标识；链接保留官方原址，研究日期均为 2026-10-20。日期没有公开时不推测。

| ID | 来源与实际 URL | 版本、发布日期或快照 | 吸收点与限制 |
| --- | --- | --- | --- |
| S01 | [SLSA：Build / Verifying artifacts](https://slsa.dev/spec/v1.2/verifying-artifacts) | v1.2，页面标记 Approved；检索日快照 | 核对 subject digest、可信 builder 与预期配置；只验签不能代替消费策略。本文不授予 SLSA 等级。 |
| S02 | [Sigstore：Timestamps](https://docs.sigstore.dev/cosign/verifying/timestamps/) | 未列发布日期；检索日快照 | 使用可信时间验证签署时证书有效性；不能由此推导当前业务证据未过期。 |
| S03 | [in-toto：test-result predicate](https://github.com/in-toto/attestation/blob/main/spec/predicates/test-result.md) | predicate `v0.1`；检索日 main | 绑定被测 subject、必要 configuration 和 result；不将自有 receipt 谎称已采用该格式。 |
| S04 | [Anthropic：Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | 2026-01-09 | 分开 task/trial、轨迹和环境 outcome；结合实际审查理解失败。不能用模型自述替实际结果。 |
| S05 | [τ-bench 原始论文](https://arxiv.org/html/2406.12045v1) | 2024-06-17，v1 | 用结束状态评判任务，区分至少一次成功与连续多次可靠性；不安装整包、不为复现而调用收费模型。 |
| S06 | [Dror 等：The Hitchhiker’s Guide to Testing Statistical Significance in NLP](https://aclanthology.org/P18-1128/) | ACL 2018-07；DOI `10.18653/v1/P18-1128` | 显著性方法取决于任务、实验设计与指标；本仓具体 bootstrap/校正由自身预注册契约决定，不能把论文当某算法的通用背书。 |
| S07 | [OTel 旧站 GenAI spans 页面](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/) | 检索日显示已迁移且不再维护 | 确认引用迁移事实；当前 ADK 已处理，不作为新缺陷。 |
| S08 | [OTel GenAI 上游源码](https://github.com/open-telemetry/semantic-conventions-genai) | 检索日 main `547934afa90a34298441caf80c43b27255c3a292`；2026-10-18 | README 的 Schema URL 仍为 TODO；保留已审 revision 与 native 字段，不编造稳定 schema。commit 仅是检索身份，不是 ADK 新批准 pin。 |
| S09 | [OTel：Inside the LLM Call](https://opentelemetry.io/blog/2026/genai-observability/) | 2026-05-14；页面最后修改 2026-09-14 | 默认 metadata 与 opt-in 内容风险的界线；本仓保持更严格的 raw-content 禁止策略。 |
| S10 | [LangGraph：Persistence](https://docs.langchain.com/oss/python/langgraph/persistence) | 未列发布日期；原 durable-execution URL 跳转此页 | checkpoint 与跨线程 store 有不同职责；作为方案比较，不增加依赖或运行服务。 |
| S11 | [Temporal：Activity Definition](https://docs.temporal.io/activity-definition) | 未列发布日期；检索日快照 | activity 完成但未写入 history 时仍可能重试；副作用需幂等和粒度设计，不推导外部 exactly-once。 |
| S12 | [Kubernetes：Controllers](https://kubernetes.io/docs/concepts/architecture/controller/) | 未固定发布日期；检索日快照 | 对比当前状态与期望，每个控制器职责有限；本轮仅借用复核模式，不部署集群。 |
| S13 | [Kubernetes apimachinery：Condition 原始定义](https://raw.githubusercontent.com/kubernetes/apimachinery/master/pkg/apis/meta/v1/types.go) | 检索日 master，`Condition` 注释与字段 | `observedGeneration` 不匹配当前 generation 时状态过时；借鉴为来源一致性检查，不复制 Kubernetes API。 |
| S14 | [AWS Builders Library：Making retries safe with idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/) | 未列发布日期；检索日快照 | 用调用方请求身份区别重复请求与新意图；现有未知结果 reconciliation 应保留，不接入 AWS 服务。 |
| S15 | [OpenAI：Evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices) | 未列发布日期；检索日快照 | 真实任务、明确判据、人工校准与持续验证的方法；不采用收费 Evals API 或模型裁判。 |
| S16 | [GitHub：Expressions / status check functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) | 未列发布日期；检索日快照 | 默认 `success()` 与 `always()` 的适用范围；失败保留仅限有界诊断/上传，不能扩大关键执行。 |
| S17 | [GitHub：Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | 未列发布日期；检索日快照 | 最小 `GITHUB_TOKEN` 权限、秘密脱敏局限；allowlist 元数据优先于事后清理完整日志。 |

上述平台能力属于外部事实；本仓的优先级、成本和不采用判断属于对精确源码基线及当前六项任务的工程推断。研究没有新增模型或云资源调用、真实资格签名、现场观察或 Owner 决策。
