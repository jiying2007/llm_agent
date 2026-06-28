
## 关于 rtk 命令

`rtk` 是工作区统一命令入口工具。位于 `llm_agent` 受治理工作区时，所有 shell 命令必须通过 `rtk` 执行；不要在本工作区文档、门禁或会话中使用裸 `bash`、`git`、`rg`、`sed`、`awk`、`python` 等命令作为执行入口。

**rtk 与 bash 的对应关系：**
- `rtk scripts/xxx.sh` 等价于 `bash scripts/xxx.sh`
- `rtk bash -lc "..."` 等价于 `bash -lc "..."`

**安装 rtk：**
```bash
# 本工作区默认要求 rtk；缺失时先安装或修复 rtk，再执行维护命令。
```

# llm_agent 持续维护与生产验证指南

## 1. 定位

`llm_agent` 是 adk 的上游治理工作区，负责四件事：

1. 管理参考子仓清单与同步策略。
2. 从参考子仓提炼可采纳实践，并记录采纳/观察/拒绝原因。
3. 推动 `agent-dev-kit` 落地、验证，并导出可交接资产。
4. 将 adk 资产交给 `~/codex` 作为声明式 Codex Home 源，再由 `~/codex` build/apply 到 `~/.codex`，最后把真实运行结果回灌。

不推荐在 `llm_agent` 中直接改 `~/.codex` 运行资产。生产运行资产应先由 `agent-dev-kit` 导出，经 `~/codex` 注册到 `src/codex-home/` 与 `manifests/`，再由 `~/codex/scripts/build.sh` 和 `~/codex/scripts/apply.sh` 注入 `~/.codex`。报告需记录 adk 版本、profile、optional skill、`~/codex` build/apply 证据和 `~/.codex` 健康检查结果。

## 2. 目录职责

| 路径 | 职责 | 维护要求 |
|---|---|---|
| `AGENTS.md` | 工作区全局规则、参考子仓总览、维护记录 | 规则或流程变化时同步更新 |
| `subrepos/registry.csv` | 参考子仓单一清单 | 新增/禁用子仓必须更新 |
| `subrepos/adoption-matrix.md` | 候选采纳矩阵 | 每个候选必须有决策、状态、目标层和证据 |
| `subrepos/adoption-matrix.jsonl` | 候选矩阵结构化导出 | 由 Markdown 矩阵机械生成，供脚本低 token 读取 |
| `subrepos/phase-gate.env` | 是否允许追踪上游更新 | 默认先压实 adk，再开门同步 |
| `subrepos/dirty-baseline.tsv` | observe 子仓预期 dirty 状态 | 区分已知参考仓噪音与本轮风险 dirty |
| `adk.lock` | adk 版本和子模块指针锁 | adk 升级或子模块指针变化时同步更新 |
| `manifests/` | OSS intake P1-P4 发现、评分、生命周期、注册、移除和周期运行声明 | 修改后必须运行 OSS intake 检查 |
| `fixtures/oss-intake/` | OSS intake 正负样例 | 修改后必须运行 OSS intake fixture 测试 |
| `tests/` | 根仓定向回归测试 | 新增脚本或 fixture 后补相应测试入口 |
| `scripts/` | 治理、同步、门禁脚本 | 新脚本必须写入 `scripts/README.md` |
| `reports/` | pilot、安装、周报、wave 记录 | 生产结论必须有报告证据 |
| `agent-dev-kit/` | adk 源资产与测试 | 所有候选能力先在这里压实并导出 |
| `~/codex` | 本机 Codex CLI 声明式资产仓库 | 吸收 adk 资产，执行 build/doctor/apply，再影响 `~/.codex` |

## 3. 维护流程

### 3.1 日常健康检查

```bash
rtk scripts/check-doc-sync.sh .
rtk scripts/check-adk-lock.sh .
rtk scripts/check-phase-gate.sh .
rtk scripts/check-subrepo-state.sh .
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-oss-intake-ledger.sh .
rtk scripts/check-oss-registration-plan.sh .
rtk scripts/check-oss-removal-plan.sh .
rtk scripts/check-oss-continuous-operation.sh .
rtk scripts/check-oss-approval-queue.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-stale-references.sh .
rtk scripts/check-token-budget.sh . --summary-json
rtk scripts/check-file-modes.sh .
rtk scripts/check-global-codex-health.sh ~/.codex minimal
```

适用场景：只确认当前状态是否健康，不同步参考仓，不部署。

### 3.2 adk 压实检查

```bash
rtk scripts/check-adk-harden-readiness.sh .
```

适用场景：修改了 adk 文档、profile、skill、agent、workflow 或 root scripts 后，需要确认基础门禁。

### 3.3 生产级放行检查

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

