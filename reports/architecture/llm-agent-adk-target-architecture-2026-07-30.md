# llm_agent / agent-dev-kit 全面优化评估与目标架构 - 2026-07-30

## Summary

- Current projection updated_at：2026-08-30
- Machine state remains authoritative：`manifests/product_maturity_scorecard.json`、
  `manifests/comprehensive_optimization_backlog.json`
- Current release status：`5.0.0-rc.2 source-pushed / clean-commit-bound / official-continuity-blocked`

本报告对 `llm_agent` 与 `agent-dev-kit` 的存在意义、目标、架构、功能、性能、可靠性、安全、可维护性、扩展性、资产体验和长期知识价值进行当前态复核。结论分为三层：

1. 产品边界是正确的：`llm_agent` 是 reference intake、采纳决策、证据和成熟度治理工作区；`agent-dev-kit` 是平台中立的 Agent/Skill/Workflow/Profile 编译、安装、评测与发布控制面。两者都不应演变为 LLM runtime。
2. 软件控制面已具备较强的 source/test/runtime-local 能力，但总体仍是 `M3 / release-candidate`。真实多 runtime、独立仓库、第二操作者、30 天现场周期和正式版本证据不足，不能用更多 fixture 或状态字段替代。
3. 本轮已把治理面熵、current report/backlog 演进、官方来源 freshness 和受支持工具链压成可执行门禁；剩余终态差距集中在真实 effectiveness、独立仓、第二操作者和 30 天 field evidence。

2026-08-30 增量实现已经完成或进入验证：

- backlog 已扩展到 G17-G22：统一 routing IR、平台中立 core、Workflow/Runtime completion、
  Evidence/Trace、Runtime Adapter 和 Agent value lifecycle。
- routing-ir/v2、Runtime Control policy/decision v2、Workflow IR v2、target-contract v2、Evidence Graph v1、
  Trace Summary v2 和 Agent value contract v1 已形成严格 schema/typed validator/正负测试。
- Trace 已提供 explicit per-run emitter；Agent Value 已提供 receipt-driven measurement API；两者都把缺失指标
  显式保留为 unavailable/not-measured，不宣称 automatic runtime integration。
- maintainability contract v2 已把 churn、owner concentration、inactive assets 升级为可重算 evidence metrics；
  当前没有 reviewed source，因此三项保持 not-available/null，而不是伪造为 0。
- Run Evidence composition 已连接 Trace 与 Agent Value；Effect Comparator 强制完整 task population、独立 run、
  不同 bundle、同 runtime/model 和 coverage-aware delta。Git candidate generator 已对当前仓两个 commit 做
  512-record dry-run，保持 review-required、未落盘、未修改 backlog。
- core 已移出 driver/C-C++/HIL 等嵌入式专属资产；通用 test strategy 与 embedded matrix 已分离。
- 28 条到期官方来源已逐条复核，freshness 使用固定 Asia/Hong_Kong 治理日且 future 继续 fail-closed。
- 当前 ADK full 为 68/68；Python 3.11.15/3.12.13 隔离 quick parity 各 29/29，含 wheel、dependency、
  static targets、30/30 deterministic routing；两个 runtime executable 在容器中均明确 not-run。
- 原 `4.0.0 -> 5.0.0-rc.1` rehearsal 使用了混入 5.x 内容的 previous artifact，已判定无效；`rc.2` exact-commit diagnostic transition 通过，但官方 4.0.0 artifact 仍不可用；
  正式 4.0 artifact `4c1e9b3c...` 当前不可用，Software M5 readiness 保持 not-ready。
- release build 已改为绑定 clean Git commit/tree，dirty/unbound snapshot 标记 `release_eligible=false`；
  exact `792a4cb` source transition 已修复 target-contract hard-cut 路径，但不能替代正式制品连续性。
- Claude Code 由 owner 显式裁决为默认通过；证据层保持 `owner-attested`、`runtime_measured=false`，
  不把默认接受升级成 native conformance 或正式 campaign 结果。
- 当前 Codex smoke 已绑定 manifest/commit/binary/bundle，Claude owner attestation v2 增加 version readback、review_after 和 immutable supersession；native target conformance、Trace/Agent Value 的真实 runtime adapter/receipt、双 runtime campaign、独立仓、
  第二操作者和 30 天 field 仍未完成；G20-G22/R6-R10 的真实 evidence 边界保持 in_progress/open。
