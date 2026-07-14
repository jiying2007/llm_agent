# llm_agent / agent-dev-kit 终态成熟度与外部实践审计

- 审计日期：2026-07-13
- 审计对象：`llm_agent` 根仓、`agent-dev-kit` 子仓及两者之间的交付和证据链
- 审计类型：只读架构、实现、门禁、运行目标和长期资产审计
- 结论状态：`owner-review-pending`
- 证据边界：本地源码、测试、manifest、现有报告、定向生成实验，以及截至审计日可访问的官方资料
- 非证据：未执行付费双运行时 campaign，未取得第二位独立操作者和 30 天现场证据，未把本报告提升到 Knowledge Hub active archive

## 1. 执行结论

### 1.1 总体判断

**当前不是终态成熟，也不应宣称 M5 已认证。** 现有 `overall=M3`、`release-candidate`、`terminal_mature=false` 的总判断是诚实且基本准确的。更精确地说：

1. `llm_agent` 已形成较成熟的参考仓发现、不可变快照分析、采纳决策、治理门禁和证据编排工作区，目标边界清楚，本地控制面接近 M4。
2. `agent-dev-kit` 已形成可安装、可验证、可发布演练的资产编译与治理控制面，但综合证据仍处于 M3 release candidate。
3. 当前优势集中在 source/test 两层，runtime/field 两层明显不足；“控制面完备”不能等同于“真实效果成熟”。
4. 最严重的新缺口是 direct target 适配器的语义兼容：当前 `export` 可以成功生成文件并返回 `status=pass`，但 Claude Code、OpenCode、Hermes Agent 的 Skill 产物均缺失必需的 `description`，Claude Code 和 OpenCode 的 Skill 路径也不符合官方发现约定。
5. `software-m5 status` 明确显示 7 个 blocker：`final_version`、`independent_repository`、`operator_count`、`pilot_duration`、`real_repository_count`、`required_field_events`、`runtime_campaign`。

因此，最合适的产品表述是：

> `llm_agent` 是成熟度较高的 AI Coding 参考实践治理工作区；`agent-dev-kit` 是 M5-ready 的本地控制面候选，但仍是 M3 release candidate，尚未完成多运行时原生兼容、独立效果验证和长期现场认证。

这里的 `M5-ready` 是仓库内部定义的“软件控制面准入就绪”，不是行业认证，也不是外部独立认证。

### 1.2 当前最重要的战略选择

下一阶段不应继续以“增加更多 Agent、Skill、manifest、报告和参考仓”为主。资产广度已经足够，真正短板是：

- 目标运行时原生可发现、可加载、可执行；
- schema 和 target contract 真正可执行，而不是文档性声明；
- 真实 trace、outcome、成本和失败恢复数据；
- 独立仓库、第二位操作者、30 天维护和升级/回滚现场证据；
- 减少 shell 和兼容入口造成的长期维护负担。

一句话概括：**从“资产数量和规则一致性”转向“契约符合性、真实效果和长期运维证据”。**

## 2. 产品目标与边界

### 2.1 llm_agent

根仓的目标不是运行 LLM Agent，而是：

- 跟踪 AI Coding 参考实现；
- 从不可变 commit snapshot 形成结构化分析和决策候选；
- 经语义、重复、架构、许可证、安全和效果复核后，在 `agent-dev-kit` 落地；
- 维护采纳矩阵、证据、报告、阶段门禁和长期复审状态；
- 禁止未经批准的自动吸收、外部写入和运行态覆盖。

这个边界在 `README.md`、`AGENTS.md`、`docs/absorption-governance.md` 和 intake 实现中是一致的。特别是 `tools/codex_assets/intake_pipeline.py` 将结构评分明确限定为 discovery/triage 信号，不把它伪装成采纳结论，这是正确设计。

### 2.2 agent-dev-kit

`agent-dev-kit` 的正确定位是：

- 平台中立的 Agent/Skill/Profile/Workflow 资产包；
- manifest 驱动的资产目录、路由、编译、安装、回滚、评测和发布控制面；
- 对 Codex、Claude Code、Hermes Agent、OpenCode 等运行时提供直接导出或外部 handoff；
- 不包含 LLM runner，不接管模型推理循环。

“no-llm-runner” 是有意的产品边界，不是功能缺失。真正需要验证的是产物能否被目标 runtime 原生识别，以及这些资产是否提升实际任务结果。

### 2.3 两仓关系

当前逻辑链路合理：

