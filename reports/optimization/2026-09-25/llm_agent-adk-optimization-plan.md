# llm_agent / agent-dev-kit 优化方案

研究日期：2026-09-25（Asia/Singapore）  
状态：方案，尚未实施；不代表全量回归、原生运行时认证或生产资格通过。

## 1. 决策摘要

保留现有架构，不把两个仓库改造成新的 Agent runtime。

- llm_agent：外部实践研究、固定来源取证、候选审查、跨仓组合与效果观察。
- agent-dev-kit：平台中立资产契约、编译、验证、评测、分发与证据模型。
- Codex / Claude 等外部运行时：负责实际会话、工具执行、权限与原生加载。
- Digital Worker：继续独占 R2 qualification；Root 只消费结果。

建议优化次序：研究输入真实性 → 有界低内存分析 → 重复试验与可归因评测 → 技能路由/上下文优化 → 分发、恢复和维护成本优化。不要先扩充参考仓、技能数量或多 Agent 编排层。

## 2. 已核验基线

| 对象 | 基线 |
|---|---|
| ADK main | `7367ef84787de75bb751940b32c9e80009660e47` |
| ADK source version | `7.0.31` |
| ADK tree | `46fd5d2b99aa7fef7fb35c2c6624fd8790139506` |
| llm_agent main | `1df8204166ff7768d0e26e42ee12bcd38ba3b515` |
| Root interface lock | 绑定上述 ADK version / commit / tree |

已存在且应保留：JSON-only manifest；execution_policy 唯一 Python 策略命名空间；Source / Release / Runtime / Product 四维状态隔离；reference exact pin + 用户 cache；人工审查后采纳；隐私约束的 trace / run evidence / asset receipt；baseline/candidate 比较器；Root 输入依赖图驱动门禁；ADK → 外部 ~/codex → ~/.codex 分发链。

本轮读取了上述固定提交的入口、契约和关键实现，没有重新执行完整 CI、真实 provider 运行或用户机器上的 live apply。外部资料按检索时版本读取；正式吸收前仍须记录其 immutable commit / blob / license。

## 3. 源码确认的问题与改进空间

### F1：reference cache 与分析入口未贯通（P0）

`tools/control_plane/reference_pins.py` 的默认 materialize 目标为用户 cache 下的 `<id>/<commit>`，并声明 user-cache-only；`tools/codex_assets/intake_pipeline.py:analyze()` 却将来源固定为 `root / repository_name`，并要求 realpath 位于 Root 内。`scripts/analyze-repo.sh` 仅把 Root 传给该实现，未转换为 cache source。

因此，按新 README 的 cache-only 路线物化后，现有分析入口不能直接消费对应来源；用指向外部 cache 的 Root symlink 也会被 realpath containment 拒绝。此结论来自该入口的静态控制流，不是声称所有自定义外部脚本都无法分析。

另外，`--cache-root` 的实现接受任意解析后的目录，当前 plan/materialize 未显式排除 Root 或 live 目录；应把 user-cache-only 从声明落实到路径权限边界，而不是重新引入 Root checkout。

### F2：语言覆盖与 YAML frontmatter 不完整（P0）

TEXT_SUFFIXES 不含 `.rs` / `.go`；提示词代码信号只扫描 `.py/.sh/.js/.ts`。这是文本与信号分析覆盖缺口，不是说这些文件完全没有进入 inventory。

`_frontmatter_value()` 只用单行正则取值；对 `description: |` 或 `description: >` 会得到块标记而非完整描述。`_read_text()` 对超限、非白名单或解码失败返回空串，缺少分析覆盖原因。因此“没有发现”和“没有分析”容易混在报告里。

### F3：资源限制不能覆盖运行过程（P0）

`_pattern_signals()` 先把所有允许读取的文本保存到 `text_files` 列表。`git archive` 写完临时文件之后才检查 512 MiB 限制；相关 subprocess 没有 timeout。这并不意味着已有路径防护无效：当前实现已有路径 containment、跳过链接、拒绝设备文件和成员数量限制，应保留并补齐运行时预算。