- Validation orchestration新增L1-L4 diff plan；local-CI以稳定content-tree receipt复用supported full，成功日志压成摘要、失败日志只展开有界窗口；Runtime Control idle不再触发无效final gate。

2026-07-30 基线已经落地的低风险优化：

- `manifests/comprehensive_optimization_backlog.json` 升级为可演进的 v2 SSOT，保留 G1-G10 基线并增加 G11-G16。
- `scripts/check-architecture-reports.sh` 改为验证连续动态 ID，不再把 backlog 冻结为固定十项；历史报告不再因当前 backlog 扩展而被迫重写。
- `manifests/report_registry.json` 成为 current 架构报告的唯一选择入口；current-status 与产品成熟度测试不再硬编码 2026-07-13 报告路径。
- ADK 的目标架构模板明确支持 G11+ 项目级扩展，同时保持设计状态、实现状态和证据分离。
- G12 新增 7 项 maintainability growth budget，命名 root/ADK hotspot 并阻断无界增长。
- G13 通过固定 Docker 镜像完成 Python 3.11/3.12 full parity；两环境均为 57/57。
- G16 经 OpenAI 官方来源复核完成 `update`，恢复 official docs governance/strict gate。
- G14/G15 已形成不伪造现场证据的可执行 handoff；外部 owner、runtime、独立仓和时间门禁仍保持 blocked。

本轮 ADK 已形成本地 commit；没有执行父仓 commit、push、merge、tag、远端 release、source-to-live apply、Knowledge Hub promotion 或 `~/.codex` 写入。

## Scope

| Area | In Scope | Out of Scope |
|---|---|---|
| `llm_agent` | 使命、治理边界、参考源 intake、报告/manifest SSOT、门禁、性能与维护面评估 | 同步外部参考仓、清理用户 dirty、重写历史证据 |
| `agent-dev-kit` | 平台中立产品边界、资产编译/安装/评测/发布能力、模板、测试和维护面 | 修改正在进行的嵌入式远程调试 change、引入 LLM runtime |
| Runtime | direct target 静态合同、Codex external handoff、真实 runtime/field 证据缺口 | 自动认证 Claude、运行付费 campaign、直接写 `~/.codex` |
| Knowledge | Hub 预检、长期结论候选、current/superseded 关系 | 静默写 memory、绕过 owner review 做 active promotion |
| Delivery | 仓内 source、test、report 与机器 SSOT | 自动 commit/push/tag/release |

## Current Architecture Map

```text
外部实践 / 参考仓 / 官方资料
  -> llm_agent source registry + immutable snapshot
  -> candidate / decision / evidence / adoption matrix
  -> owner-approved neutral capability
  -> agent-dev-kit manifest + typed core + Agent/Skill/Workflow/Profile
  -> direct target contract 或 external handoff
       direct: claude-code / hermes-agent / opencode (experimental)
       handoff: agent-dev-kit -> ~/codex -> ~/.codex
  -> source / test / runtime / field evidence
  -> current-status + maturity scorecard + Knowledge Hub candidate
```

2026-07-30 历史审计快照（不代表 2026-08-30 当前工作树）：

| Surface | Historical Evidence | Interpretation |
|---|---:|---|
| root scripts | 88 个，其中 check scripts 60 个 | 治理覆盖广，但控制面存在分散和重复入口风险 |
| root manifests | 15 个 | 已有较强机器契约，新增 manifest 应先评估能否扩展现有 SSOT |
| root reports | 284 个 | provenance 丰富，但 current/superseded 和 retention 必须持续治理 |
| ADK assets | 13 Agents、55 core Skills、10 optional Skills、9 Profiles、7 Workflows | 功能面已足够丰富，默认策略应是复用或增强 |
| ADK engineering | 80 个测试、40 个 manifests | 合同和回归成熟，但维护与认知成本较高 |
| direct targets | 3 个，均为 experimental | 静态合同不等于真实 runtime 认证 |
| MCP servers | 0 | 正确保持显式、最小权限和不隐式安装边界 |

已观察到的规模热点：

- root shell 最大文件约 666 行；ADK shell 最大文件约 1745 行。
- root Python 最大模块约 2078 行；ADK Python 最大模块约 1054 行。
- 这些数字不是自动缺陷，但说明下一阶段应优先做边界拆分、薄 wrapper、共享解析器和趋势预算，而不是继续复制新入口。

## Target Architecture

