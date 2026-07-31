# Context Compression Preflight

## 目标
- 线程角色：implementation
- 目标强度：strong
- 本轮目标：完成 MCP `2026-07-28` activation 前的 schema、固定版本 client/server、auth boundary 与 rollback 四项验证，并生成独立 owner activation decision 包。
- 范围：`agent-dev-kit` 的 MCP compatibility fixture、专用验证入口、manifest activation evidence、change/evidence/decision 工件。
- 非目标：不代替 owner 签署激活决定；不在决定前切换 active protocol、启用 runtime/Tasks/Apps/extensions；不写真实凭证、不连接真实 MCP 服务、不 source-to-live。
- 成功标准：四项专用测试均有固定 SDK/运行环境和负例证据；manifest gate 仅把技术 prerequisites 标为完成，owner decision 与 activation 仍 fail-closed。
- 验证命令：`rtk agent-dev-kit/scripts/check-mcp-2026-activation.sh --prepare`；`rtk agent-dev-kit/scripts/check-mcp-2026-activation.sh --offline`；`rtk agent-dev-kit/tests/test_agent_ecosystem_standards.sh`；ADK strict/full。
- 可审查产物：change proposal/design/tasks/checklist/state、Go fixture、go.mod/go.sum、专用 checker、verify/review/decision request。
- 阻塞条件：固定依赖无法取回；官方 SDK 无法完成精确协议 smoke；auth/rollback 负例不成立；owner 未给出独立决策。
- 期望输出：技术 readiness 证据 + 明确的 ACTIVATE/HOLD/REJECT owner 决策请求。

## 当前状态
- 仓库：/home/leiwenjun/bin/llm_agent
- 分支：main
- 关键文件：`agent-dev-kit/manifests/skill_mcp_dependencies.json`、`agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/`。
- 已完成：MCP final metadata 已刷新；active 仍为 `2025-11-25`；四项 prerequisite 当前均为 false。
- 未完成：四项技术验证、证据绑定、独立 owner activation decision。

### 工作区状态

