# llm_agent / agent-dev-kit 产品成熟度审计

- 日期: 2026-07-13
- 审计范围: 目标、产品边界、架构、功能、效果、可靠性、性能、安全、发布、维护、扩展、体验、长期资产和现场证据
- 机器状态: `manifests/product_maturity_scorecard.json`
- 执行任务: `manifests/product_maturity_task_pack.json`
- 前序设计: `llm-agent-adk-target-architecture-2026-07-11.md`（已被本报告替代为 current）

## 执行结论

两仓在变更前不是终态成熟产品：ADK 主要是 YAML + shell 资产集合，Release workflow 调用不支持的 Codex direct target；多个 ops/monitor/perf/release 命令可能返回占位成功；根仓分析器输出未完成占位符；流水线吞掉阶段失败并调用 legacy auto-absorb；GitLab CI 全部允许失败。

本轮把核心路径升级为可执行的 3.0 资产平台：

- ADK 使用 JSON schema、类型化模型和统一 CLI，完成 deterministic export、事务安装/回滚、基准、安全扫描、评测、可复现发布和显式 publish backend。
- 根仓使用 commit-snapshot 静态分析、结构化 decision candidate/task pack 和 fail-fast pipeline；删除自动吸收写入口。
- CI、Release、Action pin、checksum、SBOM、负向测试和成熟度 SSOT 已落地。
- ADK 最终提交 `eec7cd1` 已推送；根仓新增 self-contained GitHub blocking CI，私有 ADK 子仓由独立仓 CI 负责全量门禁，本地整合门禁负责 gitlink/lock/worktree 对账。

当前总体成熟度仍是 **M3 / release-candidate**，不是 `terminal_mature`。工程与发布关键路径局部达到 M4；Codex 固定集对照已完成并有提升，但第二 runtime、长期操作反馈和真实现场证据仍未完成。硬件相关状态保持 `field_not_verified`。

## 产品目标与边界

### 终态目标

`llm_agent` 是参考实践的证据化 intake 与决策工作区；`agent-dev-kit` 是平台中立的 Agent 资产编译、安装、验证和发布控制面。两者共同回答“哪些实践值得采用、如何形成可靠资产、如何安全交付、效果是否真实提升”。

### 明确非目标

- 不实现通用 LLM 推理循环、模型网关、session scheduler 或生产 Agent runtime。
- 不执行 dirty 参考仓中的未提交代码。
- 不依据目录数量、报告数量或静态结构评分自动采纳。
- 不默认发布、推送、安装到 live home 或写入外部系统。
- 不用模拟 pilot 替代真实设备、团队或发布现场证据。

## 架构对账

### 变更前

```text
reference subrepos
  -> shell static scan -> placeholder markdown
  -> permissive pipeline -> legacy auto-absorb
  -> YAML/shell ADK -> inconsistent command semantics
  -> broken release target / non-blocking CI
```

主要问题：

1. `manifest.yaml` 是事实 SSOT，但缺少通用 schema/type model，脚本各自解析。
2. public CLI 混合真实命令、内部治理命令和占位运维命令。
3. install 没有稳定 plan/receipt/ownership contract；release publish 没有 backend 仍可表面成功。
4. 静态扫描没有结构化证据、决策边界、重复比对或 task contract。
5. `|| true` 与 `allow_failure: true` 破坏失败语义。

### 变更后

```text
registered reference @ immutable commit
  -> safe git-archive snapshot
  -> analysis.json + review-required decision + task pack
  -> approved ADK change artifact
  -> manifest.json/schema/type model
  -> deterministic adapters
  -> install plan/apply/receipt/rollback
  -> deterministic/runtime eval + security/performance gates
  -> reproducible artifact/checksum/SBOM
  -> explicit direct target or external source-to-live handoff
```

核心职责：

