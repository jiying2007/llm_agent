# 微信公众号归档实践对 Codex、llm_agent 与 agent-dev-kit 的优化评估

## 1. 结论

本轮 20 篇文章和 Hermes 实跑证据支持一个净新增能力：在 `~/codex` 增加“指定公众号 × 日期窗口 × 技术主题”的批量研究归档 Skill/Workflow，并提供确定性 `plan -> collect -> report -> check` 工具链。

对 `agent-dev-kit`，本轮没有发现值得新建平行 Skill 或改变 core 架构的缺口。Harness、Context/Token、Memory、Skill/Workflow、Multi-Agent、评测与 Hook 运行态治理已经由现有 Skill、manifest、runbook 和脚本门禁覆盖，而且多数比文章观点更严格。正确优化是保留“不重复吸收”证据，而不是为了体现吸收而扩张资产。

对 `llm_agent`，值得增加顶层意图路由和维护说明，使“公众号研究归档”与“文章吸收落地”成为两个连续但不混淆的阶段：前者生成 `review-required` 证据包，后者才做 `ADOPT / MERGE / ENHANCE / REJECT / REFERENCE_ONLY` 决策。

## 2. 目标、范围与非目标

### 目标

1. 将 Hermes 已验证的搜狗发现、微信正文核验和元数据归档方法，压实为 `~/codex` 可发现、可复跑、可验证的正式资产。
2. 保留 Hermes 索引作为只读输入兼容，同时允许在没有索引时使用受限 `agent-browser` 公共读取。
3. 对 20 篇文章逐篇映射现有资产，只有存在真实缺口时才实施改变。

### 非目标

- 不复制 Hermes 的全文归档、代理池、UA 轮换、反爬绕过、自动删文、AI 自动评级或后台 cron 行为。
- 不把文章正文写入 `~/codex`、`~/.codex`、Knowledge Hub、memory 或 ADK。
- 不把搜索命中、第三方镜像或文章热度当作账号归属或采纳依据。
- 不新增 ADK Hook、Harness、Memory、Multi-Agent 或 Skill 组合的同义资产。

### 成功标准

- `~/codex` 有版本化 Skill、`agents/openai.yaml`、单层 reference、manifest skill、workflow、workflow recipe、eval suite、Python 工具、shell 入口和单元测试。
- 从非 `~/codex` cwd 能执行 `--help`、`plan --dry-run`、离线 Hermes index 过滤、报告和证据检查。
- source-to-live 链路完成后，`~/.codex` 可发现该 Skill；当前线程不假设 catalog 自动刷新。
- `llm_agent` 的入口规则能区分“采集归档”和“吸收落地”。
- 逐篇评估表给出既有资产、决策、落点和拒绝重复的理由。

## 3. 现有能力与缺口

| 能力 | 现有资产 | 覆盖情况 | 决策 |
|---|---|---|---|
| 单篇微信文章浏览 | `~/codex/.../browser-reader/0.1.0` | 只允许单页、人工验证、禁止批量抓取 | 保留；不扩大职责 |
| 多来源检索 | `multi-search-engine` | 有来源质量、日期和交叉验证，但无账号/窗口/正文核验账本 | 作为支持 Skill |
| 外部实践吸收 | `external-practice-absorption` | 已定义逐项映射、最小改动和拒绝重复 | 作为吸收阶段主 Skill |
| 知识归档 | `adk-knowledge-archive` | 已定义脱敏、provenance、archive-only 边界 | 作为审查后的归档出口 |
| 公众号批量研究 | 无独立资产 | 缺账号别名、查询矩阵、日期门、正文账号核验、负状态、内容哈希和增量复跑 | **ADOPT 新 Skill/Workflow** |
| Harness Engineering | `docs/harness-engineering-analysis.md`、planning loop、artifact/completion gates | 已有状态外化、deterministic/approval/advisory 分级和机械化门禁 | 不新增 ADK 资产 |
| Token/Context | `adk-context-engineering`、`adk-token-context-governance`、对应 runbook | 已有渐进披露、按需加载、raw fallback、分层摘要和上下文隔离 | 不新增 ADK 资产 |
| Memory | `memory-governance.md`、`adk-memory-curator`、context state contracts | 已有短/长期边界、候选写入、检索、遗忘、审查和回退 | 不新增 ADK 资产 |
| Skill/Workflow/Subagent | runtime router、skill composition governance、runtime model | 已有 primary/supporting/fallback、互斥、渐进披露、硬门禁和最低充分抽象 | 不新增 ADK 资产 |
| Multi-Agent | parallel governance、worker contract、workflow routes | 已有 scope、权限、上下文隔离、supervisor/worker 责任和整合验证 | 不新增 ADK 资产 |
| Evaluation | test strategy、verification-before-completion、eval/trace manifests | 已有 claimant/verifier 分离、负例、回归、trace eval 和 promotion gate | 不新增 ADK 资产 |
| Hook | `hooks_runtime_audits.json`、security runbook、Codex `hook_contracts.json` | 已有事件支持、trust、输出字段、日志脱敏、deny-path 和回滚 | 不新增 Hook runner 或 Skill |

