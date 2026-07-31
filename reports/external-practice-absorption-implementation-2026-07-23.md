# 外部实践吸收落地实施报告（2026-07-23）

- 状态：`implemented-control-plane / real-evidence-blocked`
- 范围：`llm_agent` 与 `agent-dev-kit`
- Owner 授权：用户在研究候选提交后明确要求“按建议全部吸收落地”。
- Candidate：`reports/external-practice-absorption-candidates-2026-07-23.jsonl`（11/11 schema pass）。
- Decision：`reports/external-practice-absorption-decisions-2026-07-23.jsonl`（8 ENHANCE、3 OBSERVE，11/11 schema pass）。
- 研究来源：`reports/external-practice-search-and-absorption-candidates-2026-07-22.md`。
- 版权边界：只保存来源 metadata、方法摘要和本地重构结果；未保存外部正文、benchmark task、数据集或容器。

## 1. 已落地能力

### Repository runtime evidence

- 新增确定性 repository eval contract、CLI plan/certify、5 条 clean-room canary metadata 和 Level 2 正负测试。
- 同一 task/revision/runtime 下比较 baseline/adk，各 3 trials；重算 contract/task digest 并要求完整 60-result matrix。
- baseline 必须隔离 project instructions、Skills、Hooks、MCP、plugins；ADK condition 只启用审查过的 surface。
- 功能 oracle 先于安全 oracle；盲目重试、回归循环、缺失最终验证、阶段乱序和重复调用无新证据均阻止 lucky pass。
- 统计 token/cost/elapsed 的 p50/p95/max/CV、cost-per-success、attempt/tool-call/timeout 和 trial non-regression。
- `contract-only` / clean-room 只能返回 `fixture-pass`；真实 `pass` 要求 owner-approved real task、available adapter 和 SHA-256 version pin。
- 根 Software M5 新增独立 `repository_runtime_campaign` blocker，缺真实 report 时 fail closed。

主要资产：

- `agent-dev-kit/src/agent_dev_kit/repository_evaluation.py`
- `agent-dev-kit/manifests/repository_runtime_eval_contract.json`
- `agent-dev-kit/tests/fixtures/repository_runtime_eval_tasks.jsonl`
- `agent-dev-kit/tests/test_repository_runtime_evidence.sh`
- `tools/codex_assets/software_m5.py`

### MCP compatibility staging

- active protocol 保持 `2025-11-25`；`2026-07-28-rc` 只进入 candidate staging。
- candidate 记录 capability、extension IDs、deprecated features、auth profile、compatibility test 与 rollback。
- `final_spec_retrieved=false`、`runtime_enabled=false`、`final_compatibility_claim=false`、`extension_ids=[]`。
- candidate auth 不得弱于 active profile；weak-auth、runtime-enabled 负 fixture 均 fail closed。
- 官方 RC 复核确认 roots、sampling、logging 为 annotation-only deprecated，当前版本仍可用，移除需另行 SEP 且有至少一年窗口。

主要资产：

- `agent-dev-kit/manifests/skill_mcp_dependencies.json`
- `agent-dev-kit/fixtures/agent-ecosystem-standards/fail/mcp-rc-runtime-enabled.json`
- `agent-dev-kit/fixtures/agent-ecosystem-standards/fail/mcp-rc-weak-auth.json`

### Field evidence v2

- M5 新增 `task_selection_recorded` 与 `human_baseline_recorded`。
- 预注册数必须等于接受数加拒绝数；唯一 selection/baseline 必须满足 selection ≤ baseline ≤ first workload。
- 分离 wall-clock、human-active、agent-active、concurrent-agent peak，并验证时间一致性。
- reviewer 必须审查 selection bias、time measurement 和 confidence interval。
- human baseline、wall time 和 agent time 不允许零值替代真实测量。
- M5 动态使用 ADK certifier 前核验模块路径位于受信 source root，防止 Python module cache 替换。

主要资产：