| 模块 | 职责 | 失败边界 |
|---|---|---|
| `tools.codex_assets.intake_pipeline` | commit 快照、静态证据、ADK 名称比对、决策候选、task pack | 路径越界、archive 异常、Git/dirty 分类失败即终止 |
| `tools.codex_assets.update_pipeline` | sync/diff/grade/analyze/pattern 报告编排 | 阶段非零立即停止并写 fail result |
| `agent_dev_kit.model` | manifest 加载、schema 语义、profile/target 解析 | 未知引用、重复、路径异常阻断 |
| `compiler` | 三个 direct target 的 deterministic export | external handoff 作为 direct target 时阻断 |
| `installer` | plan/apply/receipt/rollback、ownership 与 drift 检查 | 未托管冲突、过期 plan、digest 漂移阻断 |
| `quality/evaluation` | 性能、安全、deterministic 和 runtime 评测 | 安全失败、路由错误、runtime 错误不吞掉 |
| `release` | release check/build/publish、checksum、SBOM | 无 backend/制品/checksum/gh 时 publish 失败 |

## 功能成熟度

| 能力 | 变更前 | 当前 | 证据层 |
|---|---|---|---|
| 参考源快照 | 有 shell git archive | 安全 tar 成员校验、dirty 分类、结构化 source metadata | source/test |
| 深度分析 | 统计 + 占位符 | 完整静态证据、结构评分边界、ADK 重名比对 | source/test/runtime |
| 吸收决策 | 文档建议/自动写入口并存 | review-required JSON，自动写禁止 | source/test |
| Manifest | YAML + 多处解析 | JSON v3 + schema/type model；YAML 仅兼容镜像并受同步门禁 | source/test |
| Export | shell convert | 三 adapter deterministic export | source/test/runtime |
| Install | 一步式、所有权弱 | plan/apply/rollback + receipt + conflict/drift/TTL | source/test/runtime |
| Security | 分散检查 | secret/path/symlink/mode/action SHA 阻断扫描 | source/test/runtime |
| Performance | 旧脚本范围混杂 | manifest/profile/export 三个稳定平台基准 | source/runtime |
| Evaluation | 无双 runtime 契约 | 30 条 deterministic + opt-in Codex/Claude baseline/adk + comparison gate | source/test/runtime；Claude 因未认证保持 not-run |
| Release | broken Codex target | direct bundle + external handoff metadata + checksum/SBOM | source/test/runtime |
| CI | 全部 allow failure | 根仓与 ADK 关键 job 阻断 | source |

## 性能与成本

本轮 10 次本机基准：

| Operation | Median | P95 |
|---|---:|---:|
| manifest validate | 49.998 ms | 54.157 ms |
| profile resolve | 5.614 ms | 5.811 ms |
| export plan | 10.341 ms | 11.360 ms |

P95 使用 nearest-rank 计算，并由 `manifests/adk_performance_budgets.json:platform_operations` 统一阻断：当前上限依次是 200/50/100 ms，三项均通过。范围仅是资产平台本身，不代表模型推理延迟。真实 runtime eval 显式 opt-in，Claude 单任务设置预算上限，默认命令只生成计划，避免无意产生费用。完整回归耗时由 `tests/run_all.sh --timing-json` 保存，慢测应按证据优化，不能用跳过测试换取表面性能。

Codex 最终固定集对照使用相同的审批策略、同一 30 条任务和只读/no-tools 执行边界：baseline 综合成功率/路由/安全为 `90%/90%/100%`，ADK 为 `100%/100%/100%`，comparison gate 通过。baseline 总耗时 428.948 秒，ADK 总耗时 417.342 秒；延迟仅作观察值，不作为本轮效果放行条件。该结果是单次、显式关键词较强的代表集测量，没有置信区间，不能外推为所有模型、项目或模糊需求上的 100% 表现。

模型延迟的中位数由 `13586.498 ms` 降至 `13343.642 ms`，但 nearest-rank P95 由 `16920.324 ms` 升至 `18256.005 ms`。因此本轮只确认正确率与安全门禁提升，不声明尾延迟优化。

## 安全与供应链

- 安装目标和 archive 成员做 workspace containment 检查。
- 未托管目标冲突、source/manifest/installed digest 漂移均 fail closed。
- tracked 与 non-ignored untracked 的敏感文件名、凭证信号、仓库外 symlink、world-writable 文件和未 pin GitHub/container Action 阻断。
- 示例 token 只豁免明确 `YOUR_/EXAMPLE_/REDACTED_/CHANGEME_` 占位值。
- Release workflow 中 action 固定到 40 位 SHA；CI 覆盖 Python 3.8 与 3.12；制品包含 SHA256 和带 creation/dependency relationship 的 SPDX 2.3 SBOM。
- `publish` 只有显式 `--backend github`、版本匹配的 artifact、重新计算后匹配的 checksum 和可用 `gh` 才执行。
- 根仓不再提供自动吸收写脚本；静态分析不能触发 ADK 修改。
- 根仓 GitHub Actions 使用 SHA 固定的 checkout/setup-python 和 `contents: read`；不尝试用当前仓 `GITHUB_TOKEN` 越权读取私有 ADK 子仓。根仓运行自包含 contract/fixture/doc gate，ADK 仓运行 3.8/3.12 全量 gate。

