# 子仓治理脚本使用手册

完整维护流程见 `docs/llm-agent-maintenance-guide.md`。本文件只说明脚本入口、门禁含义与常用参数。

## Registry 字段约定（v1）

`subrepos/registry.csv` 统一使用以下列：

```csv
repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade
```

- `status`：`active` / `disabled`
- `owner`：治理责任方
- `last_reviewed_on`：最近复审日期（`YYYY-MM-DD`）
- `intake_policy`：吸收策略（如 `adopt-first`、`observe-first`、`selective-adopt`、`pilot-first`）

## 0. 阶段门禁（先压实 adk）

默认策略：先压实 `agent-dev-kit`，再跟踪外部子仓更新。

### adk 当前状态（2026-05-23）

- 版本锁: `agent-dev-kit.version=2.9.0`
- Pilot readiness: 10/10 ready，planned=0，`device_needs_fix=0`，`device_simulated_pass=1`
- Fallback replacement score: 70/70
- Codex 交接: `agent-dev-kit -> ~/codex -> ~/.codex` 只通过 handoff/build/plan/apply 链路进入运行目录
- Runtime boundary: 禁止 adk 绕过 `~/codex` 直接写入 `~/.codex`
- Production-field: 已有模拟设备状态机闭环；真实 production-ready 仍需实机烧录/readback、boot log、HIL/产测、OTA 回滚和现场包证据
- 证据刷新: 当前机器保留 build、doctor、plan、apply dry-run 与 global health 证据；当前状态索引见 `reports/current-status.md`
  `reports/current-status.md` 是最新门禁和证据包引用索引，不是 live refresh 已完成、真实 apply 已执行或 rollback 可用的证明。
门禁文件：`subrepos/phase-gate.env`（默认 `allow_upstream_sync=no`）。

阶段门禁已从单一开关扩展为阶段机，当前支持：

- `harden-adk`：压实 adk 基线
- `live-refresh`：刷新 `~/codex -> ~/.codex` 运行态证据
- `fallback-sunset`：推进 Superpowers fallback 候选下线
- `upstream-intake-cycle`：恢复参考子仓增量吸收周期
- `post-harden`：压实完成后的常规维护

```bash
scripts/check-phase-gate.sh .
scripts/check-phase-gate.sh . --summary-json
```

```bash
# 先做压实检查（严格校验 + 可选技能回归 + 外部引用门禁）
scripts/check-adk-harden-readiness.sh .
# 通过后自动开门（可选）
scripts/check-adk-harden-readiness.sh . --open-gate
# 要求 codex 试跑证据也必须就绪（更严格）
scripts/check-adk-harden-readiness.sh . --require-pilot
scripts/check-adk-harden-readiness.sh . --require-pilot --open-gate
# 若临时不检查全局 ~/.codex 健康（不建议）
scripts/check-adk-harden-readiness.sh . --skip-global-codex-check
# 若临时跳过 adk 全量回归（不建议）
scripts/check-adk-harden-readiness.sh . --skip-full-suite

# 显式打开三类新增门禁检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-skill-metadata --check-routing-conflicts --check-doc-sync

# 显式打开矩阵状态检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-matrix-status

# 显式打开 observe 吸收深度检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-observe-intake-depth

# 显式打开 delivery 采纳深度检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-delivery-adopt-depth

# 显式打开生产级路由、pilot 覆盖、上游吸收、runtime live 证据检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-runtime-routing
scripts/check-adk-harden-readiness.sh . --check-pilot-coverage
scripts/check-adk-harden-readiness.sh . --check-upstream-intake
scripts/check-adk-harden-readiness.sh . --check-codex-handoff

# 临时跳过某类新增检查（不建议）
scripts/check-adk-harden-readiness.sh . --skip-skill-metadata-check
scripts/check-adk-harden-readiness.sh . --skip-routing-conflicts-check
scripts/check-adk-harden-readiness.sh . --skip-doc-sync-check
scripts/check-adk-harden-readiness.sh . --skip-matrix-status-check
scripts/check-adk-harden-readiness.sh . --skip-observe-intake-depth-check
scripts/check-adk-harden-readiness.sh . --skip-delivery-adopt-depth-check
scripts/check-adk-harden-readiness.sh . --skip-runtime-routing-check
scripts/check-adk-harden-readiness.sh . --skip-pilot-coverage-check
scripts/check-adk-harden-readiness.sh . --skip-upstream-intake-check
scripts/check-adk-harden-readiness.sh . --skip-codex-handoff-check
```