目标架构保持六层，但增加“状态 freshness”和“控制面熵预算”两个横切能力：

| Layer | Owner | Stable Responsibility | Primary SSOT | Required Gate |
|---|---|---|---|---|
| L0 Entry Policy | root owner | 低 token 路由、权限与验证边界 | `AGENTS.md`, `README.md` | doc/token/coverage |
| L1 Source Registry | `llm_agent` | 来源、生命周期、dirty、runtime target | `subrepos/*`, `manifests/runtime_*.json` | lifecycle/state |
| L2 Decision Evidence | `llm_agent` | candidate、decision、adoption、current report | report registry、adoption matrix、backlog | evidence/freshness |
| L3 Neutral ADK Assets | ADK owner | 编译、安装、评测、发布、通用 Agent 资产 | `agent-dev-kit/manifest.json` + typed core | strict/full/security |
| L4 Runtime Handoff | target owner | direct target 或显式 source-to-live | target contracts、receipt/evidence index | dry-run/apply/health |
| L5 Knowledge Feedback | Hub owner | 脱敏长期结论与复审 | Hub candidate/active/archive | owner review/promotion |
| Cross-cut A | shared | 状态过期、current 指针、evidence freshness | report registry + current-status | reconciliation |
| Cross-cut B | shared | scripts/manifests/reports/modules 增长预算 | health/timing/maintainability baseline | trend gate |

终态原则：

- 功能缺口先映射到已有 Agent、Skill、Workflow、typed core 或 manifest，只有无法复用时才新增资产。
- current 状态由 registry/manifest 选择，不在 checker、test、README 中重复硬编码路径。
- 历史报告只作 provenance；当前 backlog 扩展不得要求篡改历史报告。
- 性能结论区分本地 control-plane、真实 runtime、并发 writer 和 field scale。
- release、live apply、Knowledge promotion、参考仓清理分别授权，不能共享一个“完成”状态。

## Responsibility Boundary

| Decision | `llm_agent` | `agent-dev-kit` | Must Not Do |
|---|---|---|---|
| 为什么跟踪某实践 | source registry、candidate、decision、evidence | 只接收已批准且平台中立的能力需求 | 直接复制第三方资产 |
| 能力如何实现 | 记录目标层和验收证据 | typed core、Agent/Skill/Workflow/Profile、测试 | 绑定单一厂商 runtime |
| 能否进入运行态 | runtime registry、handoff evidence、健康报告 | direct contract 或 external handoff metadata | 绕过 `~/codex` 写 `~/.codex` |
| 是否达到成熟度 | scorecard、task pack、field policy | 提供可重算 source/test/runtime 证据 | 用 fixture 冒充 field evidence |
| 是否进入长期知识 | 生成脱敏 candidate | 输出可复用通用结论 | 静默写 memory 或 active Hub |

## Architecture Operating Model

| Loop | Input | Decision | Write Surface | Exit Evidence |
|---|---|---|---|---|
| Intake | URL、参考仓、官方文档 | adopt / observe / reject | candidate、queue、matrix | 独立 decision |
| Productization | approved neutral pattern | reuse / adapt / build | ADK source + test | strict/full gate |
| Delivery | versioned asset | direct target / handoff | plan、receipt、evidence index | health/rollback |
| Effectiveness | task/runtime/pilot | pass / partial / blocked | eval、campaign、field ledger | source/test/runtime/field |
| Maintenance | drift、staleness、growth | refresh / consolidate / retire | current report、backlog、archive | trend/freshness gate |
| Knowledge | durable conclusion | candidate / active / archive | Hub governed item | owner review |

## SSOT Matrix

| Fact Type | Source of Truth | Stale Condition | Repair Action |
|---|---|---|---|
| 产品边界与版本 | `agent-dev-kit/manifest.json` | README/lock/version 不一致 | strict validate + sync repair |
| 当前成熟度 | `manifests/product_maturity_scorecard.json` | 报告比机器状态旧或越级声明 | 重算 scorecard，不重写证据 |
| 当前架构报告 | `manifests/report_registry.json` | 0 个或多个 current，或 current 文件缺失 | 新报告 supersede，registry 原子更新 |
| 全面优化队列 | `manifests/comprehensive_optimization_backlog.json` | ID 不连续、source report 不一致、blocked 无条件 | backlog gate fail closed |
| 当前仓状态 | `reports/current-status.md` | 超 freshness、commit/lock/gitlink 不一致 | 先对账再刷新 |
| ADK 运行交付 | target receipt/evidence index 或 `~/codex` source-to-live evidence | 缺 plan/apply/health 或发生 drift | 停止 live claim，重新 plan |
| 长期知识 | Hub governed status | candidate 被误当 active、owner review 过期 | 保持 reviewing 或重新复核 |