## 发布与兼容

3.0 是允许破坏性收敛的 Major：公开命令使用 `export`、事务 `install`、`benchmark`、`eval`、`security`、`release`；ops/monitor/perf 不再出现在公共面。内部 shell 检查暂时作为治理兼容入口，由统一 CLI 调度。

三种 direct target 均通过 adapter 打包。Codex 保持 external handoff：`agent-dev-kit -> ~/codex -> ~/.codex`，必须走 source-to-live build/doctor/plan/dry-run/apply/check，不能由 export 或 release bundle 直接写 live home。

本轮 `b29a2ce..eec7cd1` 在 `agents/skills/optional-skills/workflows/templates` 无差异，只有 control plane、manifest、测试与文档变化。因此 source-to-live 结论是 `not-required-no-mapped-assets`，不为了制造证据执行无意义的 `~/.codex` 写入。最终 release 两次构建字节一致，SHA256 为 `4cd2e4b3bdb2676c3f4256751ced38c66ed713d10399470295e41ca7e834ba4a`；wheel SHA256 为 `f0b9b837a7eb3a42e4629daa166787a46190dac2e07f9b640855c654b31e9fb0`。

## 可维护性与长期资产

1. `docs/product-maturity-model.md` 定义跨仓 M0-M5 和四层证据。
2. `manifests/product_maturity_scorecard.json` 是当前成熟度机器 SSOT。
3. `manifests/product_maturity_task_pack.json` 保存剩余任务、验收和命令。
4. `manifests/report_registry.json` 固定 current/superseded 关系，历史报告不再竞争 SSOT。
5. ADK 变更由 `docs/changes/adk-v3-product-maturity/` 保存 proposal/design/tasks/negative/verify。
6. 参考源每个 commit 独立输出 evidence、decision、task pack，不把一次性内容写进 AGENTS。

Knowledge Hub 预检将本任务路由到 `projects/llm-agent/validation/`，并要求生成 candidate。`knowledge-capture --dry-run` 已为 `llm-agent-adk-v3-product-maturity-20260713` 生成 8 项只读事务计划，目标为 `projects/llm-agent/validation/2026-07-13-agent-dev-kit-v3-product-maturity.md`，状态 `reviewing`、`active_promotion=false`。Hub 当前存在用户未提交改动，且本任务提交范围只包含 llm_agent/ADK，因此未执行 apply，也未写 memory；仓内本审计报告是可复核来源。

当前主要维护债务是 YAML compatibility mirror 与旧内部 shell parser；它们已受语义一致性门禁约束，但后续应按使用数据逐步收敛，不在本轮大规模重写 18k 行 shell 造成不必要风险。

## 独立审查闭环

| ID | Severity | 发现 | 修复与复审 |
|---|---|---|---|
| R1 | major | wheel 后构建 release 可能夹带 `*.egg-info` | Git/release 双重忽略，source distribution inventory 负向断言通过 |
| R2 | major | `export --clean` 替换失败会丢旧版本 | 改为 staging backup/restore；注入第二次 rename 失败后旧 marker 保留 |
| R3 | major | runtime comparison 信任可篡改汇总字段 | 逐任务重算 metrics/gate/status；篡改 summary 被拒绝 |
| R4 | major | GitHub 远端没有根仓 CI，且递归 checkout 无权读取私有 ADK | 新增 root self-contained CI；ADK 独立 CI；本地做跨仓整合 |
| R5 | minor | tar 成员上限在 `getmembers()` 后才检查 | 改为流式成员计数，reference integrity fixture 通过 |

复审结论：blocker `0`、unresolved major `0`；ADK full regression `48/48`、quick `14/14`。代码与证据可进入提交，但 protected branch/release publish 仍由 repository owner 承担最终审查责任。

## 外部实践对标

