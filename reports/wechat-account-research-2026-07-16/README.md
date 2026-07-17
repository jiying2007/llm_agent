# 腾讯技术工程、阿里云开发者近半年 Agent 主题文章归档

## 结论

- 检索窗口：`2026-01-16` 至 `2026-07-16`（含首尾日期）。
- 目标公众号：`腾讯技术工程`、`阿里云开发者`。搜狗结果中后者也以别名 `阿里开发者` 出现，最终以微信正文页账号名为准。
- 实际调用 Hermes 的 `SogouSearcher -> LinkResolver -> ArticleFetcher -> ArticleAnalyzer -> ArticleClassifier` 链路，而不是只依赖通用网页搜索。
- 每个账号执行 21 组主题查询，每组读取前 10 条结果，共处理 420 条原始命中。
- 41 个去重候选进入正文级复核：19 篇满足“目标账号 + 日期窗口 + 可直接读取”，另有 1 篇由腾讯云官方镜像确认来源和日期，因此归档 20 篇。
- 归档不保存文章正文，只保存可复核元数据、内容 SHA-256、访问状态和选择理由。

这是一轮“多查询覆盖 + 账号正文复核”的系统性收集，不声称穷尽公众号后台全部历史。搜狗只返回排序结果页，且新文章存在索引延迟；因此本报告同时记录覆盖边界和未确认项。

## 归档元数据

- Topic：`external-articles/wechat-agent-engineering`
- Captured at：`2026-07-16`，`Asia/Hong_Kong`
- Primary seeds：用户提供的两篇微信短链，以及目标账号名、半年窗口和主题范围。
- Provenance：Hermes 搜狗微信检索、微信正文级核验、腾讯/阿里官方站点与公开定位镜像复核。
- Sanitization：不保存正文、临时签名 URL、凭证、Cookie、浏览器状态或原始会话；仅保存事实型元数据、哈希和原创短摘要。
- Memory candidate：`no`。本轮形成研究归档和后续吸收候选，不静默提升为 Agent 规则或 memory。
- Supersedes：`none`。
- Gate：归档和采集器源代码通过；不声明本机 Hermes live runtime 已部署。

## 搜索与核验方法

### 主题查询矩阵

基础查询共 12 组：

`LLM`、`大模型`、`Agent`、`智能体`、`Skill`、`Skills`、`Workflow`、`工作流`、`Profile`、`MCP`、`Hook`、`Harness`

扩展查询共 9 组：

`上下文工程`、`Agent 记忆`、`Token 优化`、`多 Agent`、`AI Coding`、`Agent 评测`、`Agent 安全`、`工具调用`、`RAG`

每个查询分别与两个账号名组合，形成 42 次搜狗微信检索。原始命中先按搜狗展示的来源账号过滤，再按规范化标题去重。对保留下来的候选重新执行精确标题搜索，解析搜狗跳转，并在微信正文页核验标题、账号和发布日期。

### 证据优先级

1. `hermes-direct-read`：Hermes 在微信正文页读到标题、账号、日期和正文；这是账号归属的主要证据。
2. `official-mirror-verified`：微信链接未在本轮解析成功，但腾讯云官方镜像明确标注来源账号和发布时间。
3. `locator-only`：第三方镜像或搜狗标题查询只帮助长期定位，不替代正文级账号核验。

微信经搜狗解析得到的 `src/timestamp/signature` 链接会过期，因此没有写入长期目录。两个用户提供的稳定短链接保留在目录中；其他文章优先使用公司官网、官方开发者社区或公开镜像作为定位入口。

### 覆盖数据

| 阶段 | 腾讯技术工程 | 阿里云开发者 | 合计 |
|---|---:|---:|---:|
| 主题查询数 | 21 | 21 | 42 |
| 原始命中 | 210 | 210 | 420 |
| 搜狗来源名精确命中 | 37 | 27 | 64 |
| 主批次去重候选 | 14 | 17 | 31 |
| 补充标题复核 | 3 | 7 | 10 |
| 微信正文直接确认 | 10 | 9 | 19 |
| 官方镜像补充确认 | 1 | 0 | 1 |
| 最终归档 | 11 | 9 | 20 |