## Issue Map

| ID | Severity | Finding | Evidence | Action |
|---|---|---|---|---|
| F01 | blocker | `reports/current-status.md` 已过期 11 天，且记录的 ADK commit 与 gitlink、`adk.lock`、worktree 不一致 | `check-current-status-consistency` exit 1 | 用户 dirty 收口后独立执行状态对账；本轮不伪造刷新 |
| F02 | blocker | ADK strict 子仓当前有 6 项用户改动，根健康状态为 `needs-fix` | `check-subrepo-state` exit 1 | 不覆盖；等待该 change 完成、保留或拆分 |
| F03 | resolved-local | 宿主 Python 3.8.10 不满足基线，但固定 Python 3.11/3.12 parity 路径可用 | 两环境 full parity 57/57 | 宿主保持 development-only；release evidence 使用 parity |
| F04 | blocker | 多 runtime、独立仓、第二操作者、30 天和 field events 未闭环 | Software M5 status | 保持 M3/blocked，不用 synthetic evidence 替代 |
| F05 | major | backlog checker 固定 G1-G10，扩展会强迫修改历史报告和多处测试 | before-fix checker source | 本轮升级 v2 动态连续 ID 与 source report |
| F06 | major | current 报告路径在 checker/test 中硬编码为 2026-07-13 | before-fix source scan | 本轮改为 registry-driven |
| F07 | resolved-gate | root/ADK 脚本、报告、manifest 和大文件热点形成治理熵 | maintainability budget strict pass | 7 项 baseline/warning/hard limit 已机械化 |
| F08 | major | 本地性能预算通过，但无 field-scale 和当前环境 release-grade 证据 | benchmark + doctor | 保留 `verified_local`，补并发/现场趋势 |
| F09 | blocker-external | repository ownership 已落地，但长期维护证据仍集中于单一操作者 | readiness pass + M5 operator blocker | 第二操作者/独立 reviewer 必须真实参与 |
| F10 | minor | Architecture README 的“当前报告”描述与 report registry 已漂移 | README/registry 对比 | 本轮同步为 registry-driven current |
| F11 | minor | Hub 相关条目仍为 `reviewing`，不能作为 active 当前事实 | Knowledge Hub preflight | 完成时生成 candidate 或明确不 promotion |
| F12 | resolved | 官方模型目录记录曾于 2026-07-27 过期 | OpenAI official review + governance pass | decision=`update`，expiry=2026-10-28，保持 watch-only |

## Structured Requirements Review

| Dimension | Confirmed Requirement | Success Criteria | Non-Goal / Boundary |
|---|---|---|---|
| Goal | 全面评估并优化两个仓库的长期价值 | 使命、目标、架构、功能、性能、维护和长期资产均有证据结论 | 不以新增功能数量衡量成功 |
| Deliverable | 形成可审查报告和实际仓内优化 | current 报告、backlog、checker、test、ADK 模板一致 | 不只输出聊天建议 |
| Scope | 同时覆盖 `llm_agent` 和 `agent-dev-kit` | 两仓职责不混淆，改动避开用户 dirty | 不同步或清理参考仓 |
| Quality Dimensions | 功能、效果、性能、可靠性、安全、体验、维护、扩展、知识均评估 | 每个关键 gap 有优先级、阻塞条件和验证 | 不把本地 pass 外推为 field pass |
| Long-term Asset | 结论可演进、可恢复、可验证 | current registry、动态 backlog、通用模板、证据索引 | 不静默写长期 memory |
| Execution Constraint | 保留用户改动并遵守权限 | 无 commit/push/live apply，所有修改可 diff 审查 | 不扩大外部权限 |

## Landing Protocol

| Level | Meaning | Evidence |
|---|---|---|
| report-only | 只形成评估与候选 | report + Evidence Index |
| source-staged | 工作树存在实现改动 | diff + targeted tests |
| source-committed | owner 明确授权并形成 commit | immutable commit |
| dry-run-verified | 安装/发布计划已只读验证 | plan + zero unexplained destructive actions |
| live-applied | 真实运行态已应用并健康 | apply receipt + health + rollback |
| knowledge-promoted | 长期知识已 owner review 后提升 | Hub governed status |