若未开门，`sync-subrepos.sh` / `diff-scan.sh` 会返回 `[BLOCK]`。  
紧急一次性绕过：追加 `--force`（建议仅临时使用并留痕）。

runtime pilot 统一检查脚本（合并 evidence + coverage + 场景验证）：

```bash
# 完整检查（默认模式：evidence + coverage + 场景验证）
scripts/check-runtime-pilot.sh .

# 只检查 4 个基础证据字段
scripts/check-runtime-pilot.sh . evidence

# 只检查 7 个覆盖字段
scripts/check-runtime-pilot.sh . coverage

# 完整检查（等价于默认模式）
scripts/check-runtime-pilot.sh . full
```

当 `pilot_full_coverage_ready=yes` 时，`coverage` 和 `full` 模式会强制校验六类场景字段、场景章节、`ImplementationPlan/ReviewReport/TestReport` artifact 标签与命令级 Evidence Index。

`check-runtime-pilot-evidence.sh` 和 `check-runtime-pilot-coverage.sh` 是固定模式便捷入口，分别执行 evidence / coverage 检查。

Codex 目标运行态 `~/.codex` 健康检查脚本（运行目录由 `~/codex` apply 生成）：`scripts/check-runtime-targets.sh . --summary-json` 校验 `manifests/runtime_targets.json`、`manifests/runtime_health_adapters.json`、`adk.lock`、`subrepos/registry.csv` 和 target 检查脚本一致性；`scripts/check-runtime-targets.sh . --explain-target codex-home` 输出 target activation 诊断 JSON，且不得与 `--summary-json` 组合；`scripts/collect-runtime-target-evidence-package.sh . --target codex-home --summary-json` 采集 report-only evidence package，只运行只读门禁并生成 `reports/runtime-target-activation/<target-id>/<timestamp>/evidence-index.jsonl`；`scripts/collect-runtime-target-evidence-package.sh . --target codex-home --promote-current --summary-json` 会先要求 `--out-dir` 的语法路径和 realpath 都留在同一 target 的 `reports/runtime-target-activation/<target-id>/...` 子目录，再用 strict artifact gate 校验刚生成的包，校验通过且 package status 为 `pass` 后才刷新 `reports/runtime-target-activation/<target-id>/evidence-index.jsonl`、`evidence-index.md` 和 `current-status.md` 作为 canonical 当前索引；`--promote-current` does not run apply、does not run rollback，也不执行 live root writes，promotion never changes enabled state，失败路径不得覆盖旧 canonical；`scripts/generate-runtime-target-evidence-index.sh . --target codex-home --out reports/runtime-target-activation/codex-home/evidence-index.md` 生成 activation Evidence Index 草稿，`scripts/check-runtime-target-evidence-index.sh .` 校验默认 target 与 candidate 的 Evidence Index schema、状态枚举和 live 写入审批边界；`scripts/check-runtime-target-evidence-index.sh . --target codex-home --index reports/runtime-target-activation/codex-home/evidence-index.jsonl --strict-artifacts --summary-json` 对已落盘 JSONL 证据包做只读严格校验，`--require-index` 要求目标存在 canonical evidence-index.jsonl；`docs/runbooks/runtime-target-activation.md` 记录新增 runtime target checklist 和 `runtime-target-activation/<target-id>/evidence-index.md` 模板；`scripts/check-runtime-health.sh . --profile minimal|security --summary-json` 读取默认 target，并通过 `target.health_adapter` 分发到 adapter；`scripts/check-runtime-health-adapters-fixtures.sh .` 运行 adapter contract 负例 fixture，覆盖 runtime mismatch、disabled adapter、profile 缺失、script 不可执行、binding 缺失和 legacy `health_check` 残留；`scripts/check-global-codex-health.sh ~/.codex minimal|security` 保留为 Codex adapter。非标准 base URL 必须通过 `CODEX_TRUSTED_BASE_URLS` 显式声明为已审查端点。