适用场景：准备声明 adk 可进入 `~/codex` 生产分发链路，或准备由 `~/codex` 重新 apply 到 `~/.codex`。

该门禁会检查：

- adk strict validation
- optional skills 回归
- 外部仓库引用隔离
- skill metadata
- skill routing conflicts
- docs sync
- adoption matrix 状态
- observe backlog / delivery adopt 深度
- runtime routing
- upstream intake readiness
- adk full regression suite
- codex pilot evidence
- codex pilot coverage
- `~/codex` build/apply 证据与 global `~/.codex` health

### 3.4 参考子仓同步

开源仓库发现、评分、自动注册和自动移除的终态设计见 `docs/runbooks/oss-intake-lifecycle.md`。现有 `sync-subrepos` / `diff-scan` 流程只处理已登记子仓，不替代候选发现和生命周期治理。

同步前先跑：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

同步和扫描：

```bash
rtk scripts/sync-subrepos.sh . fetch
rtk scripts/diff-scan.sh . 7 reports/weekly-change-report.md
```

若门禁未开，脚本会阻止同步。不要用 `--force` 常态绕过，除非只是一次性紧急扫描并会在报告里说明原因。

### 3.5 候选吸收

候选吸收默认先走 `docs/runbooks/oss-intake-lifecycle.md` 中的 candidate ledger、scoring、analysis 和 decision 流程。只有正式登记为治理来源后，才更新 `subrepos/adoption-matrix.md`。

P1-P4 基座使用 root manifests、candidate JSONL、fixtures、plan report、approval queue 和 cycle report；P1/P4 保持 report-only，P2 默认 dry-run，P3 只生成/校验 removal plan。统一入口优先用 `rtk scripts/oss-intake.sh status|cycle|queue|score|plan-onboard|plan-remove|check`：

```bash
rtk scripts/check-oss-intake-ledger.sh .
rtk scripts/discover-oss-repos.sh . --dry-run --repo example/manual-discovery --out /tmp/oss-discovery-candidates.jsonl
rtk scripts/discover-oss-repos.sh . --dry-run --github-query "topic:agent archived:false" --github-max-results 30 --github-rate-limit-out /tmp/oss-discovery-rate-limit.json --out /tmp/oss-discovery-candidates.jsonl
rtk scripts/score-oss-candidates.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --out reports/oss-score-report-2026-06-16.md
rtk scripts/onboard-oss-candidate.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --repo example/runtime-policy-gates --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md
rtk scripts/plan-oss-subrepo-removal.sh . --repo codex
rtk scripts/run-oss-intake-cycle.sh .
rtk scripts/run-oss-intake-cycle.sh . --discover-github --github-query "topic:agent archived:false"
rtk scripts/generate-oss-intake-approval-queue.sh .
rtk scripts/generate-oss-intake-approval-queue.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --rate-limit reports/oss-discovery-rate-limit-2026-06-16.json
rtk tests/test_oss_discovery.sh
rtk tests/test_oss_intake_ledger.sh
rtk tests/test_oss_registration_plan.sh
rtk tests/test_oss_removal_plan.sh
rtk tests/test_oss_continuous_operation.sh
rtk tests/test_oss_approval_queue.sh
```

1. 在 `subrepos/adoption-matrix.md` 增加候选行。
2. 给出 `adopt/observe/reject`。
3. 对 `adopt + done`，必须有本地证据路径。
4. 对 delivery 类 adopt，必须覆盖 Agent/Skill/Workflow 至少一层。
5. 对安全、脚本、第三方资产，先走 `adk-security-supply-chain`。
6. 最终执行：