本轮最高只声明 `source-staged`。没有 commit、live apply 或 knowledge promotion 证据。

## Runtime Delivery Contract

| Field | Contract |
|---|---|
| Approval Boundary | direct target apply、`~/codex -> ~/.codex` apply、发布和 rollback 分别需要明确授权 |
| Dry-run Evidence | plan 必须列出 copy/overwrite/delete、digest、target 和权限边界 |
| Apply Evidence | receipt、实际变更集、版本、hash 和回滚指针必须完整 |
| Health Gate | direct runtime 或 Codex live health 必须在同一证据窗口内通过 |
| Stop Condition | 出现未知 overwrite/delete、凭证输出、路径越界、digest drift 或健康失败立即停止 |

## Knowledge Promotion Contract

| Field | Contract |
|---|---|
| Sanitization | 不保存凭证、raw session、完整日志、二进制或本机私有路径 |
| Review Owner | owner 必须复核长期适用范围、证据强度和 review_after |
| Promotion Mode | 默认 candidate/reviewing；active/archive 是独立动作 |
| Forbidden Action | 禁止把仓内 report、memory 或 historical archive 自动当作 active |
| Rollback | 错误提升以 superseded/rejected 记录替代，不静默改写历史 |

## State Reconciliation Contract

| State Claim | Source of Truth | Stale Condition | Repair Action |
|---|---|---|---|
| current architecture | report registry | current 数量不等于 1 或文件不存在 | 更新 registry 和报告链 |
| ADK source version | manifest + gitlink + `adk.lock` | ADK commit mismatch | 先收口 ADK change，再同步锁 |
| root current status | current-status + verification time | 超 freshness 或门禁结果变化 | 重新运行门禁并刷新索引 |
| live-applied | source-to-live evidence | 缺 apply/health 或内容漂移 | 降级声明并重新 plan |
| knowledge active | Hub governed status | 只有 candidate 或 review 过期 | 保持 reviewing |

## Status Consistency Gate

`rtk scripts/check-current-status-consistency.sh . --summary-json` 必须继续拦截：

- stale `IN PROGRESS` 或陈旧验证日期；
- ADK commit mismatch；
- 缺少 source-to-live 证据的 live 声明；
- candidate 被写成 active promotion claims；
- report registry 没有且仅有一个存在的 current 报告。

current 报告的具体路径必须由 `manifests/report_registry.json` 驱动，checker 和 test 不再复制路径常量。

## Phase Roadmap

| Phase | Goal | Done Criteria | Verification |
|---|---|---|---|
| Phase 1 | 修复可演进 SSOT | current report registry-driven；backlog 支持 G11+ | architecture/current-status tests |
| Phase 2 | 建立治理熵预算 | 脚本、manifest、report、热点模块有 baseline、owner、阈值和合并队列 | health + maintainability gate |
| Phase 3 | 支持发布级本地环境 | Python 3.11/3.12 与固定依赖可重复运行 | doctor + strict/full/local parity |
| Phase 4 | 补真实 runtime 效果 | direct target discovery/load/trigger/permission 有真实证据 | target smoke + campaign |
| Phase 5 | 补长期 field 证据 | 独立仓、第二操作者、30 天、事件和维护成本完整 | software M5 certifier |
| Phase 6 | 收敛长期知识 | owner 复核本报告候选，设置 review_after | Hub candidate/status |

## Implementation Tasks

| ID | Priority | Task | Files | Stop Condition | Verification |
|---|---|---|---|---|---|
| A1 | P0 | backlog v2 与动态连续 ID | manifest、architecture checker/test | 历史报告被迫重写或 ID gap 未捕获 | architecture tests |
| A2 | P0 | current report registry-driven | registry、current-status checker/tests | 0/多 current 或 current 文件缺失 | current-status/product maturity tests |
| A3 | P1 | ADK 模板支持 G11+ | target architecture template/test | G1-G10 基线丢失 | ADK template/quality tests |
| B1 | P1 | 建立控制面熵 baseline 与预算 | health、typed checker、report retention | 阈值只追求删文件而破坏证据 | token/doc/full gates |
| B2 | P1 | 拆分 shell/Python 热点 | root tools、ADK typed core | 公共 CLI 或证据语义变化 | targeted + full regression |
| C1 | P1 | 支持 Python 3.11/3.12 | reviewed environment/local CI parity | 下载或安装未经授权 | doctor/strict/full |
| C2 | P1 | 复核过期官方来源 | official freshness manifest + review evidence | 未读取官方来源或 provenance 不完整 | official-docs + strict |
| D1 | P0 | 真实 runtime 与 field campaign | target/campaign/field evidence | 未认证、超预算或外部权限缺失 | M5 gates |
| E1 | P1 | 多维护者 ownership | ownership contract、review evidence | owner 未确认职责 | readiness + field review |