```text
外部参考源 / 官方文档
        |
        v
llm_agent: 发现 -> snapshot -> 分析 -> 决策 -> 治理证据
        |
        v
agent-dev-kit: manifest -> Agent/Skill/Profile/Workflow -> 编译/安装/评测/发布
        |
        +--------------------+
        |                    |
        v                    v
~/codex -> ~/.codex     direct target adapters
        |                    |
        +----------+---------+
                   v
             runtime / field evidence
```

需要继续坚持的边界：

- 根仓不变成第二个资产实现仓；
- ADK 不变成通用 LLM runtime；
- `llm_agent -> agent-dev-kit -> ~/codex -> ~/.codex` 的声明式链路不能被绕过；
- 外部实践进入的是候选和证据，不是自动复制或自动启用。

## 3. 当前资产与复杂度

### 3.1 规模快照

| 指标 | 当前值 | 判断 |
|---|---:|---|
| 根仓 tracked reports | 218 | 证据丰富，但需持续治理历史报告噪音 |
| 根仓 scripts | 96 | 控制面较宽，维护成本偏高 |
| 根仓 tests | 18 | 以 shell 集成/契约测试为主 |
| 根仓 manifests | 17 | 治理 SSOT 已形成 |
| ADK tracked files | 576 | 已是独立产品规模 |
| ADK Agent | 12 | 数量足够，后续应看使用效果 |
| ADK core Skill | 56 | 已达到需要治理精简而非继续扩张的阶段 |
| ADK optional Skill | 9 | 可选分层方向正确 |
| ADK Profile | 9 | 覆盖面充足 |
| ADK Workflow | 6 | 已形成高层流程层 |
| ADK scripts | 49 | 与 Python core 并存，形成双控制面 |
| ADK test files | 68 | 本地回归密度较高 |

代码量抽样：

- 根仓 `scripts/*.sh` 约 15,088 行；ADK `scripts/*.sh` 约 14,088 行，合计约 29,176 行 shell。
- 根仓和 ADK shell tests 合计约 7,696 行。
- 根仓和 ADK Python 合计约 6,759 行。
- ADK CLI 仍有 22 个 legacy command 通过 `subprocess.call(["bash", ...])` 委托给 shell。
- 大文件包括根仓 `tools/codex_assets/software_m5.py` 1,366 行、ADK `campaign.py` 874 行、`evaluation.py` 746 行，以及 `check-official-docs-governance.sh` 1,626 行。

这说明项目已经越过“轻量脚本仓”阶段。继续只靠 shell 约定、人工 JSON 校验和大脚本扩展，会逐步压低可维护性上限。

### 3.2 采纳资产状态

`subrepos/adoption-matrix.jsonl` 当前有 183 条记录，覆盖 83 个 repo：

- `adopt`: 144
- `reject`: 34
- `observe`: 5
- `state=done`: 183

优点是决策全量结构化且有 evidence。问题是 `adopt` 同时承载了“可执行实现”“方法借鉴”“术语保留”“只作参考”等不同深度，导致采纳数量容易高估真实落地程度。

建议把决策和实现深度分开：

```text
decision: adopt | adapt | observe | reject | archive-only
implementation_depth: reference | contract | executable | runtime-verified | field-verified
```

`check-adoption-real-assets.sh` 当前主要证明 evidence 路径存在，不足以证明该资产与上游实践语义对应，更不能证明产生了效果。后续应增加 source commit、license、semantic mapping、effect evidence 和 owner review。

## 4. 成熟度复核

### 4.1 复核原则

现有 scorecard 将 12 个维度大多评为 M4，但多项证据属于“本地实现和自有门禁”。本报告建议把实现成熟度和证据成熟度分开，否则容易出现“代码存在即 M4”的乐观偏差。

| 维度 | 现有评级 | 审计建议 | 主要依据 |
|---|---|---|---|
| D01 目标与产品边界 | M4 | M4 | 根仓、ADK 和 runtime boundary 一致 |
| D02 架构与契约 | M4 | M3 | 分层清楚，但 JSON Schema 未真正执行，target contract 未建模 |
| D03 功能完整性 | M4 | M3 | CLI 功能丰富，但 direct target 生成结果不符合原生契约 |
| D04 效果有效性 | M3 | M2-M3 | 固定 fixture 可重复，真实双运行时和独立 outcome 未完成 |
| D05 可靠性与验证 | M4 | M4-local / M3-external | 本地回归很强，clean-clone 集成和 runtime-native smoke 不足 |
| D06 性能与成本 | M4 | M2-M3 | 只有内进程微基准，缺少端到端、规模和资源曲线 |
| D07 安全与供应链 | M4 | M3 | 有 fail-closed 基线，但无依赖漏洞、SAST、attestation 完整链 |
| D08 发布与回滚 | M4-local | M3 | 本地演练和 receipt 较强，远端发布、签名、目标产物有效性不足 |
| D09 可维护性 | M4 | M3 | 文档和测试丰富，但约 2.9 万行 shell、22 个 legacy 入口形成负担 |
| D10 扩展与兼容 | M4 | M2 | direct target 只验证生成，不验证官方发现和加载 |
| D11 操作者与开发体验 | M4-local | M3 | 本地入口齐全，失败诊断和独立操作者体验尚未证明 |
| D12 长期资产与现场证据 | M3 | M2-M3 | 有自用 pilot，但无独立仓库、第二操作者和 30 天完整事件链 |