- `manifests/software_m5_policy.json`
- `tools/codex_assets/software_m5.py`
- `tests/test_software_m5_certification.sh`
- `agent-dev-kit/skills/adk-production-field-readiness/references/pilot-measurement-evidence.md`

### Skill security / maintenance / target watch

- AST01-AST10 映射到本地 surface/control/evidence/residual risk；明确不构成 OWASP 认证。
- Skill 维护 contract 区分 stable behavior 与 target-local binding，要求 revision、SHA-256 digest、use/effect、verified/refresh/retire 和 rollback evidence。
- use/effect 只允许 `not-measured` 或显式 `measured:*`；lifecycle date 必须有效且不倒退。
- VS Code/GitHub Copilot 保持 watch-only；没有 use case、固定版本、discovery、export/install smoke、effect、安全和 rollback 前不新增 direct target。

主要资产：

- `agent-dev-kit/manifests/skill_reproducibility_contracts.json`
- `agent-dev-kit/manifests/external_agent_pattern_contracts.json`
- `agent-dev-kit/scripts/check-agent-ecosystem-standards.sh`
- `reports/observe-secondary-intake-packages-2026-07-23.md`

## 2. 复审闭环

初审共发现并修复 8 个 major、1 个 minor、1 个 source question，最终未留 blocker/major/minor：

- bool trial 冒充 trial 1；
- contract-only adapter 误获真实 `pass`；
- post-hoc selection 与零值测量；
- 非受信 certifier module provenance；
- MCP candidate 弱 auth；
- Skill digest 只检查非空；
- target watch fixture 未覆盖 contract 全字段；
- use/effect 与生命周期日期过宽；
- trace ref 路径边界；
- MCP 具体 deprecated feature 来源真实性。

四个 change 均为 `review-passed`：

- `agent-dev-kit/docs/changes/repository-runtime-evidence-v1/`
- `agent-dev-kit/docs/changes/mcp-2026-compat-staging/`
- `agent-dev-kit/docs/changes/field-evidence-v2/`
- `agent-dev-kit/docs/changes/skill-security-maintenance-v1/`

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `rtk bash agent-dev-kit/tests/test_repository_runtime_evidence.sh` | pass |
| `rtk bash agent-dev-kit/tests/test_agent_ecosystem_standards.sh` | pass |
| `rtk tests/test_software_m5_certification.sh` | pass |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | pass |
| `rtk bash agent-dev-kit/tests/run_all.sh --quick` | 19/19 pass |
| `rtk bash agent-dev-kit/tests/run_all.sh --timing-json /tmp/repository-absorption-adk-timing-final.json` | 56/56 pass |
| `rtk scripts/check-practice-intake.sh .` | pass |
| `rtk scripts/check-observe-intake-depth.sh .` | pass（11 rows） |
| `rtk scripts/check-adoption-matrix-structured.sh .` | pass |
| `rtk scripts/check-product-maturity-contracts.sh .` | pass |
| `rtk git diff --check`（root 与 ADK） | pass |
| `rtk scripts/check-all.sh --quick` | 50/53；仅 dirty/baseline 状态门禁未通过 |

根总门禁剩余 3 项不是能力回归：

- `check-current-status-consistency`：下游 `subrepo-state` 非 pass；本次 ADK 改动未提交时 strict subrepo 必然为 dirty。
- `check-reference-dirty-triage`：进入任务前已有 OpenSpec、superpowers、vibeflow dirty baseline，且 review date 为 2026-07-20，当前已过期。
- `check-subrepo-state`：上述三个用户 dirty 子仓，加上本次未提交的 `agent-dev-kit` 改动。

未自动 commit、push、merge、rebase、清理 dirty 子仓或刷新 owner baseline。

## 4. 当前真实阻塞

`software-m5.sh status --summary-json` 当前为：

- `integrity_status=pass`
- `readiness_status=m5-ready`
- `certification_status=blocked`
- `software_m5_certified=false`
- blockers：`final_version`、`independent_repository`、`operator_count`、`pilot_duration`、`real_repository_count`、`repository_runtime_campaign`、`required_field_events`、`runtime_campaign`