```text
 m OpenSpec
 m agent-dev-kit
 M fixtures/reference-repository/removal/pass/removal-plan.json
 M manifests/comprehensive_optimization_backlog.json
 M manifests/external_practice_sources.json
 M manifests/report_registry.json
 M reports/architecture/README.md
 M reports/current-status.md
 M scripts/README.md
 M scripts/check-architecture-reports.sh
 M scripts/check-current-status-consistency.sh
 M subrepos/adoption-matrix.jsonl
 M subrepos/adoption-matrix.md
 M subrepos/dirty-baseline.tsv
 M subrepos/registry.csv
 m superpowers
 M tests/test_architecture_reports.sh
 M tests/test_current_status_consistency.sh
 M tests/test_product_maturity_contracts.sh
 m vibeflow
?? .cache/
?? hermes/
?? hermes_data/
?? reports/aggregate-gate-evidence-reuse-quick-2026-07-23.json
?? reports/architecture/g14-g15-runtime-field-handoff-2026-07-30.md
?? reports/architecture/knowledge-candidates/llm-agent-adk-comprehensive-optimization-candidate-2026-07-30.md
?? reports/architecture/knowledge-candidates/llm-agent-external-practice-cycle-candidate-2026-07-30.md
?? reports/architecture/knowledge-candidates/llm-agent-mcp-2026-final-metadata-enhance-candidate-2026-07-30.md
?? reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md
?? reports/atomic-commit-closeout-2026-07-24.md
?? reports/codex-apply-plan-preview-2026-07-24.json
?? reports/codex-check-fix-apply-plan-2026-07-24.json
?? reports/codex-check-pre-apply-remediation-2026-07-24.md
?? reports/codex-governance-skill-routing-delivery-2026-07-24.md
?? reports/external-practice-absorption-candidates-2026-07-23.jsonl
?? reports/external-practice-absorption-decisions-2026-07-23.jsonl
?? reports/external-practice-absorption-implementation-2026-07-23.md
?? reports/external-practice-candidates-2026-07-22.jsonl
?? reports/external-practice-candidates-2026-07-30.jsonl
?? reports/external-practice-candidates-spec-kit-2026-07-23.jsonl
?? reports/external-practice-curator-review-2026-07-30.md
?? reports/external-practice-cycle-2026-07-22.md
?? reports/external-practice-cycle-2026-07-30.md
?? reports/external-practice-cycle-evidence-2026-07-22.json
?? reports/external-practice-cycle-evidence-2026-07-30.json
?? reports/external-practice-decisions-spec-kit-2026-07-23.jsonl
?? reports/external-practice-evidence-spec-kit-2026-07-23.json
?? reports/external-practice-recommendations-2026-07-22.json
?? reports/external-practice-recommendations-2026-07-22.md
?? reports/external-practice-recommendations-2026-07-30.json
?? reports/external-practice-recommendations-2026-07-30.md
?? reports/external-practice-review-queue-2026-07-22.json
?? reports/external-practice-review-queue-2026-07-30.json
?? reports/external-practice-search-and-absorption-candidates-2026-07-22.md
?? reports/external-practice-targeted-candidates-2026-07-30.jsonl
?? reports/external-practice-targeted-decisions-2026-07-30.jsonl
?? reports/external-practice-targeted-evidence-2026-07-30.json
?? reports/external-practice-targeted-input-2026-07-30.jsonl
?? reports/external-practice-targeted-recommendations-2026-07-30.json
?? reports/external-practice-targeted-recommendations-2026-07-30.md
?? reports/external-practice-targeted-review-queue-2026-07-30.json
?? reports/external-practice-targeted-review-queue-2026-07-30.md
?? reports/observe-secondary-intake-packages-2026-07-23.md
?? reports/reference-analysis-spec-kit-2026-07-23.md
?? reports/reference-dirty-triage-2026-07-23.json
?? reports/reference-dirty-triage-2026-07-23.md
?? reports/reference-duplicate-review-spec-kit-2026-07-23.md
?? reports/reference-repository-onboarding-spec-kit-2026-07-23.json
?? reports/reference-repository-onboarding-spec-kit-2026-07-23.md
?? reports/reference-security-review-spec-kit-2026-07-23.md
?? reports/source-to-live-remote-delivery-2026-07-24.md
?? reports/spec-kit-reference-onboarding-implementation-2026-07-23.md
?? reports/terminal-maturity-check-all-full-2026-07-23.json
?? reports/terminal-maturity-check-all-post-commit-2026-07-24.json
?? reports/terminal-maturity-check-all-quick-2026-07-23.json
?? reports/terminal-maturity-optimization-context-preflight-2026-07-23.md
?? reports/terminal-maturity-root-tests-2026-07-23.json
?? reports/terminal-maturity-root-tests-closeout-2026-07-24.json
?? scripts/check-maintainability-budgets.sh
?? tests/test_maintainability_budgets.sh
?? tools/codex_assets/maintainability_budget.py
```

### 变更规模

```text
OpenSpec                                           |   0
 agent-dev-kit                                      |   0
 .../removal/pass/removal-plan.json                 |   4 +-
 manifests/comprehensive_optimization_backlog.json  | 273 ++++++++++++++++++++-
 manifests/external_practice_sources.json           |  42 ++--
 manifests/report_registry.json                     |  11 +-
 reports/architecture/README.md                     |   6 +-
 reports/current-status.md                          |   4 +-
 scripts/README.md                                  |   1 +
 scripts/check-architecture-reports.sh              | 180 ++++++++++++--
 scripts/check-current-status-consistency.sh        |  18 +-
 subrepos/adoption-matrix.jsonl                     |  12 +
 subrepos/adoption-matrix.md                        |  12 +
 subrepos/dirty-baseline.tsv                        |   6 +-
 subrepos/registry.csv                              |   6 +-
 superpowers                                        |   0
 tests/test_architecture_reports.sh                 |  73 +++++-
 tests/test_current_status_consistency.sh           |  18 +-
 tests/test_product_maturity_contracts.sh           |   4 +-
 vibeflow                                           |   0
 20 files changed, 598 insertions(+), 72 deletions(-)
```

### 最近提交

```text
8a4a3ee feat(governance): 集成 M5 与聚合门禁证据
7b3ef85 feat(subrepos): 重激活mattpocock技能参考仓
71e00f8 feat(governance): 支持参考子仓安全重激活
18b2ab3 docs(status): 锁定RC5意图边界基线
a9775b1 feat(governance): 吸收skills意图边界实践
```