## Comprehensive Optimization Backlog

机器可读 SSOT 是 `manifests/comprehensive_optimization_backlog.json`。G1-G10 是长期基线；G11-G16 是
2026-07-30 审计新增项；G17-G22 是 2026-08-30 综合设计评估进入实现后的增量。设计状态与实现状态分离，
blocked 项必须写清不能由本地代码替代的 blocking condition。

| ID | Priority | Optimization Area | Terminal Outcome | Implementation Target | Verification |
|---|---|---|---|---|---|
| G1 | P0 | Goal and scope control | 跨仓目标有边界、停止条件和证据 | goal/template/status | architecture/current-status gate |
| G2 | P0 | Governance correctness | registry、adoption、lifecycle、baseline 不矛盾 | governance gates | intake/adoption/subrepo |
| G3 | P0 | Evidence integrity | 完成声明绑定命令和负结果 | evidence bundle/audit | quick/full evidence |
| G4 | P1 | Functional coverage | 优先增强现有能力 | manifest/routing/capability | capability/workflow |
| G5 | P1 | Performance and token cost | 默认入口短，深证据按需读取 | token/benchmark | token + benchmark |
| G6 | P1 | Maintainability | 每类状态有唯一入口 | registry/current/Hub | doc/current gate |
| G7 | P1 | Extensibility | runtime/source/profile 先 candidate/dry-run | registry/intake | target/intake gates |
| G8 | P1 | Asset experience | 从低 token 入口找到命令和 runbook | docs/catalog | coverage/template |
| G9 | P2 | Knowledge retention | candidate 经 owner review 后提升 | Hub candidate | Hub dry-run/status |
| G10 | P2 | Release and rollback clarity | release/live/knowledge/cleanup 分别审批 | plan/receipt/removal | delivery/removal |
| G11 | P0 | State freshness and report evolution | current 与 backlog 可换代且不改历史报告 | registry-driven report + dynamic IDs | architecture/current-status tests |
| G12 | P1 | Control-plane entropy and consolidation | 有增长预算、热点和合并队列 | health baseline + thin wrappers | health/token/doc |
| G13 | P1 | Supported toolchain portability | 发布验证只使用受支持环境 | Python/dependency baseline | doctor/local parity |
| G14 | P0 | Runtime and field effectiveness | 真实多 runtime 与独立长期证据支持结论 | campaign/field ledger | M5/target gates |
| G15 | P1 | Maintainer scalability and succession | ownership、复审继任和多操作者证据完整 | owner contract/rehearsal | readiness/M5 |
| G16 | P1 | External source freshness and provenance | 官方来源有当前检索、到期和复审决策证据 | freshness manifest/review | official-docs/strict |
| G17 | P0 | Unified routing intent and permission IR | task mode、否定、权限和 abstain 由单一 fail-closed IR 裁决 | routing-ir/v2 + cross-mode mapping | routing contrastive/negative |
| G18 | P0 | Platform-neutral core profile | core 不导出嵌入式专属 Agent/Skill/参考矩阵 | core/embedded capability closure | profile/target/taxonomy |
| G19 | P0 | Workflow and runtime completion semantics | typed Workflow IR 与 task-mode artifact gate 不允许旁路完成证据 | workflow-ir/v2 + runtime-control/v2 | workflow/runtime tests |
| G20 | P0 | Typed evidence graph and outcome traces | provenance DAG 和 outcome trace 脱敏、类型化、可寻址 | Evidence Graph + trace schema | graph/trace/security tests |
| G21 | P0 | Runtime adapter conformance | static 声明与 native runtime 证据分离，至少一个 target 完成真实 conformance | target-contract/v2 adapter | target/native campaign |
| G22 | P1 | Agent, skill and profile value lifecycle | 角色权限、调用、误路由、abstain、outcome 和退役信号可验证 | typed role/value contract | capability/routing/field |