Runtime target Evidence Index 支持 `evidence-index.md` 和 `evidence-index.jsonl`；字段包括 `Evidence ID`、`Target ID`、`Gate`、`Write Scope`、`Approval Required`、`Approval Status`、`artifact_exists`、`artifact_sha256`、`approved_by`、`approved_at`、`approval_scope`、`activation_ready`。`Gate` 枚举为 `declare`、`dry-run`、`health`、`footprint`、`apply`、`rollback`、`activation`；`Write Scope` 枚举为 `read-only`、`workspace-local`、`source-repo-only`、`live-root`、`rollback-live-root`；状态枚举为 `planned`、`passed`、`failed`、`blocked`、`approved`。`--strict-artifacts` 下 `passed/approved artifact hash` 必须匹配，live 写入和 rollback-live-root 必须有审批身份字段；evidence package 不执行真实 apply/rollback，`required_evidence is not artifact evidence`，`check-runtime-targets.sh` 是 `declaration gate only`，不能证明 dry-run、rollback、health、footprint 或 live apply artifact 已存在。

技能元数据检查脚本：

```bash
scripts/check-skill-metadata.sh .
```

技能路由冲突检查脚本：

```bash
scripts/check-skill-routing-conflicts.sh .
```

文档与治理文件同步检查脚本：

```bash
scripts/check-doc-sync.sh .
```

tracked 文件权限检查脚本：

```bash
# 检查工作区权限是否匹配 Git index：100644 不可执行，100755 可执行
scripts/check-file-modes.sh .

# 修复工作区权限漂移，不改 Git index
scripts/check-file-modes.sh . --fix
```

该检查已接入 `scripts/check-all.sh` 和 `scripts/check-adk-harden-readiness.sh`。文档、README、manifest、skill、template 默认不应带 executable bit；`scripts/*.sh`、可直接执行的测试脚本和稳定 CLI 包装层应保持 executable bit。

adk 版本锁与官方文档来源复审联动检查脚本：

```bash
scripts/check-adk-lock.sh .
scripts/check-official-docs-adoption-review.sh .
```

该脚本校验 `adk.lock`、`agent-dev-kit/manifest.yaml` 和根仓 gitlink commit 是否一致，防止子模块指针、版本号和文档交付口径漂移。
子仓状态检查脚本：

```bash
# 默认模式：只强约束 agent-dev-kit 干净，其余参考仓输出状态摘要
scripts/check-subrepo-state.sh .

# 严格模式：所有 active 子仓都必须 clean
scripts/check-subrepo-state.sh . --strict

# 低 token 摘要：区分 known_dirty、unexpected_dirty 和 stale_baseline
scripts/check-subrepo-state.sh . --summary-json
```

默认模式用于日常门禁，避免参考仓未初始化或本地状态噪音阻断主链路；严格模式用于发布前收敛。
`subrepos/dirty-baseline.tsv` 记录 observe 子仓的预期 dirty 状态、status fingerprint、change count、owner 和 expires_on，避免把长期参考仓本地噪音误判为本轮风险，也避免 dirty baseline 变成永久豁免。
`scripts/generate-reference-dirty-triage.sh . --out reports/reference-dirty-triage-YYYY-MM-DD.md --json-out reports/reference-dirty-triage-YYYY-MM-DD.json` 生成只读分流报告；`scripts/check-reference-dirty-triage.sh . --summary-json` 默认选 latest valid 报告并校验 dirty baseline，`--date YYYY-MM-DD` 可强制指定。

证据包生成脚本：

```bash
scripts/evidence-bundle.sh .
scripts/evidence-bundle.sh . --format json
scripts/evidence-bundle.sh . --out reports/evidence-bundle.md
scripts/evidence-bundle.sh . --format json --fail-on-needs-fix
scripts/evidence-bundle.sh . --format json --max-summary-chars 240
```