综合仍建议保持 **M3 release candidate**，不建议在 P0 缺口修复前提升总评级。

### 4.2 已经成熟的部分

1. **目标边界成熟**：根仓是治理工作区，ADK 是资产控制面，Codex live root 是外部交付目标，三者没有被混成一个 runtime。
2. **吸收安全边界成熟**：不可变 snapshot、结构评分非采纳分、owner approval、禁止自动外部写入等约束合理。
3. **本地回归成熟**：根仓 full 门禁 62/62 通过；ADK 全量测试 49/49 通过；strict manifest 校验通过。
4. **失败闭合意识成熟**：M5 status 没有因为本地测试通过就伪造 field certification，7 个 blocker 被明确保留。
5. **资产分层较成熟**：core/optional Skill、Profile、Workflow、direct/external target、source/test/runtime/field evidence 已形成清晰词汇。
6. **交付安全基础良好**：安装 plan/apply/rollback、receipt digest、路径边界、锁、GitHub Action SHA 固定等机制具有实际价值。

## 5. P0 关键缺口

### 5.1 Direct target 适配器不是原生兼容适配器

`agent-dev-kit/src/agent_dev_kit/compiler.py` 当前会剥离源文件 frontmatter，再只写入：

```yaml
name: <name>
kind: <agent|skill>
target: <target>
manifest_version: <version>
source: <source>
```

源 Skill 的 `description` 被丢弃；Agent manifest 中已有的 description 也没有被渲染。定向导出实验得到：

| Target | 当前输出 | 官方期望 | 结论 |
|---|---|---|---|
| Claude Code Agent | `agents/<name>.md`，无 `description` | `.claude/agents/<name>.md`，`name` 和 `description` 必需 | 路径可映射，metadata 不合规 |
| Claude Code Skill | `skills/<name>.md`，无 `description` | `.claude/skills/<name>/SKILL.md`，`name` 和 `description` 必需 | 路径和 metadata 均不合规 |
| OpenCode Agent | `prompts/agent/<name>.md`，无 `description`/`mode` | `.opencode/agents/<name>.md`，`description` 必需 | 路径和 metadata 均不合规 |
| OpenCode Skill | `prompts/skill/<name>.md`，无 `description` | `.opencode/skills/<name>/SKILL.md`，`name` 和 `description` 必需 | 路径和 metadata 均不合规 |
| Hermes Agent Skill | `skills/<name>/SKILL.md`，无 `description` | Agent Skills 兼容目录，`name` 和 `description` 必需 | 路径基本合理，metadata 不合规 |

