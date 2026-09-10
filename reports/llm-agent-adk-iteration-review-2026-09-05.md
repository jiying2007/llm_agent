# llm_agent / ADK 三方向迭代审查

- 状态：reviewing / first-iteration-implemented / integration-needs-fix；不授权发布或 active promotion。
- 日期：2026-09-05；范围：本机历史、Knowledge Hub、llm_agent、agent-dev-kit、公开一手实践。
- 目标：执行效率与治理减负、知识检索与历史复用、交付可靠性与团队推广。
- 写入边界：本轮仅修改 llm_agent 根仓；保护 ADK 生命周期与 runtime-profile 的既有 dirty；不修改 live、memory、Hub 权威状态或团队发行包。
- 隐私：历史只输出统计和摘要，不复制聊天、原始日志、凭证、个人路径清单或客户信息；公开检索不发送本地材料。

## 执行计划与验收

| 阶段 | 状态 | 产物与验收 |
|---|---|---|
| 历史、Hub、实现及官方证据审查 | complete | 全量索引/关键词统计；重点回读；区分已实现与真实缺口 |
| 验证快照修复 | complete | 16 项定向测试通过；根仓回归 21/24，三项既有集成失败单列 |
| 检索与团队试点设计 | complete | 两份 runbook、六条真实查询基线、M5 入口修订；跨仓实现和真实试点仍待后续 |
| 收口 | in_progress | 新鲜检查结果、未闭环项、脱敏活动回执；Runtime Control idle 为 not-applicable |

- retry_budget：同类失败两次后修订假设；staleness_threshold：连续两次无新证据。
- stop_condition：本轮 source 修复与可审查设计完成，或因明确外部条件记录 blocked；不能用模拟数据补充真实团队效果。
- claimant：主执行 Agent；verifier：独立验证步骤与确定性回归，未声称独立人工/子代理审查。
- 回滚：撤回本轮根仓指定文件改动；不操作其他 dirty，不改 Git 历史。

## 已核验证据

1. 本机 state SQLite 只读：1,371 个线程，710 个主会话、661 个子代理线程，时间为 2026-04-04 至 2026-09-05（UTC 日期）。项目按历史 cwd 粗聚类，仅用于发现，不能替代 Hub repo identity。
2. history.jsonl 全量逐行关键词扫描：5,555 条有效记录，558 个 session ID，1 条无效 JSON；时间为 2026-05-09 至 2026-09-05。用户文本在内存分析，不复制进交付。
3. sessions 清单：1,374 个文件，约 3.29 GB。未逐字阅读全部正文；重点回读 2026-09-04 runtime cleanup、Hub receipt persistence 和 2026-08-28 团队包原子生成会话的最终消息。
4. 主线程标题发现：效率治理 97 个线程/57 天，知识复用 72/55，交付 113/64，审查排障 82/50。主题可重叠；标题命中不是缺陷次数、用户贡献、成功率或因果证据。
5. Hub registry 全量索引：545 项，active 16、reviewing 235、archived 288、draft 3、personal 2、rejected 1；活动回执目录 137 个 JSON 文件，未经逐件验证，不宣称全部有效。
6. Hub 正文核验：`projects/agent-dev-kit/decisions/harness-readiness-v1-candidate.md`、`projects/agent-dev-kit/validation/project-readiness.md`；前者仍要求两仓/两操作者/30 天试点，后者为 structurally-ready / evidence-pending。
7. 上一轮设计与执行基线：`reports/llm-agent-adk-comprehensive-design-assessment-2026-08-30.md`。路由 IR、Runtime Control task mode、Effect Comparator、验证分级和 supported-full receipt 已实现，不再提为新增平台。
8. 现有实现：`tools/codex_assets/validation_plan.py`、ADK `effect_comparator.py` / `evidence_graph.py` / `run_evidence.py`；Codex source `workflow_mining_report.py` 仅读 session_index 标题且内置六个偏嵌入式聚类。
9. fresh baseline：doc-sync pass；ADK strict pass 但解释器为 Python 3.8.10，属于 development-only；token budget pass-with-warning，累计 AGENTS 10,362 bytes 超过 soft 10,200、低于 hard 12,000。