该脚本汇总 `adk.lock`、runtime target registry、runtime health adapter contract、phase gate、subrepo state、reference dirty triage、runtime pilot、runtime health、runtime live 实装态、pilot readiness 和 fallback sunset 结果，用于提交前或发布前附证；默认会截断单项 summary，避免证据摘要本身消耗过多上下文。

治理健康与复核报告脚本：

```bash
scripts/governance-health.sh .
scripts/governance-health.sh . --format json
scripts/governance-review.sh .
scripts/governance-review.sh . --format json
scripts/governance-review.sh . --out reports/governance-review-YYYY-MM-DD.md
```

`governance-health` 输出 Top Actions；`governance-review` 是 report-only 复核报告入口，只调用现有 gate，不同步参考子仓、不修改 phase gate、不 apply、不提交；只有显式 `--out` 才写报告。

active 文档陈旧引用检查脚本：

```bash
scripts/check-stale-references.sh .
```

该脚本检查 active 文档中的旧版本状态、旧本机路径、旧脚本名和绕过 `~/codex` 的直接运行目录安装示例；历史 archive 不参与阻断。

runtime live 实装态与长会话提醒：

```bash
scripts/check-runtime-live-footprint.sh . --summary-json  # 低 token 摘要
scripts/check-runtime-live-footprint.sh . --strict        # core-live 缺失时失败
scripts/session-coach.sh . --summary-json         # Top Action
scripts/session-coach.sh . --deep --summary-json  # 追加 live/token 检查
```

未传 `--runtime-root` 时，`check-runtime-live-footprint.sh` 从 `manifests/runtime_targets.json` 读取默认 target 的 `live_root`，并检查 fallback 矩阵中的 adk 等价 skill 是否已在目标 direct/system/vendor 路径实装；`session-coach.sh` 根据 dirty worktree、资产变更和 `THREAD_LONG`/`CTX_PRESSURE` 输出 Top Action。

Token budget 检查脚本：
```bash
scripts/check-token-budget.sh .
scripts/check-token-budget.sh . --summary-json
```

该脚本检查 `agent-dev-kit` Skill/doc 入口体量、全量测试默认输出策略、根仓 active 文档体量、关键脚本低 token 摘要入口和 `governance-health` JSON 输出大小，防止治理能力扩展后默认上下文继续膨胀。

WeChat 文章吸收账本脚本：`scripts/generate-wechat-intake-ledger.sh` / `scripts/check-wechat-intake-ledger.sh .`。只读扫描 `wechat-articles/` 并生成 `reports/wechat-article-intake.jsonl`、`reports/wechat-absorb-next-batch.md`；细则见 `docs/runbooks/wechat-article-absorption.md`。

OSS intake P1-P4 脚本：`scripts/oss-intake.sh status|discover|cycle|queue|score|plan-onboard|plan-remove|check`、`scripts/discover-oss-repos.sh . --dry-run --repo example/manual-discovery`、`scripts/discover-oss-repos.sh . --dry-run --repo https://gitee.com/example/manual-discovery`、`scripts/discover-oss-repos.sh . --dry-run --github-query "topic:agent archived:false" --github-max-results 30`、`scripts/check-oss-intake-ledger.sh .`、`scripts/score-oss-candidates.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --out reports/oss-score-report-2026-06-16.md`、`scripts/check-oss-registration-plan.sh .`、`scripts/onboard-oss-candidate.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --repo example/runtime-policy-gates --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md`、`scripts/check-oss-removal-plan.sh .`、`scripts/plan-oss-subrepo-removal.sh . --repo codex`、`scripts/check-oss-continuous-operation.sh .`、`scripts/run-oss-intake-cycle.sh .`、`scripts/run-oss-intake-cycle.sh . --discover-github --github-query "topic:agent archived:false"`、`scripts/generate-oss-intake-approval-queue.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --rate-limit reports/oss-discovery-rate-limit-2026-06-16.json`、`scripts/check-oss-approval-queue.sh .`。该链路默认只校验本地 JSON/JSONL、root manifests 和 fixtures；手工 GitHub/Gitee URL 只生成 ledger-only 候选，显式传入 `--ledger` 后进入 scoped L1 `candidate-review`；GitHub REST metadata discovery 必须显式 `--github-query` / `--discover-github` 才会联网，并且只写 `reports/oss-discovery-candidates-*.jsonl` 与 `reports/oss-discovery-rate-limit-*.json`，`cycle --discover-*` 会自动生成 `reports/oss-score-report-*.md` 并把本轮 ledger/rate-limit 带入 L1 `candidate-review` 队列项；不 clone、不注册、不吸收、不自动移除子仓；P2 `--apply` 默认 metadata-only，P3 `--apply` 当前阻断。