官方依据：

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [OpenCode agents](https://opencode.ai/docs/agents/)
- [OpenCode Agent Skills](https://opencode.ai/docs/skills/)
- [Agent Skills specification](https://agentskills.io/specification)
- [Hermes Agent Skills System](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/skills.md)

这不是格式美观问题，而是 runtime discovery contract 问题。目标运行时可能完全看不到这些 Skill。

此外，`installer.py` 的 plan 使用所有 target 共用的 `agents/<name>`、`skills/<name>` 目录，并直接复制源资产目录；它与 `compiler.py` 的目标特定导出逻辑不共享 adapter。以 Claude Code 为例，install 会计划 `agents/<name>/AGENTS.md`，而官方 Agent 是 `agents/<name>.md`。因此 `export` 和 `install` 的目标语义彼此也不一致。

当前测试主要验证：

- 文件成功生成；
- target marker 存在；
- clean/rollback/receipt 行为正确。

当前测试没有验证：

- 目标 runtime 能发现产物；
- frontmatter 必需字段和允许字段；
- Agent/Skill 在真实 runtime 中可列出、可触发、可加载；
- export 与 install 生成相同语义的目标树。

**处理建议：在修复并完成 runtime-native smoke 前，把三个 direct target 标为 `experimental` 或 `generated-only`，不要继续作为 D03/D10 M4 证据。**

### 5.2 Software M5 现场和 campaign 尚未完成

截至审计时：

- `readiness_status=m5-ready`
- `eligibility_status=blocked`
- `certification_status=blocked`
- `software_m5_certified=false`
- field event 2 条，其中 field event 1 条
- 有 field evidence 的真实仓库 1 个
- 独立仓库 0 个
- 人类操作者 1 位
- 独立 pilot 最佳观察天数 0

这意味着现有 M5-ready 只能说明“内部控制面已具备开始认证的条件”，不能说明效果、可靠性或维护成本已在真实环境稳定。

双运行时 campaign 也仍被 Claude 未认证阻塞。即使 deterministic 60/60 通过，它只证明固定 fixture 与当前 matcher 的一致性，不证明 paraphrase、歧义、多意图、对抗输入、工具失败或模型升级下的泛化能力。

### 5.3 根仓与 ADK 的 clean-clone 集成证据不足

根仓 CI 使用 `submodules: false`，只运行 shell/Python 语法、3 个根仓契约测试和文档检查；相关测试还会在 ADK 未初始化时跳过 ADK evidence 路径。ADK 自己的 CI 较完整，会在 Python 3.8/3.12 跑 full tests、安全、deterministic eval 和 wheel build。

问题在于两者没有形成一个公开 clean clone 的集成门禁：

- 根仓 CI 不拉取 ADK；
- `.gitmodules` 中 ADK 使用 SSH URL，未配置 GitHub key 的外部操作者不能直接初始化；
- 根仓的 product scorecard 可以在没有 ADK 工作树的情况下通过自包含契约检查；
- 因而“根仓 + 锁定 ADK commit + 集成门禁”没有被 CI 实际重建。

建议增加独立 integration job：使用 HTTPS、初始化唯一需要的 ADK gitlink、核验 `adk.lock`、跑 strict validate、target conformance、核心 export/install 和根仓 product contract。

## 6. 功能与架构评估

### 6.1 功能覆盖

ADK 当前公共能力已经较完整：

- `validate` / `doctor` / `catalog` / `match`
- `export` / `install` / `lock`
- `benchmark` / `security` / `eval`
- `release` / `test`
- `goal` / `capability`
- 22 个治理兼容入口

缺口不在“是否有命令”，而在命令的语义深度：

- `validate --strict` 是手工规则集合，不是真正 JSON Schema strict validation；
- `security check` 是有价值的基线扫描，但不是完整 SAST/SCA/供应链审计；
- `benchmark` 是内进程微基准，不是 CLI/安装/大 manifest 的端到端性能；
- `eval deterministic` 是固定数据集一致性，不是 runtime outcome eval；
- `release build` 能生成可复现 tar/checksum，但 release workflow 只上传 Actions artifact，没有发布、签名和 provenance attestation。

### 6.2 Schema 和类型契约

`manifest.schema.json` 只有约 78 行，而主 `manifest.json` 约 2,671 行。仓库没有 `jsonschema` 依赖或实际 schema validation 调用，测试只确认 schema 文件存在。`Manifest.validate(strict=True)` 手工检查关键字段和路径，但会忽略未知顶层字段和大量未建模内容。

建议：

1. 选择 JSON Schema Draft 2020-12 作为机器契约；
2. 用 [`python-jsonschema/jsonschema`](https://github.com/python-jsonschema/jsonschema) 在 CLI、CI 和 tests 中真正执行；
3. 明确 extension namespace，核心对象默认 `unevaluatedProperties: false`；
4. 从同一 schema 生成或校验 typed model，避免 schema、Python 和 shell 三份规则漂移；
5. 为每个 direct target 建独立版本化 schema 和 golden tree fixture。

### 6.3 路由和效果评测

当前 matcher 以规范化字符串包含关系为主，deterministic suite 固定 60 条，另有 22 个正向和很少量无关负向用例。它适合做快速回归，但不足以证明路由质量。

建议增加：

- blind holdout，避免测试集与规则共同演化；
- paraphrase、同义词、错别字、中英文混合；
- ambiguous、多意图和不应触发样本；
- adversarial prompt injection 与越权写入样本；
- 每 Skill precision、recall、false activation、confusion matrix；
- 多 trial 方差和模型版本分层；
- transcript/trace grading 与最终环境 outcome grading；
- 人类标注抽样和 inter-rater agreement。

## 7. 性能、可靠性和运维

### 7.1 已验证性能

20 次本地微基准结果：

| 操作 | median | p95 | 结论 |
|---|---:|---:|---|
| manifest validate | 45.218 ms | 49.531 ms | 当前规模快速 |
| profile resolve | 5.878 ms | 7.876 ms | 当前规模快速 |
| export plan | 11.064 ms | 11.187 ms | 当前规模快速 |

这些数据证明 typed core 在当前 manifest 下没有明显 CPU 热点，但不能支撑 D06 全面 M4。仍缺少：

- cold-start CLI 时间；
- `devkit.sh -> Python -> legacy shell` 端到端开销；
- 10x/100x assets 和 profile 规模曲线；
- export/install 大量小文件的 I/O、磁盘和内存；
- 并发 writer、锁竞争、故障注入和中断恢复；
- CI 总时长、缓存命中率和维护者等待成本；
- runtime token、调用费用和任务成功率的联合曲线。

### 7.2 可靠性与诊断

根仓 full 62/62、ADK 49/49 是强证据，但测试主要由同一仓库规则定义，属于内部一致性证据。

`scripts/check-all.sh` 非 verbose 模式把每个失败输出写入临时文件后直接删除，只汇报脚本名和退出码。门禁一旦失败，操作者需要重新跑 `--verbose` 才能看到原因。建议保留失败日志路径、打印末尾关键行，并提供稳定 JSON/JUnit 汇总。

`check-adk-harden-readiness.sh` 会再次运行完整 ADK suite，根仓 full 还会运行多层 aggregate，当前一次 full 检查中 harden、performance、workspace aggregate 分别耗时约 318、112、114 秒。建议建立 DAG 去重，区分 PR blocking、nightly、release 三档，减少重复执行而不降低覆盖。

## 8. 安全与供应链

### 8.1 已有优点

- GitHub Actions 使用完整 commit SHA；
- 默认 `contents: read`；
- 安装有路径边界、receipt digest、managed/unmanaged 冲突和 rollback；
- intake 不执行未知仓代码，先做结构分析；
- 外部写入保持 report-only/人工批准；
- third-party Skill 已有专门供应链治理流程。

### 8.2 仍需补齐

当前 Python `security_check` 主要检查可疑文件名、文本模式、world-writable、symlink 和 Action pin。建议补充：

- `ShellCheck` 和 `Ruff` 的真实 CI 执行；
- Python type checking、依赖锁和 vulnerability audit；
- CodeQL 或 Semgrep 等 SAST；
- SBOM 在 CI 中生成并验证，不只由本地 release helper 产生；
- GitHub artifact attestation 或 Sigstore 签名；
- release provenance、source commit、manifest digest、builder identity 的可验证绑定；
- direct target 产物权限和 tool restrictions 的 runtime-specific 映射。

特别注意：不同 runtime 对 Skill 中 `allowed-tools` 的支持并不一致。权限边界应由 target adapter 和 runtime config 明确生成，不能假设一个 frontmatter 字段跨 CLI/SDK 自动生效。

## 9. 可维护性与长期资产

### 9.1 当前资产结构的优点

- manifest、Agent、Skill、Profile、Workflow、eval suite、goal、automation、freshness gate 已有 SSOT 思维；
- source/test/runtime/field evidence 层级是正确的长期框架；
- report registry 已给当前架构报告建立 canonical/superseded 关系；
- local/third-party/official 来源有不同治理策略；
- 未把一次性结论静默写入 `~/.codex/memories`。

### 9.2 长期债务

1. **Shell/Python 双控制面**：Python core 已出现，但大量关键逻辑和 22 个 public command 仍委托 shell，规则分散。
2. **大脚本集中**：多个 500-1,600 行文件混合解析、校验、输出和策略，修改风险上升。
3. **manifest 过宽**：单文件承担过多领域，schema 又没有覆盖完整语义。
4. **报告数量高**：218 个 tracked report 需要更强的 topic registry、TTL、hash 去重和 superseded 管理。
5. **采纳语义过载**：`adopt=done` 不等于 executable/runtime/field verified。
6. **资产有效性缺少反馈**：Skill 多而 usage/outcome telemetry 少，难以决定淘汰、合并或降级 optional。
7. **官方来源不对称**：freshness gate 有 64 个 OpenAI source，其中 58 adopted、6 watch，但全部来自 `developers.openai.com`；Claude Code 已是 direct target，却没有对等的 Anthropic official source registry。

### 9.3 长期资产判定标准

建议以后只有满足以下链路的内容才算高成熟长期资产：

```text
来源与许可证
  -> 结构化契约
  -> 可执行实现
  -> conformance / regression
  -> runtime trace 与 outcome
  -> field 维护、升级、回滚证据
  -> owner 复审、版本和淘汰策略
```

只有文档、manifest row 或 evidence 路径存在的，应标为 reference/contract asset，不计入 runtime/field 成果。

## 10. OpenAI 官方实践吸收建议

### 10.1 已经吸收较好的部分

OpenAI [Codex best practices](https://developers.openai.com/codex/learn/best-practices) 强调 Goal、Context、Constraints、Done when，复杂任务先计划，`AGENTS.md` 保持短而实用，完成前运行测试/lint/type/review，只为真实工作流连接 MCP。当前 ADK 在目标契约、计划、验证、上下文治理和 MCP 边界上总体一致。

OpenAI [Build skills](https://developers.openai.com/codex/skills) 和 Agent Skills 标准强调目录化 Skill、`SKILL.md`、`description` 触发和 progressive disclosure。ADK 源 Skill 基本符合，但 direct target compiler 把最关键的 `description` 丢失，必须先修复实现而不是再新增文档。

### 10.2 优先新增吸收

1. **Trace + dataset eval**：把 [Evaluate agent workflows](https://developers.openai.com/api/docs/guides/agent-evals) 和 [Trace grading](https://developers.openai.com/api/docs/guides/trace-grading) 落地为可选 evidence adapter，评估工具选择、handoff、路由、policy 和最终 outcome。
2. **真实 Done condition**：将 goal evaluator、deterministic Stop gate 和独立 reviewer 证据统一到 goal contract，不只检查文件存在。
3. **Skill conformance**：按开放 Agent Skills 标准建立一个共享 validator，再叠加 Claude/OpenCode/Hermes target profile。
4. **最新兼容 canary**：将模型最新版本和 Codex CLI 最新版作为非阻断 canary；认证 campaign 使用冻结版本，不在 campaign 中途追 latest。
5. **官方文档语义 freshness**：当前 `openai-latest-model-gpt-5-5` 尚未到时间过期，但官方目录已经出现 GPT-5.6。对高波动来源，应增加内容 hash/changelog 触发，而不只依赖 30/90 天 TTL。

### 10.3 官方开源项目

- [`openai/openai-agents-python`](https://github.com/openai/openai-agents-python)：适合借鉴 tracing、guardrail、handoff、session 和工程质量配置；建议做 optional eval/trace adapter，不作为 ADK core runtime 依赖。
- [`openai/codex`](https://github.com/openai/codex)：适合做 runtime compatibility canary、AGENTS/Skill/CLI 变更观察；不建议作为常驻 submodule 或复制实现。

## 11. Anthropic / Claude 官方实践吸收建议

### 11.1 应立即吸收

1. [Claude Code best practices](https://code.claude.com/docs/en/best-practices) 的核心是可执行验证、Explore -> Plan -> Code、简洁 `CLAUDE.md`、deterministic hooks、fresh-context review 和主动上下文清理。ADK 已有对应概念，但需要 target-native 产物和真实运行证据。
2. [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) 与 [skills](https://code.claude.com/docs/en/skills) 应成为 Claude adapter 的版本化 contract 和 golden fixtures。
3. [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) 区分 task、trial、grader、trace、outcome、eval harness 和 agent harness。当前 deterministic accuracy 应升级为 transcript + environment outcome 双评分。
4. [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) 强调最小高信号 context、工具边界清晰、少而典型的 examples。当前 Skill 数量已经足够，应做合并、optional 化和效果淘汰。
5. [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) 使用 initializer、结构化 feature list、progress notes、git history、单 feature 推进和每轮基本测试。当前 context/goal manifests 可以吸收其“恢复前先读状态和验证基线”的可执行部分。
6. [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) 强调 planner/generator/evaluator 和逐项移除 scaffold 的消融实验。ADK 不应默认增加多 Agent 层，而应通过 ablation 证明每个治理组件确实提升 outcome。

### 11.2 官方开源项目

- [`anthropics/skills`](https://github.com/anthropics/skills)：适合做 Agent Skills conformance fixture、复杂 Skill 目录结构和 progressive disclosure 参考。仓库含 Apache-2.0 与 source-available 混合内容，必须逐目录复核许可证，禁止批量复制。
- [`anthropics/claude-agent-sdk-python`](https://github.com/anthropics/claude-agent-sdk-python)：适合实现 Claude campaign adapter、session/trace capture 和隔离设置；保持 optional dependency。
- [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action)：可借鉴 WIF/OIDC、trust model 和 CI 权限设计；任何外部写操作仍需 owner approval。
- `anthropics/claude-code`：适合 target contract 和 release compatibility watch，不建议 vendoring 或自动跟随未审版本。

### 11.3 不应直接吸收

- 不吸收 agent 自动修改共享 ADK Skill 源资产的默认行为；最多写入 candidate/staging，由 owner review 后提升。
- 不因官方文章出现 planner/generator/evaluator 就默认三 Agent 化；只有 ablation 显示效果提升才增加复杂度。
- 不批量安装 marketplace/community Skill；保持 provenance、hash、license、安全扫描和 trust tier。

## 12. 其他高价值开源项目

| 项目 | 解决的当前缺口 | 建议决策 |
|---|---|---|
| [Agent Skills specification](https://agentskills.io/specification) | 多 runtime Skill 基础格式和必需字段 | P0 adopt 为 conformance contract |
| [python-jsonschema/jsonschema](https://github.com/python-jsonschema/jsonschema) | manifest/schema 目前未真正执行 | P0 adopt，小依赖、CI 阻断 |
| [Hypothesis](https://github.com/HypothesisWorks/hypothesis) | 路由、路径、manifest 和状态机边界样本不足 | P1 adapt，用于 property-based tests |
| [ShellCheck](https://github.com/koalaman/shellcheck) | 约 2.9 万行 shell 只有语法和格式检查 | P1 tool-only，引入固定版本 CI |
| [Ruff](https://github.com/astral-sh/ruff) | Python 缺少统一 lint/format/security rule 基线 | P1 tool-only，引入固定配置 |
| [OpenSSF Scorecard](https://github.com/ossf/scorecard) | 供应链检查偏自定义、缺外部基线 | P1 report-only，不用总分替代逐项风险判断 |
| [Sigstore Cosign](https://github.com/sigstore/cosign) | release tar/checksum 缺签名和透明 provenance | P1 adapt，或优先 GitHub artifact attestation |
| [GitHub artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations) | CI 构建身份与制品来源未绑定 | P1 adopt 到 release workflow |

优先原则：先引入“标准、验证器、静态分析和 provenance”，不要再优先引入大型 Agent framework。

## 13. 分阶段优化路线图

### Phase 0：纠正成熟度声明，1-3 天

1. 将 Claude Code、OpenCode、Hermes direct target 标为 `experimental`，直到通过 native discovery/load smoke。
2. 在 scorecard 中增加 `implementation_level`、`evidence_level`，避免 M4 source/test 掩盖 runtime/field 缺口。
3. 把本报告的 target conformance finding 纳入 P0 task pack。
4. 暂停以新增 Skill/Agent 数量为主的扩张，除非有明确 runtime outcome 需求。

### Phase 1：修复目标契约，1-2 周

1. 建立统一 `TargetAdapter`，让 export、install、release fixture 共用 destination、metadata、permissions 和 validation。
2. Claude Code：Agent 输出 `agents/<name>.md`；Skill 输出 `skills/<name>/SKILL.md`；保留/生成 `description`。
3. OpenCode：Agent 输出 `agents/<name>.md` 并生成 `description`/`mode`；Skill 输出 `skills/<name>/SKILL.md`。
4. Hermes：保留目录式 Skill，补齐 `description`，验证 Agent 原生格式。
5. 为每个 target 增加官方示例 golden tree、schema test、CLI discovery smoke 和 install/export equivalence test。
6. 根仓增加 HTTPS clean-clone integration CI。

### Phase 2：收敛架构与质量，2-4 周

1. 真正执行 JSON Schema，并缩小 extension surface。
2. 将 manifest、target、release、campaign 的核心状态机继续迁入 Python；shell 保留稳定 wrapper。
3. 拆分 500+ 行模块和 1,000+ 行治理脚本，明确 parser/model/policy/render 四层。
4. 引入 ShellCheck、Ruff、type checker、依赖 audit 和 SAST。
5. 让 `check-all` 输出 JSON/JUnit、保留失败日志，并去重 aggregate DAG。
6. 增加 cold-start、scale、I/O、lock contention、failure injection 性能基线。
7. release 增加 SBOM verification、attestation/signature 和公开发布演练。

### Phase 3：证明效果，2-6 周

1. 建 blind holdout、paraphrase、ambiguous、adversarial、multi-intent 数据集。
2. 捕获完整 trace，分开评估 route、tool use、policy、artifact、final outcome。
3. campaign 使用冻结 runtime/model 版本；latest 版本只作为非阻断 canary。
4. 至少完成 Codex/Claude 各 60 task、3 trial，报告方差、失败类别、token、费用和 latency。
5. 对每个治理组件做 ablation，删除不能证明价值的 scaffold。

### Phase 4：现场认证，30-90 天

1. 两个真实软件仓库，其中至少一个独立仓库。
2. 至少两位人类操作者或符合策略的独立 reviewer 事件。
3. 连续 30 天 ledger 和 hash chain。
4. 完成 workload、upgrade、rollback、fault、recovery、maintenance、review 全事件链。
5. 记录人工分钟、故障恢复时间、升级停机、任务成功率、误触发和回滚成功率。
6. 只有 blocker 清零后才发布 final `3.1.0` 和声明 M5 certified。

## 14. 终态退出门禁

| 门禁 | 终态要求 |
|---|---|
| 产品边界 | 根仓、ADK、live runtime 职责无重叠，术语一致 |
| Target conformance | 每个 direct target 通过官方格式 validator、discovery、load、trigger、permission smoke |
| Export/install 一致性 | 同 profile 的 export 和 install 目标树语义等价 |
| Schema | 主 manifest 和 target contract 由可执行 schema 阻断未知/错误字段 |
| Clean clone | 无本地隐含状态、无 SSH 私钥要求即可重建集成门禁 |
| 路由效果 | blind/OOD 数据有 per-skill precision/recall 和稳定多 trial 结果 |
| Outcome | 不只看文本结论，验证环境最终状态和 artifact |
| 性能 | CLI cold/warm、规模、I/O、内存、锁竞争均有预算和趋势 |
| 安全 | SAST/SCA、SBOM、provenance、签名、权限映射和回滚均有证据 |
| 运维 | 独立操作者能按文档安装、升级、诊断、回滚，不依赖作者口头知识 |
| 长期现场 | 独立仓库、第二操作者、30 天和必需事件全部满足 |
| 资产治理 | Skill/Agent 有使用与效果数据，支持合并、淘汰、optional 化和回滚 |

“终态”不等于永远不变，而是当前 major version 的目标、契约、效果、发布和维护机制均可由独立操作者重复验证；未来 runtime 变化通过版本化 adapter 和 canary 吸收，而不是推翻整个控制面。

## 15. 验证证据

本次实际执行并获得的关键结果：

| 命令/实验 | 结果 |
|---|---|
| `rtk scripts/check-all.sh --quick` | 56/56 PASS |
| `rtk scripts/check-all.sh --full` | 62/62 PASS |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict --summary-json` | PASS，12 Agent、56 core Skill、9 optional Skill、9 Profile、6 Workflow |
| `rtk bash agent-dev-kit/tests/run_all.sh` | 49/49 PASS |
| ADK benchmark，20 iterations | 三项微基准均在当前预算内 |
| `rtk bash agent-dev-kit/scripts/devkit.sh security check` | PASS，但覆盖面为轻量基线 |
| `rtk bash agent-dev-kit/scripts/devkit.sh release check` | PASS，本地 release contract 成立 |
| `rtk scripts/software-m5.sh status --summary-json` | M5-ready；eligibility/certification blocked；7 blockers |
| Claude/OpenCode/Hermes `devkit export --profile core` | 命令 PASS，但定向审计发现官方 target contract 不合规 |

证据解释：

- 62/62 和 49/49 证明仓库内部一致性和既有回归稳定。
- target export 反例证明现有门禁尚不能识别“生成成功但 runtime 不可发现”的语义错误。
- M5 blocker 和现场数据证明终态认证条件尚未完成。
- OpenAI Codex manual helper 本次因响应缺少 `x-content-sha256` 未能使用，官方实践核验改用 OpenAI 官方网页；这不影响本地实现证据，但应修复 docs helper 的兼容性或回退诊断。

## 16. 最终结论

`llm_agent` 与 `agent-dev-kit` 已经不是原型，也不是简单 Prompt/Skill 集合。它们具备清晰产品边界、较强治理控制面、丰富回归、可复现 release 演练和诚实的现场阻塞状态，属于有实际工程价值的 M3 release candidate。

但它们尚未终态成熟，且当前最大风险不是“功能不够多”，而是“门禁证明了内部声明，却没有证明目标 runtime 真能加载，也没有证明独立用户长期使用有效”。

建议优先级固定为：

1. 修复 direct target 原生契约和 export/install 一致性；
2. 建 clean-clone 集成、可执行 schema、静态分析和 release provenance；
3. 建 trace/outcome/OOD eval，而不是继续扩大固定 fixture；
4. 完成双运行时 campaign、独立仓库、第二操作者和 30 天 field evidence；
5. 用 usage/outcome 数据精简 Skill、shell、兼容入口和历史报告。

完成上述闭环后，才有充分依据讨论 final `3.1.0`、M4 综合成熟或内部 M5 certification。