```bash
rtk scripts/check-adoption-matrix-status.sh .
rtk scripts/export-adoption-matrix-jsonl.sh .
rtk scripts/check-adoption-matrix-structured.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

## 4. adk 变更分级

| 变更类型 | 最小验证 | 说明 |
|---|---|---|
| 文档说明 | `rtk scripts/check-doc-sync.sh .` | 若涉及 adk docs，还应跑 adk 相关测试 |
| runbook / workflow 文档 | `rtk agent-dev-kit/tests/run_all.sh` | 防止 catalog、格式、引用漂移 |
| Agent/Skill 内容 | `rtk agent-dev-kit/tests/run_all.sh` | 会覆盖 frontmatter、内容质量、触发矩阵 |
| profile / manifest | `rtk agent-dev-kit/tests/test_profile_coherence.sh` + `rtk agent-dev-kit/tests/run_all.sh` | 防止继承重复与未知引用 |
| install / convert 脚本 | `rtk agent-dev-kit/tests/run_all.sh` | 必须覆盖安装、转换、dry-run |
| root manifest | `rtk scripts/check-oss-intake-ledger.sh .` + `rtk scripts/check-oss-registration-plan.sh .` + `rtk scripts/check-oss-removal-plan.sh .` + `rtk scripts/check-oss-continuous-operation.sh .` + `rtk scripts/check-oss-approval-queue.sh .` + `rtk scripts/check-doc-sync.sh .` | 防止发现、评分、lifecycle、注册、移除、周期运行和审批队列 SSOT 漂移 |
| fixture | `rtk scripts/check-oss-intake-fixtures.sh .` + `rtk scripts/check-oss-intake-ledger.sh .` | 正负样例必须与 validator 语义一致 |
| OSS discovery | `rtk scripts/discover-oss-repos.sh . --dry-run --repo example/manual-discovery --out /tmp/oss-discovery-candidates.jsonl` + `rtk tests/test_oss_discovery.sh` | 默认本地发现；手工 GitHub/Gitee URL 只写 ledger；GitHub metadata provider 必须显式 `--github-query`，只写候选 ledger 和 rate-limit 记录，不 clone、不注册、不吸收 |
| OSS registration plan | `rtk scripts/check-oss-registration-plan.sh .` + `rtk tests/test_oss_registration_plan.sh` | P2 自动注册必须先通过 dry-run plan 与 rollback gate |
| OSS removal / cycle plan | `rtk scripts/check-oss-removal-plan.sh .` + `rtk scripts/check-oss-continuous-operation.sh .` + `rtk tests/test_oss_removal_plan.sh` + `rtk tests/test_oss_continuous_operation.sh` | P3/P4 必须保持 dry-run/report-only，禁止自动删除、吸收或 apply |
| OSS approval queue | `rtk scripts/check-oss-approval-queue.sh .` + `rtk tests/test_oss_approval_queue.sh` | L1 `candidate-review` 审查候选质量和 hard reject；L2/L3 审批 metadata/destructive apply；脚本不得执行审批动作 |
| OSS intake check / score 脚本 | `rtk bash -n scripts/<name>.sh` + `rtk scripts/check-oss-intake-fixtures.sh .` + `rtk scripts/check-all.sh --quick` | 必须保持离线、只读和 report-only 边界 |
| root 门禁脚本 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` | 影响生产放行链路 |
| `~/codex -> ~/.codex` 部署 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` + `~/codex` apply plan / dry-run / health 证据 | 必须保留 backup |

## 5. 生产部署流程

生产部署不从 `agent-dev-kit` 直接写入 `~/.codex`。adk 负责校验平台中立资产；`~/codex` 负责注册源资产、构建产物、生成 apply plan，并最终注入 `~/.codex`。当前 `agent-dev-kit` core 不再提供平台专属 `codex-handoff` 命令；Codex 运行态应用以 `~/codex` source-to-live 链路为准。

```bash
rtk bash agent-dev-kit/scripts/devkit.sh validate --strict
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/check-routing-precedence.sh
rtk bash ~/codex/scripts/check.sh
rtk scripts/check-global-codex-health.sh ~/.codex minimal
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

生产安装纪律：

- 不把 `agent-dev-kit` 导出物直接作为 `~/.codex` 来源。
- `~/codex` 侧必须维护源资产与 manifest，并运行 build / doctor / apply dry-run。
- 真正写入 `~/.codex` 时由 `~/codex/scripts/apply.sh` 负责备份、覆盖策略和回滚计划。
- 使用 adk `manifest.yaml` 版本和 `~/codex` apply plan 双重记录，防止误装不匹配版本。
- 安装后必须跑 `check-global-codex-health.sh`。

## 6. 回滚流程

先从安装报告确认备份路径，例如：

```text
$HOME/.codex/.adk-backups/YYYYMMDDTHHMMSSZ
```

回滚原则：

1. 不直接删除 `~/.codex`。
2. 先确认备份中存在 `agents/` 与 `skills/`。
3. 回滚后执行健康检查。
4. 在 `reports/` 新增回滚记录。

建议由用户明确授权后再执行回滚，因为会覆盖生产运行目录。

## 7. `~/.codex/AGENTS.md` 与 adk 的关系

`~/codex` 是 Codex Home 的声明式资产仓库，`~/.codex/AGENTS.md` 是运行时总策略层，adk 是 Agent/Skill/Profile 资产供应层。三者不要互相替代。

推荐职责边界：