常用验证：`rtk scripts/check-oss-intake-ledger.sh .`、`rtk scripts/check-oss-registration-plan.sh .`、`rtk scripts/check-oss-removal-plan.sh .`、`rtk scripts/check-oss-continuous-operation.sh .`、`rtk scripts/check-oss-approval-queue.sh .`、`rtk scripts/check-oss-intake-fixtures.sh .`、`rtk scripts/check-runtime-health-adapters-fixtures.sh .`、`rtk scripts/check-runtime-target-evidence-index.sh .`、`rtk scripts/check-loop-readiness.sh .`、`rtk scripts/check-scale-engine-governance.sh .`、`rtk scripts/check-harness-loop-engineering.sh .`、`rtk tests/test_adoption_real_assets.sh`、`rtk tests/test_oss_discovery.sh`、`rtk tests/test_oss_intake_ledger.sh`、`rtk tests/test_oss_registration_plan.sh`、`rtk tests/test_oss_removal_plan.sh`、`rtk tests/test_oss_continuous_operation.sh`、`rtk tests/test_oss_approval_queue.sh`、`rtk tests/test_runtime_health_adapters.sh`、`rtk tests/test_runtime_target_evidence_index.sh`、`rtk tests/test_runtime_target_evidence_package.sh`、`rtk tests/test_runtime_target_evidence_promotion.sh`。输入是 `manifests/oss_discovery_sources.json`、`manifests/oss_candidate_scoring_policy.json`、`manifests/subrepo_lifecycle.json`、`manifests/oss_registration_policy.json`、`manifests/oss_removal_policy.json`、`manifests/oss_continuous_operation.json`、`manifests/oss_intake_approval_queue.json`、`manifests/loop_readiness_contracts.json`、`manifests/scale_engine_governance_contracts.json`、`agent-dev-kit/manifests/harness_loop_engineering_contracts.json`、`fixtures/oss-intake/`、`fixtures/oss-intake/discovery-source.md` 与 `fixtures/oss-intake/github-search-response.json`。active-reference/local-submodule lifecycle 条目还会校验 source URL/provider/branch/commit/retrieved_at、runtime boundaries、analysis/absorption/security/deep-assessment 报告 evidence 和本地 HEAD commit。harness/loop 参考源额外通过 `loop_readiness_contracts.json` 记录 report-only 指标、禁止外部 runtime、禁止 hook patch 和禁止 daemon 的边界；governance/resource 参考源通过 `scale_engine_governance_contracts.json` 记录风险分级、资源类型、Git policy 和禁止 `.scale` runtime state 的边界；harness loop engineering 合同通过 `agent-dev-kit/manifests/harness_loop_engineering_contracts.json` 固化 repo-task eval、CI gate、durable loop、coding agent loop、trace observability 和 guardrail handoff 的 method-only 证据边界。`reports/oss-discovery-candidates-*.jsonl` 是候选 ledger；`reports/oss-discovery-rate-limit-*.json` 是 GitHub metadata provider 的 rate-limit 审计记录；`reports/oss-score-report-*.md` 是评分摘要；`candidate-review` 是 report-only L1 队列项；`reports/oss-onboarding-plan-*.json/md`、`reports/subrepo-removal-plan-*.json/md`、`reports/oss-intake-cycle-*.json/md`、`reports/oss-intake-approval-queue-*.json/md` 和 `reports/oss-intake-evidence-bundle-*.md` 分别是 P2/P3/P4/审批证据。

adoption-matrix 状态检查脚本（真实记录不得有 `pending`，`blocked` 必须写解除条件）：
```bash
scripts/check-adoption-matrix-status.sh .
```

