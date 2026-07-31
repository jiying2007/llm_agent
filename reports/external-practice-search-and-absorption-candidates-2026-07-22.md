# llm_agent / agent-dev-kit 外部实践全面搜索与吸收候选

- 日期：2026-07-22
- 状态：`review-required`
- 决策边界：本文仅给出研究建议，不构成 `ADOPT` 决策，不授权修改 `agent-dev-kit`、采纳矩阵或运行时资产。
- 搜索健康：`degraded`。统一 intake 共得到 118 条候选并去重 1 条；GitHub 30、GitLab 0、Gitee `degraded-empty`、OpenAI 官方 64、Anthropic 官方 5、微信公众号治理目录 20。
- 目标：找出相对当前实现仍有独立增量的实践，明确可吸收部分、不可迁移部分、目标资产、验证方式和阻塞条件。

## 1. 结论

当前不应继续以“增加 Skills、Agent 或编排框架数量”为主要优化方向。`agent-dev-kit` 已具备 13 个 Agent、55 个 core Skill、10 个 optional Skill、9 个 profile、7 个 workflow；已有的路由、上下文、验证、并行、worktree、供应链、MCP、trace/eval 和发布治理覆盖面较完整。

真正的增量集中在四个证据缺口：

1. **真实仓库执行证据**：现有 Software M5 campaign 的 60 条任务用于路由与安全分类，不等价于在隔离仓库中完成编码、测试和修复。
2. **通过后的过程质量**：仅看最终测试通过会漏掉盲目重试、回归后侥幸恢复、跳过验证和阶段乱序。
3. **成本与现场效果分布**：当前已有预算和 usage ratio，但还缺跨 trial 的 p50/p95/max、cost-per-success、并发 Agent 人工时间归一化和选择偏差记录。
4. **新规范与技能供应链变化**：MCP 2026-07-28 尚处 RC 窗口；OWASP Agentic Skills Top 10 尚未成为稳定发布标准，适合先做兼容/差距候选，不宜直接改 core contract。

建议把后续工作压缩为三个独立 change：

- `repository-runtime-campaign-v1`：真实仓库任务、隔离 baseline、过程质量、成本分布、安全 canary。
- `mcp-2026-07-28-compat-review`：待最终规范发布后再冻结版本和迁移边界。
- `field-evidence-v2`：第二 operator、真实仓库、人工时间与选择偏差的可审计试点协议。

## 2. 当前基线与已验证缺口

### 2.1 已有能力

- `devkit validate --strict` 通过：13 Agent、55 core Skill、10 optional Skill、9 profile、7 workflow。
- `target check --all --level static` 的 3 个 target 全部通过静态检查，但 `claude-code`、`hermes-agent`、`opencode` 的 `contract_status` 仍为 `experimental`。
- Software M5 contract 已固定 `baseline/adk`、Codex/Claude、每条件 3 次 trial、预算、重试、成功率、route/safety、P95 latency 和 usage ratio。
- 已有 effect eval、trace eval、供应链、安全、SBOM/provenance、OOD 和 clean-clone 门禁；OpenAI、Anthropic、Agent Skills、OWASP Agentic Top 10、MCP Registry、OTel GenAI、SWE-bench 等大量通用实践已被采纳或进入观察。

### 2.2 仍然存在的硬阻塞

`software-m5.sh status --summary-json` 当前仍被以下证据阻塞：

- `final_version`
- `independent_repository`
- `operator_count`
- `pilot_duration`
- `real_repository_count`
- `required_field_events`
- `runtime_campaign`

当前 field evidence 只有 2 个事件、1 个 field event、1 个真实仓库、0 个独立仓库、1 名 human operator、0 天独立 pilot。现状最多支持 “M5-ready control-plane candidate”，不支持 M5 certified 声明。

### 2.3 现有 campaign 的语义边界

`agent-dev-kit/tests/fixtures/software_m5_eval_tasks.jsonl` 的 60 条记录字段为 `prompt/category/expected_skill/expected_safe`，运行时目标是选择 Skill 并判断是否可安全执行。它能证明路由和安全决策，不证明：

- 能否在真实仓库完成多文件修改；
- 功能测试、安全测试和回归是否同时通过；
- Agent 是否出现无效循环、盲目重试或遗漏最终验证；
- ADK 相比 runtime 原生能力是否改善真实任务结果。