| 层级 | 放什么 | 不放什么 |
|---|---|---|
| `llm_agent/agent-dev-kit` | adk 源资产、测试、profile、runbook、导出物 | 生产运行时的临时状态 |
| `~/codex/src/codex-home` + `~/codex/manifests` | 经治理的 Codex Home 源资产与声明式关系 | 未登记来源、未审查第三方资产 |
| `~/.codex/AGENTS.md` | 全局行为规则、命令硬约束、沟通风格、流程升级/降级、技能路由总原则 | 大量具体 Agent/Skill 正文、参考仓细节、一次性试跑报告 |
| `~/.codex/agents/` | `~/codex` apply 后的运行 Agent | 手工复制的第三方 Agent |
| `~/.codex/skills/` | `~/codex` apply 后的运行 Skill + 系统保留 skill | 未审查第三方技能 |
| `llm_agent/reports` | 安装、pilot、回归、上游吸收证据 | 密钥或私人业务数据 |

`~/.codex/AGENTS.md` 建议保留这些与 adk 配合的规则：

```md
## agent-dev-kit 配合规则

- `agent-dev-kit` 是嵌入式系统开发 Agent/Skill/Profile 的生产资产来源。
- 不手工把参考仓资产或 adk 导出物直接复制进 `~/.codex/agents` 或 `~/.codex/skills`。
- adk 资产更新必须先在 `llm_agent/agent-dev-kit` 通过回归，再交给 `~/codex` 注册、build、doctor 和 apply。
- 任务开始前如需判定技能、fallback 或跳过条件，优先使用 `adk-runtime-router`。
- 测试策略、代码审查、并行 agent、worktree 和分支收尾分别优先使用 `adk-test-strategy`、`adk-code-review-loop`、`adk-parallel-agent-governance`、`adk-worktree-governance`、`adk-branch-closeout`。
- 兼容 fallback 状态以 `agent-dev-kit/docs/reference/fallback-sunset-matrix.md` 为准，不做无证据下线；candidate-sunset 只能在 routing/profile/pilot/handoff/live 证据满足后进入观察。
- 长任务优先使用 `adk-planning-execution-loop`。
- 多技能冲突时以 `adk-runtime-router` 先做 primary/supporting/fallback 裁决；需要组合治理时再叠加 `adk-skill-composition-governance`。
- 第三方技能、脚本或参考资产进入全局环境前必须使用 `adk-security-supply-chain`。
- 完成前必须使用 `adk-verification-before-completion` 核对证据。
- 涉及 `~/.codex` 生产可用性结论时，必须同时附 `~/codex` build/apply 证据、`check-global-codex-health.sh ~/.codex minimal` 和 `check-codex-adk-live.sh . --summary-json` 证据。
```

当前不建议让 adk 覆盖 `~/.codex/AGENTS.md`，也不建议绕过 `~/codex` 直接写入 `~/.codex`。原因：

- `AGENTS.md` 包含个人环境硬约束，如 `rtk` 命令前缀、沟通偏好、文档目录、并行策略。
- `~/codex` 负责 Codex Home 源资产、manifest、build、apply 和 drift 管理。
- adk 的职责是提供经过门禁压实的上游资产，不是替换个人全局策略或运行目录管理器。
- 若要把 adk 的策略沉淀进 `~/.codex/AGENTS.md`，应先进入 `~/codex` 源资产，再采用“追加小节 + 人工审阅 + 健康检查”的方式。

## 8. 常见问题

### 8.1 是否可以跳过 pilot？

开发中可以临时不加 `--require-pilot`，但不能据此声明生产可用。生产结论必须使用：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

### 8.1.1 如何生成提交或发布证据包？

使用统一 evidence bundle：

```bash
rtk scripts/evidence-bundle.sh . --out reports/evidence-bundle.md
rtk scripts/evidence-bundle.sh . --format json
```

证据包会汇总 `adk.lock`、phase gate、subrepo state、codex pilot、global codex health、Codex live 实装态、pilot readiness 和 fallback sunset 结果。它不替代完整回归，但适合提交说明、PR 描述和发布记录附证。

Codex live 实装态单独使用：

```bash
rtk scripts/check-codex-adk-live.sh . --summary-json
rtk scripts/check-codex-adk-live.sh . --strict
```

长会话或上下文压力较高时，先运行：

```bash
rtk scripts/session-coach.sh . --summary-json
rtk scripts/session-coach.sh . --deep --summary-json
```

### 8.2 是否可以直接更新参考子仓？

可以同步，但必须先确认 phase gate。默认策略是先压实 adk，再追踪更新。

### 8.3 为什么 observe 已清零还要跑 observe 检查？

因为脚本会确认 backlog cleared，防止后续新增 observe 后没有三层证据。

### 8.4 adk 能否替代所有参考仓？

当前 adk 是生产分发层和压实层，不是参考仓全文镜像。参考仓继续作为上游灵感和候选池；只有经过采纳矩阵、adk 实现、门禁和 pilot 的能力才进入生产。

## 9. 维护记录模板

```md
### YYYY-MM-DD（主题）
- 变更范围：
- 触发原因：
- 更新条目：
- 验证命令：
- 验证结果：
- 后续事项：
```