ADK target evidence 检查脚本：`scripts/check-adk-target-evidence.sh .`。2026-06-29 起，`target` 包含 `agent-dev-kit` 且 `adopt/observe + done` 的条目，证据必须包含至少一个存在的 `agent-dev-kit/...` 路径；更严格的 `scripts/check-adoption-real-assets.sh .` 会阻断只停在 `reports/`、`subrepos/adoption-matrix*` 或 reference adoption matrix 的行，除非能力本身就是采纳/评估矩阵。

observe 吸收深度检查脚本（`observe+done` 行必须同时具备 Agent/Skill/Workflow 三层证据，并附 intake 任务包报告证据）：

```bash
scripts/check-observe-intake-depth.sh .
```

当 `observe+done` 行为 0（已全部收口为 `adopt/reject`）时，脚本返回通过并提示 backlog cleared。

delivery 采纳深度检查脚本（`delivery + adopt + done` 行必须同时具备 Agent/Skill/Workflow 三层证据，并附 wave 任务包报告证据）：

```bash
scripts/check-delivery-adopt-depth.sh .
```

生产级 runtime routing 资产检查脚本：

```bash
scripts/check-runtime-routing.sh .
```

该脚本会同时调用 `agent-dev-kit/scripts/check-profile-coherence.sh`，防止 profile 继承后重复声明 Agent/Skill 或引用漂移。

上游吸收生产准入检查脚本：

```bash
scripts/check-upstream-intake-readiness.sh .
```

当前默认不强制 `--require-pilot`。  
如需“先试跑再开门”，请在开门命令追加 `--require-pilot`。

harness/loop readiness 合同检查脚本：`scripts/check-loop-readiness.sh .` 只读校验 `manifests/loop_readiness_contracts.json`、`reports/oss-loop-readiness-*.md`、lifecycle 和 adoption 证据链，确保只吸收 DiagnosticLoop、AgentLoopReadiness、failure replay 等 report-only 字段，不接入上游 CLI、hook、orchestrator 或 daemon runtime。scale-engine governance 合同检查脚本：`scripts/check-scale-engine-governance.sh .` 只读校验 `manifests/scale_engine_governance_contracts.json`、`reports/oss-governance-contracts-*.md`、lifecycle 和 adoption 证据链，确保只吸收 progressive governance、resource lifecycle、Git policy 等 report-only 字段，不创建 `.scale` runtime state。harness loop engineering 合同检查脚本：`scripts/check-harness-loop-engineering.sh .` 转发校验 `agent-dev-kit/manifests/harness_loop_engineering_contracts.json`，确保 repo task harness、agent eval CI gate、durable loop、coding agent loop、trace observability 和 guardrail handoff 只作为 method-only 合同输入。
ADK tool/skill evidence 合同检查脚本：`scripts/check-adk-tool-skill-evidence-contracts.sh .` 转发校验 `agent-dev-kit/manifests/tool_skill_evidence_contracts.json`、routing/verification/memory/context/security 资产，确保只吸收 evidence plan、memory maintenance、command safety 和 code intelligence fallback，不启用外部 runtime。ADK 目标/功能/性能检查脚本：`scripts/check-adk-goal-capability.sh .` 校验 `devkit.sh goal check`、`devkit.sh capability health` 和 `devkit.sh perf budget`。ADK perf/ops 检查脚本：`scripts/check-adk-performance-ops.sh .` 校验 `devkit.sh perf`、`devkit.sh ops` 和 quick timing gate 的 report-only 契约。

工作区入口回归检查脚本：

```bash
scripts/check-workspace-entrypoints.sh .
```

该脚本覆盖 `scripts/devkit.sh health`、`scripts/devkit.sh sync status`、旧 pilot wrapper、weekly report 输出和 registry 评级列解析，防止统一入口与文档承诺再次漂移。

## 1. 同步子仓增量

```bash
scripts/sync-subrepos.sh . fetch
scripts/sync-subrepos.sh . pull
scripts/sync-subrepos.sh . fetch --force
```

- `fetch`：对启用子仓执行 `git fetch --all --prune`
- `pull`：仅对 `registry.csv` 中 `sync_mode=pull` 的子仓执行 `git pull --ff-only`