这里发现的是仓库分析器的资源风险，不能据此认定它就是浏览器页面 Out of Memory 的根因。

### F4：效果比较器是单次配对均值报告，而不是重复试验框架（P0）

`effect_comparator.py` 在每个条件中按 task_id 建索引并拒绝重复 task；`_measured()` 给出均值；`_deltas()` 给出均值差。它已经认真检查完整任务集合、独立 run_id、相同 runtime/model identity、不同资产 bundle 和一致币种。

应在此基础上增加 trial 维度、实验控制变量、分布与不确定性，而不是另建一个评测系统。当前 prompt_versions 被汇总展示，但比较入口没有要求两条件的非干预 prompt/control variables 完全一致。

已有 test-only / no lifecycle authority 限制必须保留。不能把统计改进直接变成 runtime certification 或 product qualification。

### F5：仍有活动文档指向退休契约（P1）

Root `scripts/README.md` 的 release-clean 说明仍写 `agent-dev-kit/manifest.yaml`，与当前 JSON-only manifest 冲突。其 2026-05-23 的 2.9.0 状态段虽然有日期，但放在活动操作手册中容易被误读；应明确归档或改为生成状态链接。

### F6：静态结构评分应减少语义暗示（P1）

intake 已明确 `structural-readiness-only` 和 `not_an_adoption_score`，这是正确边界。但 `painpoint_precision`、`context_efficiency` 等分数由 frontmatter/文件数量推导，并不测量实际痛点命中或 token 效率。建议用结构计数与覆盖率取代易误读的效用名称，不把数值总分升级为采纳排名。

## 4. 外部研究吸收矩阵

| 来源 / 已读取内容 | 值得吸收 | 不应照搬 |
|---|---|---|
| OpenAI Harness engineering | 短 AGENTS 导航、仓库内事实源、依赖方向机械校验、持续文档清理 | 特定高吞吐团队放宽 merge blocker 的策略，不适用于本项目严格发布与资格边界 |
| Claude Code Best practices / long-running harnesses | 先定义可执行验收、独立验证、增量任务、可恢复进度 | 把会话 Stop hook 或上下文 checkpoint 等同不可绕过发布门禁或全系统事务回滚 |
| Agent Skills specification | YAML metadata、明确用途和触发条件、渐进加载、平台能力显式声明 | 把 experimental allowed-tools 当成跨运行时统一授权机制 |
| anthropics/skills 的 skill-creator/run_eval.py | 正负触发样本、重复试验、结构化 trigger_rate | 该脚本用临时 .claude/commands 代理描述触发；不能代表完整原生 skill 加载/执行认证；异常不得归并为业务 False |
| obra/superpowers 的 writing-skills/SKILL.md | 先证明无 skill 的失败，再做最小修复和回归；机械约束写成测试 | 全量安装、所有任务强制多 Agent，以及与官方规范不一致的描述/格式要求 |
| Fission-AI/OpenSpec 的 spec-driven/schema.yaml | 行为规格、可检验场景、显式 artifact requires、按影响选择设计深度 | 与 ADK 既有 change contract 并行维护另一套权威状态 |
| Aider 的 aider/repomap.py 与 repo-map 文档 | 符号/依赖地图、分层取证、缓存、预算内挑选上下文 | 直接引入整个运行时；把抽样 token 估计当成硬预算的精确证明 |
| mini-swe-agent 的 agents/default.py | 可读的小执行模型、明确错误/限制状态、可追踪轨迹 | ADK 自己实现推理循环；把下一轮检查累计成本等同预先保证绝不超支 |
| OpenHands SDK / LangGraph 官方说明 | workspace、conversation、adapter 与 orchestration 职责分隔；持久状态语义 | 为借鉴原则而新增生产 runtime、服务端或完整框架依赖 |
| Codex 官方 openai_yaml.md | 把 agents/openai.yaml 定义为产品扩展配置；显式/隐式调用策略可由适配器表达 | 将 Codex 产品字段反向塞入 ADK core 或假定其他运行时同样解释 |
| GitHub Actions 安全与 provenance | 消费侧验证 exact identity、完整 SHA pin、最小权限、attestation | 把 artifact 存在或 workflow 绿当作来源和资格都已验证 |
| MCP / OTel 官方资料 | 版本化 adapter、协议安全测试、最小遥测映射 | 把 draft 或变化中的外部规范当作 core 的隐含权威 |