## 已存在能力与本轮判断

| 方向 | 已有能力 | 缺口 | 决策 |
|---|---|---|---|
| 执行效率 | L1–L4、同 content snapshot full receipt、失败日志有界展开 | 父仓 diff 只见 ADK dirty 标记，不能绑定子仓实际 dirty 内容；缓存虽排除分类却仍参与指纹 | 修复现有 validation_plan，不新增 checker |
| 知识复用 | Hub registry / route / search、session receipts、workflow-mining | 标题索引覆盖有限；不能用 child thread 数冒充独立复现；跨项目工作流与结果反馈不足 | 扩展现有 miner 的设计与验收，保留在 Codex source owner 范围 |
| 团队交付 | Runtime Bundle、幂等 setup、source-to-live、Effect Comparator、M5 campaign | 第二操作者、独立仓、真实周期与 measured campaign 未闭环 | 复用现有 campaign，补轻量上手/故障回滚试点入口与判定表 |

## 外部设计证据

- [OpenAI Skills](https://learn.chatgpt.com/docs/build-skills)：描述与正文渐进加载；安装规模与实际加载集合应分别测量。官方页面当前说明初始 catalog 存在预算限制；本机资产多不等于全部正文被加载。
- [OpenAI Testing Agent Skills with Evals](https://developers.openai.com/blog/eval-skills)：以显式、隐式、带上下文、负例用例及工具事件验证路由与行为；迁移到本地时仅持久化脱敏摘要。
- [Anthropic Harness Design](https://www.anthropic.com/engineering/harness-design-long-running-apps)：结构化任务交接与可检验结果；随着模型变化逐项验证哪些控制仍有收益，避免一次删尽流程后无法定位退化。
- [Anthropic 开源长任务实现](https://github.com/anthropics/cwc-long-running-agents)：可读的 hook 与评估角色实现可用于检查机制粒度；不直接安装 hook、不引入第二套运行时。
- [LangGraph Persistence](https://docs.langchain.com/oss/python/langgraph/persistence)：区分线程 checkpoint 与跨线程 store；这里只参考会话状态和长期知识边界，不将 LangGraph 引入 ADK。

外部来源于本轮只读联网核验；“适合本项目”属于基于本地证据的设计推断。以上不是 ADOPT decision，也不是运行效果证明。

## 调整优先级与迭代次序

| ID / 优先级 | 调整 | 原因与现有覆盖 | 落点 / 本轮状态 | 后续验收 |
|---|---|---|---|---|
| E1 / P1 | 修复受管 diff 快照 | 子仓 A/B dirty 内容得到相同指纹；缓存却改变指纹 | llm_agent validation_plan：已实现 | 负例失效、排除项稳定、baseline 与 staged 边界；16 项通过 |
| E2 / P1 | 区分验证适用范围与整仓集成状态 | 既有 dirty 保守 L4；full 外部引用关键词扫描把“删除外部路径”的 change 说明判为依赖 | 保留 L4；门禁适用面调整交 ADK owner | scope 外差异显式阻断 release；删除说明与真实 runtime dependency 用正反例分别验证 |
| E3 / P2 | 用实际成本决定规则/Skill 瘦身 | 累计 AGENTS 已到 soft warning；已有 token budget 和渐进加载 | 当前报告提供基线；不增加新 Skill | 统计 catalog bytes、实际读取 Skill 数、重复工具/验证时间、人工等待；逐项去除候选后做相同任务回归 |
| K1 / P1 | 扩展已有 miner 的覆盖与去重 | session_index 217 行；本机 710 主会话、661 child；已有 miner 只有六类标题聚类 | Codex source owner；根仓交接 runbook 已落地，代码未改 | 多来源 coverage、ID 去重、child 不计独立复现、六类外新增治理/知识/交付；缺数据报告 unknown |
| K2 / P1 | 补活动回执到长期知识的受控衔接 | 9 月 4 日有真实 receipt，但“回执 持久化”本轮 search 零命中 | 知识 runbook 与查询基线已落地；Hub 正文 intake 未执行 | 生成 reviewing candidate、登记 canonical ID、回放自然语言查询；不得把 receipt 数当知识数 |
| K3 / P2 | 先做 known-answer / 负例，再扩检索技术 | 4 个登记正例 rank 1；“温控”可以从已登记正文命中，说明不能只查 registry 元数据下结论 | 六条查询基线已落地 | 冻结独立标注的真实 query 集，覆盖过期/别名/过滤/零命中；有缺口再评估 rerank/混合检索 |
| D1 / P1 | 清除团队认证入口的旧合同 | 当前 M5 doc 仍指向 3.1 RC7 与旧 state-dir，机器 policy 为 v5 | M5 文档已修订、计划生成命令已执行 | 只读 plan 与 policy 的 contract/state_dir 对齐，不沿用历史 rehearsal 成功状态 |
| D2 / P1 | 小范围团队上手/故障恢复试点 | Runtime Bundle/setup/原子生成已存在；第二 human 和独立 field 没有证据 | 六场景验收 runbook 已落地；试点未执行 | T1–T6，失败保留旧包、幂等、profile identity、恢复后真实功能；两人两仓及正式周期另外满足 |
| D3 / P1 | 把已有 Effect Comparator 接到真实观察 | API 与 schema 已实现；authority 默认为 disabled，CLI 不是采集服务 | ADK/Codex composition owner；设计交接，未启用 authority | 真实 source trace、受管 verifier、同条件 baseline、完整 coverage；缺失为 not-measured |
| D4 / release blocker | 单独收口 lock/发布身份/证据 freshness | 当前 HEAD 与 policy candidate 不同，root 21/24、quick 50/55 | 等既有 ADK lifecycle/source 工作形成可交付身份后串行收口 | clean commit/tree → lock/gitlink → fresh runtime evidence → 受管 release/source-to-live；不得靠改日期解除 |

上述后续项是明确待办，不表示本轮全部实现。尤其 K1/K2/D2/D3 不能由新增文档替代完成证据。当前无需新增通用 runtime、第二套知识库、默认外部 hooks、更多 Agent 或新加权成熟度评分。

## 三方向本轮交付

### 执行效率与治理减负

`managed-diff-v2` 绑定 baseline tree、受管 diff、文件内容/执行位、符号链接和子仓自身快照。分类中排除的 cache/reference/output 在读取及 hash 前同样排除；workspace 排除策略不误传到 ADK 内部同名目录。使用 NUL 文件名分隔和 literal pathspec；未初始化的受管 gitlink 明确报错。staged-only 不读取未暂存子仓。

修复前新增测试为 5 fail / 8 pass；修复后增加边界覆盖，共 16 pass。中间首次实现使用了 Python 3.9 的 `Path.is_relative_to`，在本机 3.8 暴露兼容错误，已改为兼容判断并复跑通过。这是本轮负结果，不掩盖为首次即通过。

该指纹不是原子快照、不是 toolchain receipt、更不具有发布授权。既有 ADK gitlink dirty 仍触发 L4，避免无依据降低集成门禁。

完整 Python 3.11 验证发现 E2 的第二个具体问题：`agent-dev-kit/tests/test_no_external_repo_refs.sh` 对 docs 逐字匹配外部仓名称；现有 `runtime-profile-health-and-compat-cleanup-v1/requirements.md:19` 明确要求“Codex source 不再导出”外部路径，仍被判为失败。建议针对 manifest/profile/workflow/导出物检查实际运行引用，对 change 中的移除说明记录为治理证据；需补“实际依赖拒绝、移除说明允许、读取失败非零”用例，不能通过删除需求证据或宽泛放行所有 docs 掩盖问题。该 ADK 变更未在本轮实施。

### 知识检索与历史经验复用

- [复用 runbook](../docs/runbooks/history-knowledge-reuse.md)：补齐全历史口径、parent/child 去重、canonical route、receipt/knowledge 区分及 miner owner handoff。
- [真实查询基线](knowledge-retrieval-baseline-2026-09-05.json)：四个登记正例均 rank 1；两个探索 query 中“回执 持久化”零命中，“温控”可由已登记正文命中。
- 这些样本是小规模、登记条目引导的基线，不能宣称整体 accuracy 100% 或检索性能提升。当前没有修改 Hub ranking、registry，也没有把原始历史导入团队资产。

### 交付可靠性与团队推广

- [团队试点](../docs/runbooks/team-pilot-acceptance.md)：安装、重复 setup、小修复与共享改动、生成失败、升级恢复、知识与任务交接六个场景，明确观测和失败判定。
- [M5 计划](../docs/software-m5-certification-plan.md)：删除漂移的旧版本声明、对齐当前 v5 合同与 state-dir，区分结构化逐任务结果和禁止归档的 raw 会话。
- v5 `eval campaign plan` 已在 `/tmp` 生成并解析出 `adk-runtime-eval-campaign-plan/v1`；仅证明本地计划入口可用，没有执行付费 campaign 或正式推广。

## 当前验证与风险

| 验证 | 结果 | 边界 |
|---|---|---|
| validation_plan 定向测试 | 16/16 pass | 本轮代码行为；真实临时 Git 父子仓 fixture |
| 根仓 regression | 21/24 | lock worktree、current-status、product-maturity 三项失败；指向既有 ADK identity 与过期运行证据，不是放行 |
| working-tree quick gate | 50/55 | lock、current-status、product-maturity、reference-dirty-triage、subrepo-state 失败 |
| ADK quick suite | 29/29 pass | 未修改 ADK 源；本机 development evidence |
| ADK strict | pass | Python 3.8.10，不能升级为 supported release evidence |
| 既有 supported-full receipt 复核 | rejected | 与当前 ADK snapshot 不同；没有复用旧 pass |
| Python 3.11.15 full | 67/68 | 外部引用检查命中既有移除说明；没有生成 supported-full pass receipt |
| doc-sync / AGENTS coverage / diff --check | pass | 新增知识/团队文档局部链接检查也通过 |
| 查询基线 JSON | 六条可解析 | 搜索执行真实；整体效果未测量 |
| 非仓库 cwd CLI help | pass | `/tmp` 通过显式 PYTHONPATH 调用现有模块 |

根仓已存在的 policy candidate 为 `12bfeaf...`，ADK worktree HEAD 为 `63f62e0...`；当前 source/identity 没有对齐。OpenSpec、superpowers、vibeflow baseline 已于 2026-08-31 到期。没有替用户改写这些 dirty、没有提交/推送、没有更新 live 或伪造 release identity。

维护性门禁仍为 pass；root report 已有 319 项、warning limit 为 320。churn、owner concentration、inactive assets 三项均为 not-available，不能据此宣称不存在冗余或认定哪些 Skill 应删除。应补真实受审输入并做引用/退役评审，避免每次审查新增平行的长期状态表。

长期结论以本报告作为 **reviewing candidate**；尚未作为 Hub 正式知识条目登记。活动回执只表示本轮事项持久化，不替代知识归档或团队试点证据。

## 下一轮恢复入口

1. 在既有 ADK lifecycle 改动边界明确后，先收口 D4 的 source 身份、lock/gitlink 和 fresh evidence；禁止把其它 dirty 一并提交。
2. 按 K1/K2 的 owner handoff 扩展 Codex source miner 与 Hub intake；复用六条查询基线，增加独立自然语言和负例。
3. 与真实第二操作者完成 T1–T6，并将可信观测接入现有 Effect Comparator；30 天和付费 campaign 仍按原 policy 验收。