## 2. 扫描高价值变更

```bash
scripts/diff-scan.sh . 7 reports/weekly-change-report.md
scripts/diff-scan.sh . 7 reports/weekly-change-report.md --force
```

- 参数 2：扫描最近 N 天（默认 `7`）
- 参数 3：报告输出路径（默认 `reports/weekly-change-report.md`）

冻结后一键巡检（文档同步 + 周报扫描 + 矩阵状态）：

```bash
scripts/run-post-freeze-cycle.sh .
scripts/run-post-freeze-cycle.sh . 7 reports/weekly-change-report.md
```

adoption-matrix 汇总报告生成脚本（统计 done/pending/blocked 与类别分布）：

```bash
scripts/generate-adoption-matrix-summary.sh .
scripts/generate-adoption-matrix-summary.sh . reports/adoption-matrix-summary.md
```

adoption-matrix 结构化导出与同步校验：

```bash
scripts/export-adoption-matrix-jsonl.sh .
scripts/check-adoption-matrix-structured.sh .
```

`subrepos/adoption-matrix.jsonl` 由 Markdown 矩阵机械导出，供脚本低 token 读取；手工修改矩阵后必须重新导出并通过同步校验。

## 3. 检查 AGENTS 覆盖

```bash
scripts/check-agents-coverage.sh .
```

- 检查项：active 子仓是否在 `subrepos/registry.csv` 注册且本地路径存在
  - 子仓是否存在本地 `AGENTS.md`，或使用根仓托管覆盖文件 `subrepos/agents/<repo>.md`
  - 根 `AGENTS.md` 是否保持 slim-entry 预算，并指向 registry、adoption matrix 和维护指南
  - 根 `AGENTS.md` 不再逐个列出参考子仓；完整清单以 `subrepos/registry.csv` 为准。

## 4. 新仓库接入

当有新参考仓库需要纳入 llm_agent 治理时，使用一键接入脚本：

```bash
scripts/new-repo-onboard.sh <repo-path> [--adopt|--observe|--selective|--pilot]
```

功能：
- 自动注册到 `registry.csv`
- 生成/追加仓库 `AGENTS.md`
- 更新 `adoption-matrix.md`
- 运行基础检查
- 生成接入报告到 `reports/`

详细流程参见：`docs/runbooks/new-repo-onboarding.md`

## 5. 备份回滚

```bash
scripts/backup-rollback.sh [ACTION] [OPTIONS]
```

功能：
- 提供安装资产的备份和回滚能力。
- `backup`：创建当前 `~/.codex` 的完整备份快照；生产变更优先使用 `~/codex` apply plan / rollback。
- `rollback`：从已有备份点恢复 `~/.codex`；常规资产回滚优先走 `~/codex/scripts/rollback.sh`。
- `list`：列出所有可用备份点。
- 支持自动清理过期备份。

## 6. 全局 codex 目标策略校验

```bash
scripts/check-global-codex-target-policy.sh [WORKSPACE_ROOT]
```

功能：
- 确保工作区未回退到使用本地 `codex/` 目录。
- 校验 `registry.csv` 中 codex 行的策略指向 `~/codex` 声明式资产仓库，并由其 apply 到全局 `~/.codex`。
- 已接入 `check-adk-harden-readiness.sh` 主链路。

详细排查参见：`docs/runbooks/quality-gate-checklist.md`

## 7. 一键门禁检查

```bash
scripts/check-all.sh --smoke
scripts/check-all.sh --quick
scripts/check-all.sh --full
scripts/check-all.sh --verbose
scripts/check-all.sh --quick --verbose
```

功能：
- 自动发现 `scripts/check-*.sh` 并汇总 PASS/FAIL。
- `--smoke` 只覆盖最小健康面；`--quick` 跳过 `check-adk-harden-readiness.sh` 和 `check-workspace-entrypoints.sh`；`--full` 或无参数运行全部脚本。
- 退出码：全部通过返回 0，否则返回 1

## 8. 统一入口 devkit.sh