特别注意：superpowers 当前建议 description 只写何时触发，而官方 Agent Skills 规范要求用途和使用时机。建议满足官方格式与语义要求，保持简洁，再由各运行时的正负触发评测判断效果，不能盲目合并两套相冲突的口号。

## 5. 目标链路（复用现有权威）

reference pin → 有界物化 → immutable snapshot → 覆盖可解释的取证 → 具体实践候选 → 语义/架构/许可证/安全审查 → 最小 ADK change → 配对效果实验 → release / consumer 验证 → 现场反馈。

每一步只生成自己的证据，不越权提升下一层状态。静态分析不能自动写 adoption matrix；LLM 建议不能替代批准；runtime receipt 不能自动给产品资格。

建议扩展现有 decision-candidate / task-pack，而非平行创建 registry。每个候选记录：来源 URL 与 commit/blob、具体代码位置、行为机制、适用前提、当前问题、目标现有资产、许可证范围、风险、baseline、计划干预、验收方式、回滚条件和审查决定。

研究单位从“整个仓值得采纳吗”收敛为“这个机制解决哪个已知问题，并如何证明有效”。同名不是必然重复，异名不是必然新能力；语义判断仍需可复核审查。

## 6. 工作包

### R1：贯通 cache-only source identity（第一批，P0，llm_agent）

落点：`tools/control_plane/reference_pins.py`、`tools/codex_assets/intake_pipeline.py`、`tools/control_plane/cli.py`、`scripts/analyze-repo.sh`。

设计：由 reference pin resolver 产生唯一的 typed source snapshot，携带 reference_id、approved URL、commit、tree、cache 路径、来源种类；分析器消费已验证的快照，不再猜 Root 子目录。研究参考源和 managed dependency 必须显式分型，不以 fallback 混用。

验收：干净 Root 中不存在 OpenSpec/superpowers checkout 时，显式物化固定 pin 后可以完成分析；Root git status 不变；报告 commit/tree 与 pin 相同；错误 pin、路径逃逸、将 cache 指向 Root/live 目录、未批准的来源替换必须拒绝；已有 cache 的工作树内容不得污染 commit-snapshot 分析。

### R2：补齐覆盖率、解析与低内存预算（第一批，P0，llm_agent）

落点：现有 intake pipeline 及对应测试。

设计：按真实研究对象补 `.rs/.go` 等语言；采用受限 YAML 解析和 schema 验证，正确处理多行描述；单文件/流式提取静态信号；区分 analyzed、unsupported、oversized、decode-error、truncated；按语言和文件类型给出覆盖分母。

进程预算覆盖 fetch/archive/analyze，限制时间、输出、archive 生成中的字节数和成员数；超限明确返回 budget-exceeded，不能继续标记 static-complete。默认串行，在预算与隔离条件证明满足后再提高并发。失败 JSON 必须与 exit code 一致，不出现 summary-json 模式只在 stderr 给错误的分裂。

验收：Rust/Go 混合仓、YAML |/>、大文件、坏编码、链接、恶意路径、超时命令、输出洪泛、超大归档都有负例；扩大输入规模时 peak RSS 不随所有文本总大小线性累计；测量实际资源基线后设可配置预算，不虚构一个通用内存数字。

### A1：重复试验和可归因效果合同（第二批，P0，ADK）

落点：`effect_comparator.py`、`run_evidence.py`、`trace_summary.py` 及对应 schema/tests。

设计：显式 `(task_id, trial_id, condition)`；不能把重复 trial 改成不同任务编号虚增样本量。完整记录计划试验集合和实际试验状态，避免只上传成功样本。固定任务/仓库/环境/运行时/模型/工具权限/grader/非干预 prompt 与参数；声明本轮唯一干预变量。对模型中转或别名，分别记录已审查 endpoint 标识、请求模型名、响应模型标识和配置摘要（不含凭证）；拿不到不可变模型 revision 时标记 identity-unverified，不能仅凭相同别名声称完全控制了模型变化。