## Verification Gates

| Command | Expected |
|---|---|
| `rtk scripts/check-architecture-reports.sh . --summary-json` | current report、G1-G22、registry 和模板一致 |
| `rtk scripts/check-maintainability-budgets.sh --strict --summary-json` | 11 项数量、行数、import fan-out、exact duplication 预算和 drift 无 warning/failure |
| `rtk tests/test_architecture_reports.sh` | 当前、fixture 和负例通过 |
| `rtk tests/test_current_status_consistency.sh` | registry-driven current 与状态负例通过 |
| `rtk tests/test_product_maturity_contracts.sh` | current report 不依赖固定日期路径 |
| `rtk bash agent-dev-kit/tests/test_templates.sh` | G1-G10 基线与 G11+ 扩展提示通过 |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | 本机 development-only；受支持环境由 local CI parity 证明 |
| `rtk bash agent-dev-kit/scripts/run-local-ci-parity.sh --python all --mode full` | Python 3.11/3.12 各 57/57，dependency audit pass |
| `rtk scripts/check-doc-sync.sh .` | README、report 与门禁入口一致 |

## Rejected Options

| Option | Decision | Reason |
|---|---|---|
| 继续增加平行 Skill/Workflow 代表“优化” | reject | 当前功能面已丰富，会增加 routing 冲突和维护面 |
| 修改历史 2026-07-11 报告以容纳所有未来 G 项 | reject | 破坏 provenance；应由 current source report 承载扩展 |
| 把 Python 3.8 quick pass 当作 release pass | reject | doctor 已明确依赖和解释器不受支持 |
| 用 fixture、self pilot 或文档声明关闭 field blocker | reject | 违反 source/test/runtime/field 证据模型 |
| 在本轮清理用户 dirty 或同步 gitlink/adk.lock | reject | 用户改动未收口，存在覆盖风险 |
| 直接 apply 到 `~/.codex` | reject | 本轮没有 source-to-live 授权与必要性 |

## Evidence Index

| Command | Exit Code | Result Summary | Layer |
|---|---:|---|---|
| `rtk bash agent-dev-kit/tests/run_all.sh --fail-fast --timing-json /tmp/adk-comparator-full-final.json` | 0 | CR9 最终整合树 68/68 | regression-current |
| `rtk bash agent-dev-kit/tests/run_all.sh --quick --fail-fast --timing-json /tmp/adk-comparator-quick-final.json` | 0 | CR9 最终整合树 30/30 | regression-current |
| `rtk bash agent-dev-kit/scripts/run-local-ci-parity.sh --python all --mode quick` | 0 | source snapshot `eaa47e8f59eeb232532efacb17117d062349aa5f3c578c8d0d131587b2a99827`；Python 3.11.15/3.12.13 各 30/30；wheel 独立 venv 安装后 Trace/Evidence schema smoke、dependency audit、strict/security/eval/release check pass | supported-toolchain-current |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | 0 | official freshness、manifest/schema、target v2 和新 typed contracts pass；宿主 Python 3.8 仅 development | governance-current |
| `rtk bash agent-dev-kit/scripts/devkit.sh benchmark run --iterations 5 ...` | 0 | development-only P95：validate 128.864ms、profile 5.23ms、plan 68.544ms、target 204.599ms、cold start 674.87ms、10x I/O 832.499ms；peak 261.547KiB，全部预算 pass | performance-current |
| `rtk scripts/check-all.sh --quick --working-tree` | 1 | 53/55；仅 current-status/Software M5 因 release rehearsal manifest digest stale fail-closed | workspace-current-negative |
| `rtk scripts/check-architecture-reports.sh . --summary-json` | 0 | current report、22 个连续 backlog 项和 registry 结构一致 | governance-current |
| `rtk scripts/check-maintainability-budgets.sh --strict --summary-json` | 0 | 11 个 static budget pass；3 个 evidence metric evaluator 可用，当前 source 均 not-available/null；不宣称健康 | maintainability-current |

## Appendix A：Superseded 2026-07-30 Provenance（不属于 Current Evidence Index）

以下仅保留当时的负结果和 provenance，不参与 2026-08-30 当前状态判定，也不得与上方 current rows
合并计数或用于 release/completion 声明。