```bash
# 查看帮助
scripts/devkit.sh help

# 一键门禁检查
scripts/devkit.sh check --quick
scripts/devkit.sh check --full

# 新仓库接入
scripts/devkit.sh onboard <repo-path> --adopt
scripts/devkit.sh onboard <repo-path> --observe

# 子仓同步
scripts/devkit.sh sync fetch
scripts/devkit.sh sync pull
scripts/devkit.sh sync status

# 差异扫描（默认 7 天）
scripts/devkit.sh diff
scripts/devkit.sh diff 14

# 健康检查
scripts/devkit.sh health
scripts/devkit.sh health --summary-json

# runtime live / 长会话提醒
scripts/devkit.sh runtime-live --summary-json
scripts/devkit.sh coach --deep --summary-json

# 生成周报
scripts/devkit.sh weekly-report

# 清理过期报告
scripts/devkit.sh cleanup --dry-run
scripts/devkit.sh cleanup
```

`devkit.sh` 是 `llm_agent` 工作区的统一运维入口，将分散的脚本按功能聚合为子命令，降低记忆成本。

## 9. 工作区健康检查

```bash
scripts/health-check.sh check-all --root .
scripts/health-check.sh .
scripts/health-check.sh --summary-json
```

功能：
- 对 `llm_agent` 工作区执行综合健康检查。
- 检查项包括：目录结构完整性、关键文件存在性、registry 格式、依赖、门禁入口、脚本语法。
- 输出通过/失败/警告三级状态报告。
- `--summary-json` 输出低 token JSON 摘要，适合 Codex 在上下文紧张时读取。

## 10. 版本管理

```bash
scripts/version-manager.sh [ACTION] [OPTIONS]
```

功能：
- 管理 `agent-dev-kit` 的版本锁定和升级路径。
- `check`：检查当前版本状态。
- `lock`：锁定当前版本号。
- `upgrade`：执行版本升级并验证。
- 支持版本回退和变更日志生成。

## 11. 自动生成周报

```bash
scripts/generate-weekly-report.sh [WORKSPACE_ROOT]
```

功能：
- 自动汇总最近 7 天 git 提交摘要。
- 读取 `subrepos/registry.csv` 中 `enabled=yes` 的子仓同步状态。
- 统计 `adoption-matrix.md` 决策分布与本周变更。
- 运行质量门禁快速检查（health-check / matrix-status / agents-coverage）。
- 输出报告到 `reports/weekly-report-YYYY-MM-DD.md`。

建议配合 cron 定时执行：
```bash
# 每周五下午 6 点自动生成周报
0 18 * * 5 cd /path/to/llm_agent && rtk scripts/generate-weekly-report.sh .
```

## 12. 清理归档旧报告

```bash
scripts/cleanup-reports.sh [WORKSPACE_ROOT] [--dry-run] [--days N]
```

功能：
- 将 `reports/` 中超过指定天数的 `.md` 报告移入 `reports/archive/`。
- 保留 `.template.md` 模板文件不移动。
- `--dry-run`：只显示会移动的文件，不实际执行。
- `--days N`：自定义天数阈值，默认 30 天。

示例：
```bash
# 模拟清理（查看哪些文件会被归档）
scripts/cleanup-reports.sh . --dry-run

# 清理 60 天前的报告
scripts/cleanup-reports.sh . --days 60
```

## 13. 安装 Pre-commit Hook

```bash
scripts/install-pre-commit-hook.sh [WORKSPACE_ROOT]
```

功能：
- 安装 git pre-commit hook 到 `.git/hooks/pre-commit`。
- 自动备份已有 hook（`.bak.YYYYMMDDHHMMSS`）。

hook 检查项：
1. **Shell 脚本语法**：对 `scripts/*.sh` 及暂存区中的 `.sh` 文件执行 `bash -n` 语法检查。
2. **AGENTS.md 引用文件**：检查 `AGENTS.md` 中反引号引用的 `.md/.sh/.py/.csv/.json/.yaml/.yml/.env` 文件是否存在。
3. **registry.csv 格式**：校验表头、列数（12列）、`enabled`（yes/no）和 `status`（active/disabled）字段值。

跳过 hook 检查：`git commit --no-verify`

卸载 hook：`rm .git/hooks/pre-commit`