| 官方/代表实践 | 成熟能力 | 本项目决策 |
|---|---|---|
| [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md/) | 层级指令与仓库定制 | 保留 AGENTS 路由，但长期状态迁出入口文件 |
| [OpenAI Agents SDK Runner](https://openai.github.io/openai-agents-python/running_agents/) | agent loop 与运行生命周期 | 明确属于下游 runtime，ADK 不复制实现 |
| [OpenAI Agents SDK Sessions](https://openai.github.io/openai-agents-python/sessions/) | 会话持久化 | ADK 只提供 context/handoff 资产，不做 session store |
| [OpenAI Agents SDK HITL](https://openai.github.io/openai-agents-python/human_in_the_loop/) | 外部动作审批与恢复 | install/publish/source-to-live 保持显式审批点 |
| [OpenAI Agents SDK Tracing](https://openai.github.io/openai-agents-python/tracing/) | trace/观测 | runtime eval 记录结构化结果与耗时；不声称具备完整 tracing backend |
| [LangGraph Persistence](https://docs.langchain.com/oss/python/langgraph/persistence) | checkpoint/thread/state 恢复 | 长流水线采用结构化状态与可重跑证据，不引入 runtime 依赖 |
| [Microsoft Agent Framework Checkpoints](https://learn.microsoft.com/en-us/agent-framework/workflows/checkpoints) | workflow checkpoint/resume | 作为未来长任务恢复参考，当前不扩张产品边界 |

对标结论：成熟不等于功能面越大。资产平台应与 runtime 通过 manifest、权限、评测和 handoff contract 连接；自行实现 runner/session/checkpoint 会扩大安全和维护面，且没有用户价值证据支持。

## 风险与未完成项

### Major

- Codex 30 任务 baseline/adk 已归档并通过 comparison gate；Claude CLI 未认证，30 任务 baseline/adk 均如实记录为 `not-run`，因此双 runtime 结论不成立。
- YAML compatibility mirror 仍存在，虽然 v3-only 字段和其余语义漂移已阻断。
- 同一 export/install target 的并发 writer 尚未做压力验证；操作契约假定每个目标同一时刻只有一个获批 writer，并依赖 conflict/drift gate，而不是分布式锁。

### Conditional

- 没有真实设备/团队 field pilot、升级周期、故障与维护成本证据，状态必须保持 `field_not_verified`。
- 根仓远端 GitHub CI 结果只有根仓 push 后才能确认，本地配置正确不等于远端已通过。

## 终态判断

- **可以声称**：3.0 产品架构与关键工程路径已经落地，具备本地 release-candidate 质量；发布、安装、回滚、安全和 deterministic eval 有真实实现；Codex 固定任务集较 baseline 提升 10 个百分点且安全不回退。
- **不能声称**：跨 runtime 效果已经全面优于 baseline、固定任务集等于开放世界表现、真实现场长期成熟、所有外部交付链路已经运行。
- **下一状态**：根仓回归、状态基线和 push 完成后，软件侧仍因 Claude 未认证、开放世界/长期采用证据不足而保持 M3；只有补齐跨运行时与长期运行证据才可重评 M4，只有真实 field evidence 才可能提升对应维度到 M5。

## Evidence Index

| Evidence | Purpose |
|---|---|
| `agent-dev-kit/docs/changes/adk-v3-product-maturity/negative-results.md` | before-fix/negative evidence |
| `agent-dev-kit/docs/changes/adk-v3-product-maturity/verify-report.md` | ADK 3.0 verification |
| `agent-dev-kit/docs/changes/adk-v3-product-maturity/benchmark.json` | performance baseline |
| `agent-dev-kit/docs/changes/adk-v3-product-maturity/codex-comparison-final.json` | Codex baseline/adk comparison |
| `agent-dev-kit/docs/changes/adk-v3-product-maturity/claude-adk-final.json` | Claude not-run boundary |
| `reports/adk-v3-release-evidence-2026-07-13.json` | reproducible release、wheel 和 no-live-write decision |
| `tests/test_product_maturity_contracts.sh` | root negative/contract gate |
| `tests/test_reference_source_integrity.sh` | immutable snapshot and dirty isolation |
| `reports/pipeline-report-2026-07-13.json` | structured pipeline result |
| `manifests/product_maturity_scorecard.json` | authoritative maturity status |
| `manifests/product_maturity_task_pack.json` | executable remaining work |