保留现有成功率、首次成功、人工介入、时间、成本、token、误路由和弃权率；增加分布与配对不确定性。统计重采样以任务为聚类单位，避免重复运行造成伪独立。拒绝把 telemetry unavailable 当作 0。

建议输出 improved / non-inferior / regressed / inconclusive / invalid，效果阈值和非劣界值必须在实验前约定。样本不足只得 inconclusive，不得“绿即提升”。业务失败、实验环境故障、预算耗尽分别保存；预定义预算内未完成属于任务结果，外部停机是否令试验无效须事先定义且全量报告。

验收：支持每任务多个 trial；重复 run、缺试验、控制变量漂移、币种变化、伪造/错绑 evidence、缺指标均有失败用例；固定输入可重复生成同一统计报告；scope 继续为 test-only，无 lifecycle authority。

### R3：实践级取证与采纳实验闭环（第二批，P1，llm_agent）

落点：现有 analysis / decision-candidate / task-pack 生成逻辑与 adoption review 流程。

设计：结构计数不再命名为实际效能；每项 candidate 绑定具体问题、机制、现有资产与 A1 实验；引用只作为数据，不执行参考仓 hooks/install；许可证审查到文件/子目录级别。第三方文档更新优先按风险/语义差异复审，不机械拉取所有 active references。

验收：随机抽取候选可定位到不可变来源和本地负例；没有 semantic/risk approval 不生成可自动采用的状态；一次实验只改一项机制；过时或不适配结果记录 observe/reject，不为提高采纳量扩资产。

### A2：技能触发、native evidence 与上下文减负（第三批，P1，ADK + Root 观察）

落点：现有技能、compiler、evaluation、target adapters 与 evidence 接口；Codex 原生运行由既有消费链产生证据，不新增 ADK direct Codex live writer。

设计：分别测试“该触发/不该触发”“真实读入/仅字符串出现”“执行是否有效”。正例、近似负例、中文/英文、重叠技能、无关任务、应 abstain、安全阻断和 prompt injection 都纳入。运行时异常不算 negative case 的成功不触发。

保持三层加载：入口/metadata → 被选择的 SKILL → 按需 references/scripts。测量整个 profile 的实际加载成本，不只量单个文件。相似技能先通过语义和效果数据决定合并；安全/低频恢复技能不得仅因调用少自动删除。

Codex 的 `agents/openai.yaml` 等产品扩展只在 versioned adapter 或其声明式资产仓生成；不能当作 core schema，也不能替代宿主权限。

验收：比较 no-ADK / current-ADK / candidate-ADK 三个明确条件，先做少量 smoke 再进行配对重复试验；完整导出 bundle 在隔离 HOME 的支持运行时中真实 discover/load；原生结果绑定 bundle/runtime/config identity；不得写用户真实 ~/.codex。

### X1：状态文档、恢复协议与架构减负（第三批，P1）

Root 修复活动手册的 manifest.yaml；历史状态归档、实时状态采用现有生成投影。文档链接和命令要能在干净环境校验。

继续使用已有 change/task/evidence authority，恢复摘要仅保存其引用和投影：任务 ID、base/head、已完成步骤与 receipt、尚未执行步骤、下一可验证动作、有效预算与风险。恢复时先复核当前 head/目标状态，不按旧文本盲目重发写操作。单会话 checkpoint 不代表外部副作用回滚。

依赖方向/public API/authority ownership 用现有架构测试保护；不为文件字节预算制造 `_support.py` 或增加兼容别名。纯文档、小修复、复杂跨仓变更使用不同深度的工作流，避免一律完整多 Agent 流程。

### X2：消费侧 provenance 与 CI 成本回归（第三批，P1）

本项是拟增验收和需核验项，不是断言当前发布流水线缺失相关机制。