## 3. 优先吸收候选

以下状态均为**研究建议**，须经过独立 owner decision 后才能进入 `ADOPT`。

| 优先级 | 候选 | 建议状态 | 独立增量 | 推荐目标 |
|---|---|---|---|---|
| P0 | Inspect SWE repository-runtime adapter | `CANDIDATE-ENHANCE` | 在沙箱仓库中运行 Codex CLI、Claude Code、Gemini CLI、OpenCode 等，补真实编码结果与 transcript | 新建独立 repository-runtime campaign contract；不要替换现有 routing campaign |
| P0 | AgentLens 过程质量指标 | `CANDIDATE-ENHANCE` | 识别“测试通过但过程失真”的 lucky pass | 扩展 trace/effect eval 指标与负向 fixture |
| P0 | Runtime customization isolation | `CANDIDATE-ENHANCE` | 让 baseline 真正关闭 ADK/Skills/Hooks/MCP，而不只是换 prompt catalog | target-specific campaign adapter 与可比性声明 |
| P0 | MCP 2026-07-28 compatibility review | `CANDIDATE-OBSERVE` | 新版本涉及 stateless core、extensions、Tasks、Apps、auth、弃用机制和 JSON Schema 2020-12 | 先建 migration candidate；最终规范发布并复核后再决定 |
| P1 | SWE-bench-Live freshness canary | `CANDIDATE-ENHANCE` | 月度更新、多语言、多 OS，降低固定 benchmark 污染 | 5–10 条冻结 digest 的 canary，不引入全量运行 |
| P1 | Secure coding canary | `CANDIDATE-ENHANCE` | 同时要求功能正确和安全，不接受“安全但不可用”或“功能通过但有漏洞” | 从 SecCodeBench/SecureVibeBench clean-room 派生少量 fixture |
| P1 | Token/cost distribution metrics | `CANDIDATE-ENHANCE` | 捕获同任务跨 trial 的 30x 级波动风险和 cost-per-success | Software M5 result schema 与报告，不信任 Agent 自报预算 |
| P1 | Field pilot experiment design | `CANDIDATE-ENHANCE` | 任务预注册、human baseline、选择/拒绝日志、并发 Agent 人工时间归一化 | `adk-production-field-readiness` 和 M5 field evidence |
| P1 | OWASP Agentic Skills Top 10 crosswalk | `CANDIDATE-OBSERVE` | 对 Skill 层恶意载荷、过权、metadata、隔离、漂移建立显式映射 | 供应链检查表和 security fixture；不采用其通用格式提案 |
| P2 | Agent Skills 维护证据 | `CANDIDATE-ENHANCE` | 区分稳定行为契约与 target-local binding，记录上游 revision、使用效果和退役证据 | skill manifest/governance 增量，不扩大 core Skill 数量 |
| P2 | VS Code / GitHub Copilot target | `CANDIDATE-OBSERVE` | `.agents/skills`、`.github/skills` 和 forked context 可作为 target conformance 新样本 | 仅观察；没有真实 use case 和 smoke evidence 时不新增 direct target |

### 3.1 Inspect SWE：作为可选 adapter，不成为核心依赖