## Context Layout
### Stable Context
- 仓库硬规则：所有命令经 `rtk`；手工修改经 `apply_patch`；不覆盖 dirty 变更；无证据不声明完成；不自动 commit/push/merge。
- 长期决策：MCP final release metadata 不等于兼容或激活；active/candidate/evidence/owner decision 分层治理。
- 可复用工作流：固定版本、隔离执行、负例覆盖、rollback 与 owner 授权分离。
- 可提升候选：MCP activation evidence contract。

### Dynamic Context
- 当前目标：完成四项 activation readiness 验证并生成 owner 决策包。
- 当前范围：仅 `agent-dev-kit` MCP compatibility contract 与根仓本轮 evidence/decision。
- 当前工作区状态：见上方工作区状态和变更规模
- 最近验证：Hub exact-source 审计要求证据绑定 source/version/environment；Go SDK `v1.7.0-pre.3` tag 已只读取回并核验 commit。
- 下一条命令：先建立 change 工件并运行 change governance，再新增测试取得红灯。

### Evidence Context
- 命令 / 退出码：详见新 change 的 `verify-report.md`。
- 工件路径：`agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/`。
- 负结果或被排除路径：不使用可变 latest SDK；不使用真实 OAuth/token；不把 metadata rollback 当作 runtime rollback。
- 证据缺口：四项技术证据与 owner activation decision。

### Excluded Context
- 不写入：secrets、auth、sessions、长日志、缓存、未审查 memory
- 需要脱敏后再归档：

## 关键决策（只保留可复用）
- 决策 1：SDK 固定为 `github.com/modelcontextprotocol/go-sdk v1.7.0-pre.3`，并记录 tag commit 与 module checksum。
- 决策 2：依赖准备与测试执行分离；最终 smoke 在 `--network=none` 容器和本地 loopback 中执行。

## 自动结晶（Crystallized Insights）
- Insight 1：
- 为什么重要：
- 是否应提升到 AGENTS / archive / memory：

## 操作队列
- steer（立即纠偏）：无。
- queue（后续追加）：技术证据通过后生成 owner decision request。
- scope-change（目标/验收变更）：owner 决定 ACTIVATE 后才允许进入 active/runtime 切换。

## 未决张力（Open Tensions）
- Tension 1：
- 为什么还没闭环：
- 下次恢复时先验证什么：

## 约束与风险
- 约束：Go SDK 当前为 pre-release；测试只覆盖固定 SDK、loopback HTTP 与声明的 auth/rollback profile。
- 风险：把局部 smoke 外推为生态全面兼容；通过 evidence scope 和 owner gate 限制。

## 下一步（可执行）
- Step 1: 建立 change 工件和红灯验收测试。
- Step 2: 准备固定依赖并离线运行四项 smoke。
- Step 3: 更新 gate、执行全量验证并生成 owner 决策包。

## 可审查产物
- Markdown note：本 preflight 与 change proposal/design/tasks/verify/review。
- index.html / 预览 / 截图：
- CSV / 表格 / 数据产物：
- diff / 测试报告 / artifact report：Go `-json` 测试输出、manifest gate diff、full regression。
- 归档或提升建议：完成后写 Knowledge Hub validation candidate。

## 验证命令
- `rtk agent-dev-kit/scripts/check-mcp-2026-activation.sh --offline`
- `rtk agent-dev-kit/tests/test_agent_ecosystem_standards.sh`
- `rtk agent-dev-kit/scripts/devkit.sh validate --strict`
- `rtk agent-dev-kit/tests/run_all.sh`
- `rtk git diff --check`

## 恢复提示（Resume Prompt）
继续处理：完成 MCP 2026-07-28 四项 activation readiness 证据并请求独立 owner decision。
从这些文件继续：`agent-dev-kit/docs/changes/mcp-2026-activation-readiness-2026-07-31/`、`agent-dev-kit/manifests/skill_mcp_dependencies.json`。
先执行：`rtk agent-dev-kit/scripts/check-mcp-2026-activation.sh --offline`