在现有 exact-SHA promotion / release / Root lock / consumer-chain 上补测：错 SHA、旧 head、资产 digest 不匹配、过期 receipt、证据身份不匹配、同事件重复触发、网络中断后恢复；不能用不同 commit 的绿色结果复用。验证 attestation 的 subject/source/workflow identity，而不只检查 attestation 文件存在。

保持 `manifests/gates.json` 为影响范围与依赖 SSOT；PR 使用确定性和受影响检查，主线/发布执行所需完整回归；昂贵 native campaign 独立预算、可分段产物、受控重试。日志和报告采用摘要+可定位附件，不把全量输出灌入交互页面。

验收：相同输入的重复处理不产生重复晋级或分叉状态；缺权限/凭证明确 blocked；不得通过放宽保护、加大通用 token 权限或跳过门禁获得全绿。

### X3：外部标准 adapter（按需，P2）

MCP 仅在出现明确 consumer 时实现版本化适配，测试 audience/scope、token passthrough、工具结果不可信与权限边界。OTel 作为现有 TraceRunFacts 的可选映射，不反向要求 core 接入 exporter/collector。外部规范的 draft/stable 状态逐项记录；无真实 consumer 不扩框架。

## 7. 评测最小方案

建议首轮选择 30 个有清晰验收的任务：10 个普通软件改动、10 个嵌入式相关且可离线验证的任务、10 个治理/恢复/安全负例。此配比是本方案起点，不是统计显著性的保证；可先用小子集验证 harness，再扩大。

离线嵌入式任务可包括 C 边界检查、协议解析、构建配置、日志诊断和回滚状态机，不替代电机实机、HIL 或产品现场验证。

每个候选与当前基线先采用 3 次/任务的重复运行，固定预算和条件；开发集用于调整，保留不用于调参的回归/留出任务。比较任务最终可执行结果而非模仿某条固定思维/工具轨迹；确定性测试优先，主观质量评分才使用经过人工校准的模型 grader。

报告至少同时展示：完整性/无效试验原因、pass@1、重复一致性、误触发与漏触发、实际人工介入、token/cost、时间分布。pass@k 和全部 k 次成功的可靠性指标不能混用。成本既看每任务，也看成功任务成本与失败浪费，不能通过更多弃权伪装效率改善。

对于“降低上下文成本”类候选，先约定成功率/安全边界的非劣要求，再判断 token/延迟是否改善。对于“提高成功率”类候选，先约定最大成本增幅和可靠性要求。小样本的 p95 和置信区间须报告其不稳定性，必要时补样，不伪造确定结论。

## 8. 放行与退出条件

满足：cache-only 端到端成立；覆盖与跳过可解释；预算内失败可控；重复试验可重放；至少一项候选有独立验收且效果结论明确；没有 schema/consumer/negative-test 回归；发布消费链身份一致。

出现：效果回退、样本不全、指标不可信、权限边界变弱、复杂度增加但没有证明收益时，保持当前资产，记录观察或回滚候选。不得以新 schema/更多技能/更多测试数量代替效用证据。

LTA-04 独立 30 天窗口最早于 **2026-10-12T04:19:00Z（新加坡时间 12:19）** 后才可能满足时间条件，且仍须真实 event-chain summary、风险和事故/恢复记录。现在的软件优化不必等待该窗口；不能将 synthetic fixture 或日期到了当作自动认证。

## 9. 首批落地建议

第一条主线：R1 + R2（Root intake 修复），用一个端到端目标贯穿，代码提交保持可独立 review。不要先添加参考仓。

第二条主线：A1（ADK 效果比较）→ R3（Root 消费），契约/schema/所有 active consumer 原子迁移，不保留兼容 shim。若 wire contract 或 public API 不兼容，依据契约差异确定 SemVer 与新 schema identity，不能伪装成 patch；历史证据按原 schema 留存，不静默重写，也不为它恢复 live 兼容分支。

第三条主线：A2 只选择一组真实高频技能试点，同时推进 X1/X2；X3 保持按需。每批完成后用实测决定下一批，不按预先固定的“技能增长量”推进。

## 10. 来源索引

### 本地仓库固定版本证据