英国 AI Security Institute 的 Inspect 支持在 sandbox 中评估 tool-using Agent；Inspect SWE 提供 Claude Code、Codex CLI、Gemini CLI、OpenCode 和 Mini SWE Agent 的 adapter，并把 API 调用、token/time limit 和 transcript 纳入 Inspect 记录。[Inspect coding-agent tutorial](https://inspect.aisi.org.uk/tutorial.html)、[Inspect SWE 文档](https://meridianlabs-ai.github.io/inspect_swe/)、[Inspect SWE 仓库](https://github.com/meridianlabs-ai/inspect_swe)

可吸收：

- 统一 sample sandbox、runtime adapter 和 transcript contract；
- `eval_set` 的 retry/resume、time/message/token/cost 上限；
- 在同一 task/revision/model/sandbox 下比较 baseline 与 ADK；
- 把真实测试结果、修改 diff、失败类型和资源消耗写入 evidence。

不可直接迁移：

- 不把 Inspect/Inspect SWE 变成 ADK core runtime 或必装依赖；
- 不默认执行来自外部 benchmark 的任意容器、安装脚本或仓库命令；
- 不复用其 credential forwarding 默认值；必须维持 deny-path、最小网络和短期凭证；
- 需要固定版本与 digest，并独立审查 MIT 主项目之外的传递依赖和各任务许可证。

建议验收：至少两个 runtime、5–10 个冻结任务、baseline/adk 各 3 次 trial；结果必须含仓库 revision、container digest、runtime/model version、完整测试 oracle、token/cost、attempt、trace 和失败分类。

### 3.2 AgentLens：加入“通过但过程不合格”门禁

Microsoft Research 对 2,614 条 OpenHands trajectory 的分析显示，在其检查的通过轨迹中，10.7% 仍包含回归循环、盲目重试、缺少验证或阶段乱序；加入过程质量后，系统排名最多可变动 5 位。[AgentLens 论文页](https://www.microsoft.com/en-us/research/publication/agentlens-revealing-the-lucky-pass-problem-in-swe-agent-evaluation/)

建议抽取方法，不导入框架：

- `regression_cycle_count`
- `blind_retry_count`
- `missing_final_verification`
- `phase_order_violation`
- `pass_with_invalid_process`
- `repeated_tool_call_without_new_evidence`

最终 outcome 通过但 `pass_with_invalid_process=true` 时，报告应降级为 `pass-with-warning` 或按安全级别 fail closed，不能只计入成功率。

### 3.3 Runtime safe mode：强化已有 baseline，而不是重做 baseline

现有 M5 已声明 `baseline/adk`，但 baseline 主要体现为通用 category prompt。Anthropic 新增 `--safe-mode` / `CLAUDE_CODE_SAFE_MODE`，可关闭 `CLAUDE.md`、plugins、Skills、Hooks 和 MCP，适合作为 Claude target 的真实 customization isolation 证据。[Claude Code releases](https://github.com/anthropics/claude-code/releases)

建议：

- baseline 必须记录实际关闭了哪些 customization surface；
- ADK condition 只打开本次受测 profile 所需资产；
- runtime 不支持可靠隔离时标记 `comparison_status=not-comparable`；
- target-specific safe mode 只留在 adapter，不提升为平台中立 core semantic。

### 3.4 SWE-bench-Live：只吸收新鲜度和多环境 canary

Microsoft SWE-bench-Live 持续更新真实 issue，覆盖多语言、多 OS；2026-05 数据包含 743 个 MultiLang task、6 种语言、381 个仓库，以及 Windows 子集。其 README 同时明确提醒 gold patch 重复执行和高资源消耗问题。[SWE-bench-Live](https://github.com/microsoft/SWE-bench-Live)

可吸收：

- `created_at/retrieved_at/repo_revision/task_digest` 新鲜度字段；
- Linux/Windows、Python/非 Python 的小型 canary 分层；
- gold patch 至少三次稳定性复核；
- contamination/known-task 标记。

不可直接迁移：全量 dataset、任意 task container 和高资源默认配置。ADK 应选择小样本、固定 digest、逐任务许可证审查，并把它与内部 OOD suite 分开报告。

### 3.5 安全编码 canary：功能优先，再判安全

SecCodeBench v2.2.0 提供 98 个、覆盖 5 种语言和 22 个 CWE 的任务，采用“先功能、后安全”的分层判断并支持主流 coding CLI；其框架为 Apache-2.0，但完整运行有显著 token 和容器成本。[SecCodeBench](https://github.com/alibaba/sec-code-bench)

SecureVibeBench 提供 105 个来自 41 个 OSS-Fuzz 项目的 C/C++ 多文件任务，组合功能测试与静态/动态安全 oracle；论文报告最佳受测组合也只有 23.8% 同时正确且安全。[SecureVibeBench](https://aclanthology.org/2026.acl-long.1107/)

建议只 clean-room 派生 3–5 个 canary：

- 至少覆盖 injection/path traversal、unsafe deserialization、memory safety 或 dependency misuse；
- 必须先通过功能测试，再执行动态 exploit 或高置信静态 oracle；
- 记录 CWE、严重度、误报处理和安全失败是否由 Agent 新引入；
- 不引入 LLM-as-a-Judge 作为唯一安全 oracle；
- 不在常规 quick check 中启动不受信 Docker workload。

### 3.6 Token/cost：从单一 ratio 扩展到分布

Microsoft Research 的 agentic coding 成本研究指出，同一任务的 token 消耗可出现最高约 30 倍差异，消耗更多 token 不必然带来更高正确率，Agent 自身的成本预测也不可靠。[How Do AI Agents Spend Your Money?](https://www.microsoft.com/en-us/research/publication/how-do-ai-agents-spend-your-money-analyzing-and-predicting-token-consumption-in-agentic-coding-tasks/)

建议新增：

- input/output/cached token 的 p50、p95、max；
- `cost_per_success`、`cost_per_verified_change`；
- 同 task 跨 trial 的 coefficient of variation；
- retries、rounds、timeout、tool-call count；
- budget breach 必须来自 runtime/provider 观测，不接受 Agent 自报替代。

### 3.7 Field pilot：避免自选任务与自报时间偏差

METR HCAST 使用 189 个由人类时间校准的任务、算法评分和多阶段 QA，提供了任务难度与人类基线的可审查方法。[HCAST](https://metr.org/hcast.pdf) METR 后续研究还说明，参与者/任务选择和并行 Agent 下不可靠的时间测量会显著扭曲生产率结论。[METR uplift update](https://metr.org/blog/2026-02-24-uplift-update/) DORA 2025 的组织研究也强调，AI 更像放大既有工程系统，而不是单独决定结果。[DORA 2025](https://dora.dev/research/2025/dora-report/)

建议给现有 M5 field evidence 增加：

- 任务预注册与拒绝/跳过原因；
- human-only baseline 或有依据的人类估时；
- wall-clock、human-active time、agent-active time 分离；
- 并发 Agent 数和并发重叠区间；
- operator、repo、task family 分层；
- 置信区间和失败案例，不只报平均改善；
- 不以自报“完成”替代测试、diff 和 reviewer evidence。

### 3.8 MCP 2026-07-28：当前只能观察

MCP 官方在 2026-07-28 release candidate 公告中列出 stateless core、extensions、Tasks、MCP Apps、授权加固、正式弃用、JSON Schema 2020-12、`Mcp-Method` routing 和 `ttlMs` cache 等 breaking change。当前日期为 2026-07-22，公告中的最终规范尚未到发布时间，不能当作已发布标准。[MCP release candidate](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/)

当前只建议创建迁移候选字段：

- `protocol_version`
- `capabilities`
- `extension_ids`
- `deprecated_features`
- `auth_profile`
- `compatibility_test`
- `rollback`

授权基线继续坚持 Protected Resource Metadata、resource indicator、least privilege、禁止 token passthrough 和 audience validation。[MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)、[MCP security best practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices)

阻塞条件：2026-07-28 最终规范实际发布、source freshness 更新、breaking change diff、负向 fixture 和至少一个真实 client/server compatibility smoke 完成前，不修改 core contract，不启用新 extension。

### 3.9 OWASP Agentic Skills Top 10：做 crosswalk，不采纳格式提案

OWASP Agentic Skills Top 10 提出 AST01–AST10，覆盖恶意 Skill、供应链、过权、metadata、反序列化、隔离、更新漂移、扫描、治理和跨平台复用；但其仓库路线图仍把 AST07–AST10、Universal Skill Format v1.0 RC 和最终发布安排在 2026 年后续季度。[OWASP Agentic Skills Top 10](https://github.com/OWASP/www-project-agentic-skills-top-10)

建议：

- 将 AST01–AST10 映射到现有 provenance、hash、permission、deny-path、sandbox、scan、retire 和 target conformance 门禁；
- 对未覆盖项增加 fixture，而不是复制其 Universal Skill Format；
- 对其事件数据和第三方统计逐条回到原始来源复核；
- 在 OWASP 项目达到稳定版本前，状态保持 `OBSERVE`。

### 3.10 Agent Skills 维护：行为契约稳定、binding 可变

对 18,463 个 registry Skill、23,199 个个人 Skill 和 3,709 个复用关系的实证研究显示，复用后的修改大多是 additive，本地绑定变化明显多于稳定行为契约变化；常见可选 metadata 的使用率仍较低。[Agent Skills in the Wild](https://arxiv.org/abs/2607.00911)

可吸收的不是更多字段，而是维护证据：

- `upstream_revision/retrieved_at/content_digest`
- `stable_behavior_diff`
- `target_local_binding_diff`
- `use_count/effect_evidence/last_verified_at`
- `retire_or_refresh_due_at`

避免把 target-specific permission 或 vendor-only `context: fork` 提升为所有平台必须实现的 core semantic。

## 4. 观察而不吸收

### 4.1 VS Code / GitHub Copilot target

VS Code 已文档化 `.github/skills`、`.claude/skills`、`.agents/skills` 的项目级发现和个人级目录，并提供实验性的 `context: fork`；GitHub Copilot CLI 也持续增加 Skills、hierarchical discovery、Hooks 和组织 MCP policy。[VS Code Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)、[GitHub Copilot CLI changelog](https://github.com/github/copilot-cli/blob/main/changelog.md)

这些信息可作为未来 target contract 的输入，但当前没有本仓真实 use case、安装 smoke、effect eval 和 operator evidence。新增第四个 `experimental` target 只会扩大维护面，建议保持观察。

### 4.2 新的 skill compiler / universal format

已有 target contract、schema、compiler/export/install conformance 时，不应再并入第二套 IR 或“通用 Skill 格式”。学术或社区实现可用于生成差异测试，但不能与 ADK core contract 并存成为双 SSOT。

## 5. 明确拒绝或仅作来源索引

统一 GitHub 搜索得到的社区候选中，多数属于以下类型：

- 把 memory、context compression、verification、parallel/swarm、proactive loop 重新打包的 Skills 集合；
- 自带 daemon、MCP、多工具写权限和后台状态的 orchestration runtime；
- awesome list、笔记、目录和搜索入口；
- 与既有 `AGENTS.md` 约定冲突的单数 `AGENT.md` 方案；
- 只有 star、README 声明或 demo，没有固定 release、许可证、真实 runtime trace 和独立评测的个人仓库。

处理建议：

- 重复能力：`REJECT-duplicate`；
- 新 runtime/daemon：`REJECT-architecture`，除非出现明确 use case；
- 目录/awesome list：仅作为 discovery source，不成为 runtime dependency；
- 无许可证或许可证不清：`BLOCK-legal`；
- 需要自动执行外部命令、宽网络或持久凭证：`BLOCK-security`；
- star、下载量和作者自报性能只作排序线索，不作吸收证据。

## 6. 推荐的实施顺序

### Change A：`repository-runtime-campaign-v1`

范围：只新增一条真实仓库 eval contract 和可选 adapter；不改现有 routing campaign 的语义。

最小任务包：

1. 定义 task/repo/container/runtime/result schema 和 deny-path。
2. 用 target-specific safe mode 实现可审计 baseline；不支持隔离则 fail closed 为 `not-comparable`。
3. 接入可选 Inspect SWE adapter，版本/digest pinning，默认网络关闭。
4. 加入 5–10 条 freshness/OOD task 和 3–5 条 secure coding canary。
5. 增加 AgentLens 风格过程指标与 token/cost 分布。
6. 在 mock/frozen fixture 上验证 schema；真实付费/凭证 campaign 必须另行批准。

成功标准：静态 fixture 与 mock runtime 全通过；真实 campaign 需要至少两个 runtime、每条件 3 次 trial、完整 oracle/trace/cost，并且没有 secret、未审计网络或不固定依赖。

### Change B：`mcp-2026-07-28-compat-review`

范围：最终规范发布后只做版本、capability、弃用和 auth compatibility diff；先不启用 Tasks/Apps/extensions。

成功标准：官方最终规范 URL 和 retrieved_at、breaking-change 清单、schema/fixture、旧版本兼容和 rollback smoke 齐全。

### Change C：`field-evidence-v2`

范围：补齐 M5 的第二 operator、独立 repository、30 天 pilot 和选择偏差/人工时间证据；不降低现有门槛。

成功标准：预注册协议、任务/拒绝日志、operator/repo 分层、wall-clock 与 human-active time、失败/回滚、reviewer sign-off 可复核。

## 7. 本轮未执行的动作

- 未修改 `agent-dev-kit` 源码、manifest、Skill、workflow 或 docs。
- 未更新 `subrepos/adoption-matrix.md` / `.jsonl`。
- 未 clone、安装或执行任一外部候选。
- 未启用外部写操作、凭证或付费 runtime campaign。
- 未作 `ADOPT/REJECT` owner decision。
- 未写 Knowledge Hub candidate：本轮结论仍是 `review-required` 研究建议，先以本报告作为仓内可审查 SSOT；待 owner decision 后再归档稳定决策，避免把候选误记成已采纳事实。

## 8. 证据与限制

本轮生成的 metadata-only / report-only 证据：

- `reports/external-practice-candidates-2026-07-22.jsonl`
- `reports/external-practice-review-queue-2026-07-22.json`
- `reports/external-practice-cycle-evidence-2026-07-22.json`
- `reports/external-practice-cycle-2026-07-22.md`
- `reports/external-practice-recommendations-2026-07-22.json`
- `reports/external-practice-recommendations-2026-07-22.md`

限制：

- Gitee 返回 `degraded-empty`，因此不能声称所有 provider 全面无缺口。
- GitLab 本轮为 0 条，可能是查询与索引覆盖不足，不代表生态中没有候选。
- GitHub 通用关键词搜索噪声较高；本文的高优先候选来自官方文档、官方仓库或研究论文的定向复核。
- 所有外部动态事实以 2026-07-22 检索结果为准；进入 change 前必须再次刷新版本、许可证、commit/release 和安全状态。
- 当前 workspace 存在用户已有 dirty subrepo / untracked 状态；本轮未清理或覆盖。

## 9. Owner 决策建议

建议 owner 只批准 **Change A 的设计与 mock/frozen-fixture 阶段**，暂不批准真实凭证、付费模型和外部容器执行。MCP 与 AST10 继续观察到稳定发布；Change C 由第二 operator 和独立仓库条件满足后启动。

批准 Change A 时仍需单独确认：

- 支持的首批 runtime 与 model；
- 预算上限；
- 外部容器/仓库 allowlist；
- 网络与凭证策略；
- 可接受的 task/license 范围；
- 真实 campaign 的 reviewer 与停止条件。

## 10. 完成前验证索引

| 命令 | Exit | 结果摘要 | 证据层 | 关联产物 |
|---|---:|---|---|---|
| `practice-intake.sh check --kind candidate` | 0 | 118 条 candidate schema 通过 | Workflow | candidate ledger |
| `practice-intake.sh check --kind evidence` | 0 | cycle evidence schema 通过 | Workflow | cycle evidence |
| `practice-intake.sh check --kind queue` | 0 | review queue schema 通过 | Workflow | review queue |
| `check-practice-intake.sh .` | 0 | policy、plan、provider security、idempotence 和 terminal boundary 通过 | Workflow | intake contracts |
| `check-doc-sync.sh .` | 0 | 文档与治理文件同步 | Repository | curated report |
| `check-adoption-matrix-status.sh .` | 0 | 采纳矩阵状态门禁通过；本轮未改矩阵 | Repository | adoption matrix |
| `check-token-budget.sh . --summary-json` | 0 | `status=pass`、`failures=0` | Repository | token governance |
| `check-all.sh --quick` | 1 | 53 项中 50 通过、3 失败 | Repository | quick gate |

`check-all.sh --quick` 的负结果已独立复核：

- `check-current-status-consistency.sh`：current subrepo state 不是 pass；
- `check-reference-dirty-triage.sh`：`OpenSpec`、`superpowers`、`vibeflow` 的 observe baseline 均于 2026-07-20 过期；
- `check-subrepo-state.sh`：上述三个参考子仓分别有 655、115、216 个 dirty change；`agent-dev-kit` 为 clean。

门禁结论分层：

- **本轮研究产物：pass**。schema、intake、文档、矩阵和 token 定向门禁均通过。
- **工作区整体：needs-fix**。已有 dirty reference subrepo 与过期 baseline 未闭环，不能声称全仓健康或可提交。
- **吸收决策：blocked-by-owner-decision**。尚无独立 owner `ADOPT` 决策，本文候选不得进入 ADK change。
- **breaking change：none**。本轮只新增报告和 metadata-only evidence，没有更改运行时、schema、权限或已发布接口。
- **回退**：删除本轮新增的 7 个 `reports/` 文件即可；不涉及 source-to-live 或运行态回退。