## 4. 逐篇评估

| ID | 文章 | 可复用机制 | 现有等价资产 | 决策 | 本轮动作 |
|---|---|---|---|---|---|
| T01 | Agent 治理：用 Hook 堵住 LLM 的偷懒、越权与失忆 | 事件点校验、权限/完成/记忆边界 | ADK runtime hook audit、completion gate、security runbook | MERGE | 新采集工作流采用显式负状态和 stop-on-gate；不建新 Hook Skill |
| T02 | 从 Vibe Coding 到 Harness——一套大仓 AI 工程化实战 | 阶段拆分、基线、脚本门禁、人工关卡 | planning loop、artifact gating、worktree/parallel governance | REFERENCE_ONLY | 现有机械门禁更完整 |
| T03 | 从 AI Coding 到 Harness Engineering 的端到端工程开发实践 | 状态文件、渐进知识、专家 Agent、DAG | planning state、context governance、parallel governance | MERGE | 新工作流外化 plan/run-summary/evidence；ADK 不改 |
| T04 | 从提需求到部署发布，全 AI 全自动化后研发效能跃升 | 分阶段演进、工具链、质量门 | feature/adk delivery workflows | REFERENCE_ONLY | 已有 propose/apply/verify/review/archive 闭环 |
| T05 | 精打细算虾养成指南 | JIT 上下文、会话分段、主/子 Agent 分工 | token/context governance、context handoff | REFERENCE_ONLY | 现有 raw fallback 与风险门更严格 |
| T06 | Skills 开发技能指南 | 场景优先、渐进披露、借鉴后改造 | skill lifecycle、composition governance | REFERENCE_ONLY | 已有 reuse-before-rebuild 和触发回归 |
| T07 | Kuikly AI Coding 实践 | 团队规则、工具、评测接入开发流程 | delivery workflow、test strategy | REFERENCE_ONLY | 属案例证据，无新通用合同 |
| T08 | Agent 自动持续进化 | 反馈闭环、黄金集、Human-in-loop、Memory | prompt experiments、eval suites、memory governance | REFERENCE_ONLY | 已有 promotion/owner review，禁止自动自改 |
| T09 | 鹅厂员工的龙虾形态 | 场景盘点与安全意识 | intake workflow、runtime model | REFERENCE_ONLY | 深度不足，不形成规则 |
| T10 | 混元 Hy3 发布 | 模型/Agent 能力动态 | official freshness/reference governance | REFERENCE_ONLY | 时间敏感，不形成 durable guidance |
| T11 | 全双工语音大模型 ACL 论文 | LLM 研究动态 | research archive | REFERENCE_ONLY | 与 Agent 工程治理关联弱 |
| A01 | 数据研发 Multi-Agent Harness 工程实践 | 身份、执行、演进分层；Harness 支柱 | runtime model、planning/parallel/eval gates | MERGE | 新工作流显式分 plan/collect/report/check；ADK 不改 |
| A02 | Agent Skills 最后一公里 | 领域知识包、脚本/模板、版本治理 | skill format/lifecycle/manifest SSOT | REFERENCE_ONLY | 已完整覆盖 |
| A03 | Function Calling、MCP 与 Skills | 工具调用、协议、程序性知识分层 | runtime model、MCP governance、skill composition | REFERENCE_ONLY | 文章部分观点有争议，现有边界更中性 |
| A04 | Agent 记忆系统 | record/retrieve、短/长期记忆 | memory governance、context state contracts | REFERENCE_ONLY | 已覆盖写入、检索、遗忘、审计和 scope |
| A05 | 企业级多智能体架构选型 | Pipeline、Routing、Handoff、Supervisor、Skill | runtime router、workflow routes、parallel governance | REFERENCE_ONLY | 已有 primary/supporting/fallback 和隔离合同 |
| A06 | Skill/Workflow/Spec Coding 高可靠助手 | 单职责 Skill、显式 Workflow、结构化初始化 | requirements triage、task breakdown、skill composition | REFERENCE_ONLY | 已有输入/输出/失败/验证契约 |
| A07 | AgentScope 商旅生产案例 | 快慢路由、上下文分层、效果指标 | runtime routes、eval/pilot evidence | REFERENCE_ONLY | 框架专用实现不进入 ADK core |
| A08 | 从 Agent 到 Skills 学习笔记 | 薄 Agent、组合式 Skill、协议分层 | runtime model、skill composition | REFERENCE_ONLY | 趋势及数字断言需原始来源复核 |
| A09 | 自动化评测的九九归一 | 评测集生成、打分、验收、badcase | test strategy、claimant/verifier、eval/trace contracts | MERGE | 新目录保持 `review-required`，采集器不得自评自采纳；ADK 不改 |