- B1 ADK README: https://github.com/jiying2007/agent-dev-kit/blob/7367ef84787de75bb751940b32c9e80009660e47/README.md
- B2 Root README: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/README.md
- B3 Root interface lock: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/manifests/adk_interface.lock.json
- B4 reference pins implementation: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/tools/control_plane/reference_pins.py
- B5 intake implementation: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/tools/codex_assets/intake_pipeline.py
- B6 analyze wrapper: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/scripts/analyze-repo.sh
- B7 effect comparator: https://github.com/jiying2007/agent-dev-kit/blob/7367ef84787de75bb751940b32c9e80009660e47/src/agent_dev_kit/effect_comparator.py
- B8 run evidence: https://github.com/jiying2007/agent-dev-kit/blob/7367ef84787de75bb751940b32c9e80009660e47/src/agent_dev_kit/run_evidence.py
- B9 trace summary: https://github.com/jiying2007/agent-dev-kit/blob/7367ef84787de75bb751940b32c9e80009660e47/src/agent_dev_kit/trace_summary.py
- B10 active script manual: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/scripts/README.md
- B11 reference registry: https://github.com/jiying2007/llm_agent/blob/1df8204166ff7768d0e26e42ee12bcd38ba3b515/subrepos/registry.csv

### 官方与开源资料

以下外部 main 链接为检索入口，不冒充 immutable pin；正式采纳时必须固化具体 commit 和许可证范围。

- S1 OpenAI Harness engineering: https://openai.com/index/harness-engineering/
- S2 OpenAI Codex AGENTS configuration: https://developers.openai.com/codex/guides/agents-md/
- S3 Anthropic Building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- S4 Anthropic Effective context engineering: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- S5 Anthropic Demystifying evals for AI agents (2026-01-09): https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- S6 Anthropic Effective harnesses for long-running agents: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- S7 Claude Code Best practices: https://code.claude.com/docs/en/best-practices
- S8 Agent Skills specification: https://agentskills.io/specification
- S9 Anthropic trigger evaluator source: https://github.com/anthropics/skills/blob/main/skills/skill-creator/scripts/run_eval.py
- S10 Anthropic skills licensing notice: https://github.com/anthropics/skills
- S11 Superpowers skill authoring asset: https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md
- S12 OpenSpec executable workflow schema: https://github.com/Fission-AI/OpenSpec/blob/main/schemas/spec-driven/schema.yaml
- S13 Aider repository-map source: https://github.com/Aider-AI/aider/blob/main/aider/repomap.py
- S14 Aider repository-map explanation: https://aider.chat/docs/repomap.html
- S15 mini-swe-agent default implementation: https://github.com/SWE-agent/mini-swe-agent/blob/main/src/minisweagent/agents/default.py
- S16 OpenHands SDK boundaries: https://github.com/OpenHands/software-agent-sdk
- S17 LangGraph persistence: https://docs.langchain.com/oss/python/langgraph/persistence
- S18 Codex product-specific skill metadata: https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/skill-creator/references/openai_yaml.md
- S19 MCP security practices (draft): https://modelcontextprotocol.io/docs/draft/tutorials/security/security_best_practices
- S20 OpenTelemetry GenAI current repository: https://github.com/open-telemetry/semantic-conventions-genai
- S21 GitHub secure use reference: https://docs.github.com/en/actions/reference/security/secure-use
- S22 GitHub securing builds: https://docs.github.com/en/code-security/tutorials/implement-supply-chain-best-practices/securing-builds

已读取外部文件的 blob identity（不是仓库 commit）：

- OpenSpec schema.yaml: `51322aa03ba1faa249e8fcebb8c465800b887f84`
- superpowers writing-skills/SKILL.md: `182dfad177c9940d8ea388be322aadddd6c4db5f`
- Aider repomap.py: `541bba6ef4a5385b8cf032201ec6e3f3e32a6ea6`
- Codex openai_yaml.md: `90f9e8e863dff501c0125e2ead20c1dd6c3028d5`

部分外部文件为定向分段阅读，未声称全仓逐行审查。上述取舍是对来源机制结合本项目约束的设计判断，不是外部作者对本项目的背书。