41 次正文级复核的状态分布：

| 状态 | 数量 | 含义 |
|---|---:|---|
| `direct-read` | 19 | 账号、日期和正文均由微信页确认 |
| `out-of-window` | 8 | 账号正确，但发布日期早于窗口 |
| `account-mismatch` | 6 | 搜狗展示或检索命中与微信正文账号不一致 |
| `search-unresolved` | 8 | 精确标题搜索未获得可安全解析的目标结果 |

## 精选目录

优先级含义：

- `P0`：可直接转化为 `llm_agent`、`agent-dev-kit` 或 `~/codex` 的工程规则、Skill、Workflow、门禁或验证候选。
- `P1`：有生产案例或方法论价值，适合继续比对现有资产后吸收。
- `P2`：模型/研究动态，保留为参考，不应直接形成治理资产。

### 腾讯技术工程

| 日期 | 级别 | 文章 | 主题 | 为什么保留 | 核验 |
|---|---|---|---|---|---|
| 2026-07-16 | P0 | [Agent 治理：用 Hook 堵住 LLM 的偷懒、越权与失忆](https://mp.weixin.qq.com/s/ISwjIw5lj7JlcQJV7BOx5g) | Hook、权限、记忆、RAG、工具调用 | 将运行时 Hook 用于截断偷懒、权限边界、记忆与结果校验，和现有 Agent 治理高度相关 | Hermes 直读；用户给定稳定短链 |
| 2026-07-07 | P0 | [从 Vibe Coding 到 Harness——一套大仓 AI 工程化实战](https://www.lddgo.net/article/detail/vdd4) | Harness、Workflow、MCP、门禁 | 大仓阶段拆分、基线、脚本门禁和人工关卡可转化为执行/验证治理 | Hermes 直读；链接为定位镜像 |
| 2026-07-03 | P0 | [从 AI Coding 到 Harness Engineering 的端到端工程开发实践](https://www.lddgo.net/article/detail/6nn4) | Harness、Context、Agent、DAG | 状态文件、渐进式知识加载、专家 Agent 与 DAG 编排可补强长任务闭环 | Hermes 直读；链接为定位镜像 |
| 2026-04-20 | P0 | [从提需求到部署发布，全 AI 全自动化后，研发效能全面跃升](https://cloud.tencent.com/developer/news/3860908) | Multi-Agent、MCP、Skill、质量门禁 | 覆盖需求、方案、编码、测试、部署全链路，适合提取 L2/L3 分阶段门禁 | 腾讯云官方镜像确认；本轮微信解析未成功 |
| 2026-07-08 | P0 | [精打细算虾养成指南：省 Token 和把 AI 用好，从来就是一件事](https://cloud.tencent.com/developer/news/4219098) | Token、Context、Subagent | JIT 上下文、分阶段会话和主/子 Agent 分工可优化 token-lean profile | Hermes 直读；腾讯云镜像作稳定入口 |
| 2026-03-13 | P0 | [Skills 开发技能指南：OpenClaw 也好，Skills 也好，都别脱离具体场景谈方案](https://www.gm7.org/archives/53058) | Skill、MCP、Context | 强调场景建模、渐进披露和“借鉴后改造”，与现有吸收治理直接契合 | Hermes 直读；链接为定位镜像 |
| 2026-03-27 | P1 | [腾讯广泛使用的跨端开发框架——Kuikly 在搜狗输入法中的 AI Coding 实践](https://zhuanlan.zhihu.com/p/2020890460856524971) | AI Coding、Skill、MCP、评测 | 提供真实团队将规则、工具和评测接入开发流程的案例 | Hermes 直读；链接为定位镜像 |
| 2026-03-04 | P1 | [鹅厂员工怎么看 Agent 自动持续进化？](https://cn-sec.com/archives/5060532.html) | Memory、Evaluation、Human-in-loop | 反馈闭环、黄金评测集、记忆和人工守门可转化为演进门禁候选 | Hermes 直读；链接为定位镜像 |
| 2026-03-25 | P1 | [鹅厂员工的龙虾都长什么样？](https://weixin.sogou.com/weixin?type=2&query=%E9%B9%85%E5%8E%82%E5%91%98%E5%B7%A5%E7%9A%84%E9%BE%99%E8%99%BE%E9%83%BD%E9%95%BF%E4%BB%80%E4%B9%88%E6%A0%B7) | Skill、Workflow、安全 | 内部使用形态可作为场景盘点材料，但方法深度低于 P0 | Hermes 直读；搜狗标题定位 |
| 2026-07-06 | P2 | [腾讯混元 Hy3 发布：Agent 能力和产品体验跃升](https://www.tencent.com/zh-cn/tencent-hunyuan-officially-releases-hy3-advancing-agent-capabilities-and-deeper-product-integration/) | LLM、Agent、工具调用 | 用于跟踪模型与 Agent 产品能力，不直接吸收为治理规则 | Hermes 直读；腾讯官网作稳定入口 |
| 2026-07-16 | P2 | [腾讯 PCG 联合深圳河套学院：在全双工语音大模型领域取得重要突破，获 ACL 2026 杰出论文奖](https://weixin.sogou.com/weixin?type=2&query=%E8%85%BE%E8%AE%AFPCG%E8%81%94%E5%90%88%E6%B7%B1%E5%9C%B3%E6%B2%B3%E5%A5%97%E5%AD%A6%E9%99%A2%20ACL%202026) | LLM、语音、研究 | 属于 LLM 研究动态，与 Agent 工程吸收的关联较弱 | Hermes 直读；搜狗标题定位 |

### 阿里云开发者

| 日期 | 级别 | 文章 | 主题 | 为什么保留 | 核验 |
|---|---|---|---|---|---|
| 2026-07-15 | P0 | [数据研发 Multi-Agent 架构的 Harness 工程实践](https://mp.weixin.qq.com/s/9ikvuGaAJSPyGYidbAdC7g) | Multi-Agent、Harness、Workflow、评测 | 身份、执行、演进分层及 Harness 支柱可用于审视 ADK 的运行闭环 | Hermes 直读；用户给定稳定短链 |
| 2026-04-01 | P0 | [Agent Skills：打通可复用专业领域知识的最后一公里](https://developer.aliyun.com/article/1722841) | Skill、MCP、Workflow | Skill 包结构、可复用领域知识和版本治理适合与现有 Skill SSOT 比对 | Hermes 直读；阿里云开发者社区入口 |
| 2026-02-26 | P0 | [AI Agent 系列：深入解析 Function Calling、MCP 和 Skills 的本质差异与最佳实践](https://developer.aliyun.com/article/1713530) | Function Calling、MCP、Skill | 明确工具调用、协议接入和程序性知识的边界，可改善路由与资产分层 | Hermes 直读；阿里云开发者社区入口 |
| 2026-01-30 | P0 | [AI Agent 记忆系统：从短期到长期的技术架构与实践](https://developer.aliyun.com/article/1704117) | Memory、Context、RAG | 短期/长期记忆的 record-retrieve 生命周期适合审计 context/memory 治理 | Hermes 直读；社区镜像日期与微信转载日期不同 |
| 2026-03-20 | P0 | [企业级 Agent 多智能体架构与选型指南](https://developer.aliyun.com/article/1719997) | Routing、Handoff、Supervisor、Skill | 提供 Pipeline、Routing、Handoff、Subagent、Supervisor 的场景化选型框架 | Hermes 直读；阿里云开发者社区入口 |
| 2026-03-02 | P0 | [打造高可靠 AI 助手：Skill 编排、Workflow 设计与 Spec Coding 的深度实践](https://developer.aliyun.com/article/1714719) | Skill、Workflow、Spec Coding | 单职责 Skill、显式 Workflow 和结构化初始化可补强需求到执行的契约 | Hermes 直读；阿里云开发者社区入口 |
| 2026-02-14 | P0 | [准确率提升至 90%，阿里商旅基于 AgentScope 构建多智能体差旅助手最佳实践](https://agentscope.io/blog/alibaba-business-travel/) | Multi-Agent、Routing、Handoff、Context | 生产案例给出架构取舍、上下文分层、快慢路由及效果指标 | Hermes 直读；AgentScope 官方博客入口 |
| 2026-03-30 | P1 | [学习笔记：从 Agent 到 Skills——AI 智能体架构的范式转变](https://developer.aliyun.com/article/1723783) | Skill、MCP、A2A、模块化 | 可作为薄 Agent 与组合式 Skill 的趋势参考，但部分行业断言需原始来源复核 | Hermes 直读；阿里云开发者社区入口 |
| 2026-02-05 | P1 | [自动化评测的九九归一——评测 Agent](https://developer.aliyun.com/article/1710689) | Evaluation、数据闭环 | 评测集生成、自动打分、验收和 badcase 分析可映射为验证闭环 | Hermes 直读；阿里云开发者社区入口 |

机器可读记录见 [`catalog.jsonl`](catalog.jsonl)，覆盖统计和运行边界见 [`evidence-summary.json`](evidence-summary.json)。

## 排除与负面证据

### 日期越界

8 篇账号匹配但不在半年窗口内，包括：

- 腾讯的 PAG 动效（2023）、混沌工程（2019）、混元首次亮相（2023）、腾讯文档 AI 助手（2024）。
- 阿里的设计模式 Hooks（2021）、AI 应用工程架构（2023）、bpftrace Hook（2024）、大模型与大数据平台（2024）。

这些结果说明只搜 `Hook`、`Workflow` 或 `大模型` 会大量召回词面相关但时间不合格的旧文，不能直接进入归档。

### 账号错配

6 篇正文账号与目标账号不一致，包括 `腾讯低代码`、`技术原始积累`、`AI大玩家Eddie`、`互联网游侠`、`DataFunSummit`、`阿里云云栖号`。它们即使主题高度相关，也没有计入两个目标公众号。

### 未解析与主题空档

- `Profile` 未发现符合“目标账号 + 日期窗口 + 正文可核验”的专门文章。
- `Hook` 的有效主线集中在腾讯的 Agent 治理文章；阿里检索到的 React/bpftrace Hook 属于旧文或非 LLM Agent 语义。
- `ABACI 内核缺陷智能体`、`构建会思考的测试 Agent`、腾讯混元 `CL-bench` 等精确标题在本轮搜狗链路中未安全解析，因此没有凭标题猜测纳入。
- 阿里云官网近期还有 Agent Toolkit、Cloud Agents × Skills、可观测 Skills 等文章，但未核验为 `阿里云开发者` 微信正文，本报告只列为后续官网专题候选，不混入公众号结果。

## 合规与后续使用边界

- 未保存、复制或改写文章正文；`catalog.jsonl` 只包含事实型元数据和本次研究形成的简短选择理由。
- 内容哈希仅用于重复检测和证据一致性，不用于重建正文。
- 第三方镜像只作定位入口；吸收决策应优先回看微信正文、公司官网或原始技术文档。
- 本报告是研究与候选归档，不等于已吸收到 `agent-dev-kit`。后续应先与现有 Skill、Workflow、Profile、Hook 和验证门禁做重复/冲突/冗余比对。
- 下一轮增量采集建议复用同一查询矩阵，仅抓取上次日期之后的新文，并对 `search-unresolved` 候选做人工或官方镜像复核，不应绕过验证码、轮换代理或保存受版权保护的全文。