因此本次完成的是控制面、schema、validator、fixture、文档和门禁落地，不是 M5 真实认证。后续只有在至少两个 runtime、5 个 task、2 条 owner-approved real-repository task、各 3 trials 的真实 campaign，以及第二 operator、独立仓、30 天 field pilot 证据完成后，才允许解除阻塞。

## 5. Provenance

- Source URLs、retrieved date 与不可迁移边界见研究报告及 candidate JSONL。
- MCP RC 官方复核：<https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/>，复核日期 2026-07-23。
- 本报告不替代外部 source license、task license、runtime credential 或真实 field owner approval。

## 6. Knowledge Hub 候选

- 已通过 `knowledge-capture.sh --dry-run` 后事务写入 `reviewing` 候选：`projects/llm-agent/archive/research/2026-07-23-external-practice-absorption-implementation.md`。
- Candidate ID：`llm-agent-external-practice-absorption-20260723`；`review_after=2026-10-23`；未晋升为 active。
- 定向检索为 `pass`，registry、正文路径及 owner/status/review-date 索引引用均存在。
- Hub 全库 dry-run 仍被 4 个既有 `xcrz-sigmastar-demo` body-coverage 漂移阻断；这些错误不属于本次写入，未越权修复。

## 7. 完成前核验

### Evidence Index

| 命令 | Exit Code | 结果摘要 | 证据路径 | 层级 | 关联工件 |
|---|---:|---|---|---|---|
| `rtk bash agent-dev-kit/tests/test_repository_runtime_evidence.sh` | 0 | repository runtime 正负路径通过 | `agent-dev-kit/tests/test_repository_runtime_evidence.sh` | Workflow | `repository-runtime-evidence-v1` |
| `rtk bash agent-dev-kit/tests/test_agent_ecosystem_standards.sh` | 0 | MCP、Skill security/maintenance/target 正负路径通过 | `agent-dev-kit/tests/test_agent_ecosystem_standards.sh` | Workflow | `mcp-2026-compat-staging`、`skill-security-maintenance-v1` |
| `rtk tests/test_software_m5_certification.sh` | 0 | field evidence v2 与 M5 fail-closed 测试通过 | `tests/test_software_m5_certification.sh` | Workflow | `field-evidence-v2` |
| `rtk bash agent-dev-kit/tests/run_all.sh --timing-json /tmp/repository-absorption-adk-timing-final.json` | 0 | ADK full 56/56 | `/tmp/repository-absorption-adk-timing-final.json` | Workflow | 全部 ADK change |
| `rtk scripts/check-all.sh --quick` | 1 | 50/53；仅既有/预期 dirty 与过期 baseline 状态门禁失败 | 本报告 §3 | Workflow | 根仓总门禁 |
| `rtk bash knowledge-check.sh --dry-run --json --diagnostics --explain llm-agent-external-practice-absorption-20260723` | 1 | 本候选及索引均正常；Hub 全库被 4 个既有 xcrz body-coverage 漂移阻断 | Knowledge Hub registry 与 explain 输出 | Workflow | Hub candidate |

### 结论与回退

- Claimant：四类控制面已落地；Verifier：定向、strict、quick、full 与独立 review 证据支持该声明。
- Review：最终 `blocker=0 / major=0 / minor=0`；初审负结果和修复记录保存在四个 change 的 `review-report.md`。
- Breaking change：运行时 active MCP 未切换，现有 runtime 默认行为无破坏性变化；Software M5 认证契约被有意收紧，旧的不足证据会新增 blocker，而不会被静默迁移为 pass。
- 回退：以四个 change package 为审查和回退单元，恢复对应 manifest/checker/policy 前一版本；MCP candidate 可独立删除且 active protocol 不受影响。仓库仍未 commit，因此未执行任何自动回退或 Git 历史改写。
- Final Gate：`implemented-control-plane / real-evidence-blocked`。控制面实现可交付；真实 M5 认证固定为 `needs-fix`，责任人需补真实 repository/runtime/field/operator/pilot 证据。