| Command | Exit Code | Historical Result Summary | Layer |
|---|---:|---|---|
| `rtk scripts/health-check.sh --summary-json` | 0 | `status=needs-fix`；root 88 scripts/284 reports，ADK 13 Agents/65 Skills/80 tests | workspace |
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 1 | 3 known dirty + 1 unexpected strict dirty (`agent-dev-kit`) | negative |
| `rtk scripts/check-current-status-consistency.sh . --summary-json` | 1 | verification stale 11 days；ADK commit/lock/gitlink/worktree 不一致 | negative |
| `rtk bash agent-dev-kit/scripts/devkit.sh doctor --summary-json` | 1 | Python 3.8.10 与依赖版本不满足 release baseline | negative |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --quick` | 0 | quick source validation pass，但明确为 development-only | source-test |
| `rtk bash agent-dev-kit/scripts/devkit.sh capability health --summary-json` | 0 | 8 capabilities、62 checks、0 failures | source-test |
| `rtk bash agent-dev-kit/scripts/devkit.sh benchmark run --iterations 3 --output /tmp/adk-comprehensive-assessment-benchmark.json --summary-json` | 0 | 本地预算全 pass；cold-start P95 656.498ms；10x I/O P95 1002.76ms | performance-local |
| `rtk bash agent-dev-kit/scripts/devkit.sh performance check --summary-json` | 2 | 被证伪路径：公共命令是 `benchmark`，不是历史/猜测的 `performance` | negative |
| `rtk tests/run_all.sh --timing-json /tmp/llm-agent-comprehensive-optimization-root-full-final.json` | 0 | root full 17/17 pass | regression |
| `rtk bash agent-dev-kit/tests/run_all.sh --quick --timing-json /tmp/llm-agent-comprehensive-optimization-adk-quick.json` | 1 | 19/20 pass；唯一失败为官方来源 freshness 过期 | regression-negative |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict --summary-json` | 1 | `openai-latest-model-gpt-5-5` 于 2026-07-27 过期 | governance-negative |
| `rtk scripts/check-architecture-reports.sh . --summary-json` | 0 | 3 份受治理报告；16 个连续 backlog 项；current/source report 一致 | governance |
| `rtk tests/test_architecture_reports.sh` | 0 | current、连续 ID、registry mismatch、legacy 和缺文件负例通过 | regression |
| `rtk tests/test_current_status_consistency.sh` | 0 | registry-driven current 与 stale/commit/promotion 负例通过 | regression |
| `rtk bash agent-dev-kit/tests/test_templates.sh` | 0 | 19/19；G1-G10 基线和 G11+ 扩展通过 | ADK asset |
| `rtk bash agent-dev-kit/scripts/devkit.sh target check --all --level static --summary-json` | 0 | 3 个 experimental direct target 静态合同通过；非 runtime 认证 | target-static |
| `rtk bash agent-dev-kit/scripts/devkit.sh security check --summary-json` | 0 | 811 files，0 failures，0 warnings；当前环境仅作 development evidence | security-local |
| `rtk bash ~/knowledge-hub/tools/knowledge-capture.sh ... --dry-run --json` | 0 | planned reviewing decision；transaction `kh-20260730T134750Z-e0db299f`；10 changed paths；未 apply/未 active promotion | knowledge-candidate |

## Goal Closure State

- goal_statement: 全面评估并优化 llm_agent 与 agent-dev-kit 的存在意义、目标、架构、功能、性能、可维护性和长期资产
- completion_claim: G17-G22 的 source/test 控制面、R7-R9 emitter/evaluator 与 test-only Run Evidence composition 已形成并通过 ADK full 与双 Python quick；
  当前不是 release-ready，release rehearsal digest、native conformance、真实 runtime/field receipt/campaign 和
  reviewed maintainability source 保持 open
- required_evidence: backlog/report/checker/template diff；定向测试；root/ADK 回归；状态和环境负证据
- claimant: current Codex implementation session
- verifier: repository gates plus owner review
- open_items: G9、G10、G13-G15、G17-G22；新版本与 release rehearsal；用户 dirty；native conformance、
  automatic runtime adapter、真实 value receipt/maintainability source、双 runtime、independent repository、
  second operator、30-day field evidence
- retry_budget: 同一验证失败最多 2 次，第二次后 replan
- staleness_threshold: 任一目标仓 HEAD/相关 working-tree fingerprint 变化或 45 分钟无新证据时重新复核
- heartbeat: implementation and scoped verification complete; overall product closure remains needs-fix on documented blockers
- stop_condition: pass / replan / split / blocked / abort