决策汇总：`MERGE=4`、`REFERENCE_ONLY=16`。净新增 `ADOPT=1` 是跨文章与 Hermes 实跑共同证明的“公众号账号研究归档工作流”，不是把单篇文章观点提升为规则。

## 5. Hermes 流水线吸收与拒绝矩阵

| Hermes 能力 | 决策 | Codex 适配 |
|---|---|---|
| 搜狗批量查询与账号别名 | ADOPT | 有限查询矩阵和硬上限 |
| 搜狗跳转解析、微信正文账号/日期核验 | ADOPT | `agent-browser` 只读；遇 gate 立即停止 |
| 标题规范化、去重、内容哈希 | ADOPT | 正文驻留内存，落盘只存 SHA-256 和统计 |
| Hermes `articles.json` | ADOPT | 只读 discovery adapter，不回写 Hermes |
| 负状态与增量复跑 | ENHANCE | 统一 `direct-read/account-mismatch/out-of-window/.../access-gated`；`--resume` 按 candidate key 跳过 |
| 正文 Markdown 全量归档 | REJECT | 版权和 token 风险；目录只保存元数据 |
| 代理池、UA 随机轮换、“绕过反爬” | REJECT | 与 Codex 浏览器安全边界冲突 |
| CAPTCHA 后冷却并自动重试 | REJECT | access gate 是终止状态，不是重试信号 |
| 启发式/AI 自动质量评级 | REJECT AS GATE | 长度/结构分数易误判；只输出 review-required 候选 |
| 自动删除 D 级文章 | REJECT | 禁止自动破坏归档和隐藏负证据 |
| 后台 cron 自动运行 | REJECT BY DEFAULT | 若未来需要，另走 automation manifest，默认 disabled/report-only |

## 6. 设计

### Codex 资产

```text
src/codex-home/vendor/skills/wechat-account-research/0.1.0/
├── SKILL.md
├── agents/openai.yaml
└── references/evidence-contract.md

tools/codex_assets/wechat_archive.py
scripts/wechat-archive.sh
tests/test_wechat_archive.py
```

声明式入口：

- `manifests/skills.json`：登记 deferred local skill。
- `manifests/workflows.json`：增强 `external-research`，新增批量公众号 route，并保留单篇 `browser-reader` 边界。
- `manifests/workflow_recipes.json`：登记账号、窗口、查询预算、证据包和失败状态契约。
- `manifests/eval_suites.json`：绑定单元测试、治理检查和负例门禁。

工具动作：

1. `plan`：无网络生成账号 × 主题查询矩阵。
2. `collect`：使用 Hermes index 或受限 public browser，正文只驻留内存。
3. `report`：生成 metadata-only `catalog.jsonl`、`coverage.json` 和 `README.md`。
4. `check`：禁止正文、Cookie、session、签名 URL；核对日期、账号、hash 和计数。

### llm_agent 资产

- 根 `AGENTS.md` 增加“公众号研究归档”意图路由。
- `docs/llm-agent-maintenance-guide.md` 增加采集、审查、吸收分层和最小命令链。
- 本报告作为逐篇吸收证据；不直接修改 adoption matrix，因为公众号材料不是正式受治理子仓。

### agent-dev-kit 决策

- 不修改 core/optional skill、manifest 或 workflow。
- 不把 `~/codex` 的浏览器采集 runtime 反向导入 ADK。
- 若未来出现新的平台中立合同缺口，先走 `skill-curation-delivery`；本轮证据不足以新增资产。

## 7. 任务与验证

| Task | 产物 | Verify |
|---|---|---|
| C1 Skill scaffold 与证据 reference | 版本化 Skill 目录 | `quick_validate.py <skill>` |
| C2 确定性 CLI | Python module + shell wrapper | `unittest`、`py_compile`、非仓库 cwd `--help/plan` |
| C3 声明式路由 | skill/workflow/recipe/eval manifests | governance doctor、routing precedence、skill search |
| C4 llm_agent 路由 | AGENTS + maintenance guide | doc sync、agents coverage |
| C5 source-to-live | build/doctor/plan/dry-run/apply/check | 完整 Codex 链路与 live skill 文件核验 |
| C6 完成门禁 | `optimization-verification.md` 和 Hub candidate | final-ready、三仓状态与风险说明 |

## 8. 风险、回退与停止条件

- `~/codex` 当前已有大量用户 dirty 变更；只在当前内容上追加独立项，不回退、重排或清理既有变更。
- apply plan 若显示与本任务无关的 overwrite/delete，停止 apply 并报告；不得用 `--overwrite` 掩盖漂移。
- 搜狗或微信出现 access gate，采集命令以 partial 状态结束，不尝试绕过。
- manifest/schema/路由检查连续失败两次则回到设计，不继续叠加修复。
- 回退仅撤销新增 Skill、CLI、测试、manifest 条目和 llm_agent 路由；不影响 Hermes 原始数据和 ADK。
