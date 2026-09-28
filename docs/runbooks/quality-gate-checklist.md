# 质量门禁 Check 脚本 Runbook

本 runbook 覆盖 `scripts/` 目录下 10 个质量门禁检查脚本的用途、用法、通过标准与失败排查。

---

## 1. check-adoption-matrix-status.sh

**用途**: 校验 `subrepos/adoption-matrix.md` 中真实记录的状态一致性。确保无遗留 `pending` 占位行，`blocked` 行必须附带解除条件。

**用法**:
```bash
scripts/check-adoption-matrix-status.sh [WORKSPACE_ROOT]
```
- `WORKSPACE_ROOT` 默认为脚本所在目录的上级。

**通过标准**:
- 所有真实数据行（日期格式行）的 `验收状态` 列不为 `pending`。
- `blocked` 行必须在 `证据` 列注明解除条件。

**失败排查**:
- `[FAIL] adoption-matrix still has real pending rows` → 打开 `subrepos/adoption-matrix.md`，找到输出中列出的行号，将 `pending` 更新为 `done` 或 `blocked`（附解除条件）。
- `[FAIL] blocked row missing unblock condition` → 在 `证据` 列补充解除条件说明。

---

## 2. check-runtime-pilot.sh

**用途**: 统一校验 runtime pilot 报告的完整性。支持三种模式：`evidence`（4 个基础证据字段）、`coverage`（7 个覆盖字段 + 场景验证）、`full`（全部检查，默认）。

**用法**:
```bash
scripts/check-runtime-pilot.sh [WORKSPACE_ROOT] [MODE]
```
- `MODE` 可选：`evidence` | `coverage` | `full`（默认 `full`）

**通过标准（evidence 模式）**:
- `reports/codex-pilot-report.md` 存在。
- 门禁证据状态节存在。
- 以下字段值均为 `yes`：`pilot_high_risk_case_done`、`artifact_labels_complete`、`review_test_consistent`、`command_evidence_recorded`。

**通过标准（coverage 模式）**:
- 以下 7 个字段均存在于报告中：`pilot_full_coverage_ready`、`pilot_feature_delivery_done`、`pilot_bugfix_delivery_done`、`pilot_refactor_hardening_done`、`pilot_release_hardening_done`、`pilot_team_handoff_done`、`pilot_upstream_intake_done`。
- `pilot_full_coverage_ready=yes` 时，六类场景字段均为 `yes`。
- 每个 `yes` 场景对应章节存在，且包含 `ImplementationPlan`、`ReviewReport`、`TestReport` artifact 标签。
- 命令级 Evidence Index 中包含对应场景的可复现命令。

**通过标准（full 模式）**: 同时满足 evidence 和 coverage 的全部通过标准。

**失败排查**:
- `[FAIL] pilot evidence key not ready: xxx=<missing/empty>` → 在 pilot 报告中找到对应字段，确认试跑已完成且证据已补充。
- `[FAIL] pilot coverage field missing: xxx` → 在 pilot 报告中补齐对应覆盖字段。
- `[FAIL] scenario field not yes` → 在 pilot 报告中补齐对应场景的试跑证据。
- `[FAIL] missing artifact tag` → 在场景章节中补充 `ImplementationPlan` / `ReviewReport` / `TestReport` 标签。
- `[FAIL] missing command-level evidence` → 在 Evidence Index 中添加可复现命令。
- 报告不存在 → 先执行目标运行态试跑并生成 `reports/codex-pilot-report.md`。

> **便捷入口**: `check-runtime-pilot-evidence.sh` 和 `check-runtime-pilot-coverage.sh` 分别固定执行 evidence / coverage 模式。

---

## 3. check-delivery-adopt-depth.sh

**用途**: 校验 `delivery` 类 `adopt + done` 行具备 Agent/Skill/Workflow 三层证据及 wave 任务包报告。

**用法**:
```bash
scripts/check-delivery-adopt-depth.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `subrepos/adoption-matrix.md` 存在。
- 所有 `delivery` + `adopt` + `done` 行的 `证据` 列同时包含：
  - Agent 层证据（`agent-dev-kit/agents/` 路径）
  - Skill 层证据（`agent-dev-kit/skills/` 路径）
  - Workflow 层证据（`agent-dev-kit/docs/workflows.md` 或 `agent-dev-kit/scripts/workflow.sh`）
  - Wave 报告证据（`reports/wave*-*.md`）

**失败排查**:
- `[FAIL] delivery adopt row missing xxx evidence` → 在 `subrepos/adoption-matrix.md` 对应行的 `证据` 列补充缺失的证据路径。
- 确保 agent-dev-kit 中对应的 Agent/Skill/Workflow 资产已落地。

---

## 4. check-doc-sync.sh

**用途**: 校验治理文档之间的同步一致性，确保 `registry.csv`、`scripts/README.md`、`adoption-matrix.md` 与根 `AGENTS.md` 入口边界无漂移。

**用法**:
```bash
scripts/check-doc-sync.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `subrepos/registry.csv` 存在。
- `scripts/README.md` 存在。
- `subrepos/adoption-matrix.md` 存在。
- 根 `AGENTS.md` 不超过 slim-entry 行数预算，并指向 registry、adoption matrix、维护指南和吸收治理文档。
- adoption-matrix 中引用的仓库名均在 registry 中注册。

**失败排查**:
- `[FAIL] registry missing` → 确认 `subrepos/registry.csv` 文件存在。
- `[FAIL] repo in matrix but not in registry` → 在 `registry.csv` 中补充缺失的子仓条目。
- `[FAIL] root AGENTS.md exceeds slim-entry budget` → 将子仓清单、历史计划或长说明迁移到 registry、adoption matrix、维护指南或 reports。
- `[FAIL] root AGENTS.md missing slim-entry token` → 补回对应 SSOT 链接，避免入口文档失去可追溯来源。

---

## 5. check-runtime-targets.sh

**用途**: 校验 `manifests/runtime_targets.json` 与 `adk.lock`、`subrepos/registry.csv`、运行态检查脚本一致，避免 `~/.codex` 这类目标路径散落在脚本中成为隐式事实。

**用法**:
```bash
scripts/check-runtime-targets.sh [WORKSPACE_ROOT]
scripts/check-runtime-targets.sh [WORKSPACE_ROOT] --summary-json
```

**通过标准**:
- `schema_version=1` 且 `status=active`。
- `default_target` 指向已声明 target。
- 默认 target 当前为 `codex`，`source_repo=~/codex`，`live_root=~/.codex`。
- 默认 target 与 `adk.lock` 的 `codex.source` / `codex.target` 一致。
- `subrepos/registry.csv` 的 `codex` 行保持 `runtime-target`、`enabled=no`、`status=disabled`、`intake_policy=pilot-first`。
- 支持的 runtime kind 至少包含 `codex`、`claude-code`、`hermes-agent`、`opencode`。

**失败排查**:
- manifest 与 `adk.lock` 不一致 → 先确认真实 source/live 链路，再同步两处事实。
- registry 缺少 `codex` 行或状态不符 → 恢复 runtime-target 禁用参考仓语义，避免把 `~/codex` 当参考子仓同步。
- target check 脚本缺失或不可执行 → 修复脚本入口和文件权限后复跑。

---

## 6. check-reference-dirty-triage.sh

**用途**: 校验当天 `reports/reference-dirty-triage-YYYY-MM-DD.json` 与 `subrepos/dirty-baseline.tsv` 一致，确保参考子仓 dirty 状态有报告解释，而不是混入治理提交。

**用法**:
```bash
scripts/generate-reference-dirty-triage.sh . --out reports/reference-dirty-triage-YYYY-MM-DD.md --json-out reports/reference-dirty-triage-YYYY-MM-DD.json
scripts/check-reference-dirty-triage.sh . --summary-json
scripts/check-reference-dirty-triage.sh . --date YYYY-MM-DD --summary-json
```

**通过标准**:
- 报告为 `report-only`。
- `OpenSpec`、`superpowers`、`vibeflow` 均存在 triage item。
- 每项 `decision=known-dirty-review`、baseline 未过期、fingerprint 匹配。

---

## 7. check-runtime-health.sh

**用途**: 读取 `manifests/runtime_targets.json` 的默认或指定 target，再通过 `manifests/runtime_health_adapters.json` 中的 `target.health_adapter` 绑定分发到只读健康检查 adapter。当前 active target 是 `codex-home`，因此会调用 `check-global-codex-health.sh`。

**用法**:
```bash
scripts/check-runtime-health.sh [WORKSPACE_ROOT] [--target codex-home] [--profile minimal|security|strict]
scripts/check-runtime-health.sh [WORKSPACE_ROOT] --summary-json
```

**通过标准**:
- target 已声明且 `enabled=true`。
- target 拥有 `health_adapter` 和 `live_root`。
- adapter 已声明、`enabled=true`、`read_only=true`，runtime 与 target 匹配。
- adapter 可执行、支持指定 profile，且返回 exit 0。

---

## 8. check-runtime-health-adapters-fixtures.sh

**用途**: 用临时 fixture 校验 runtime health adapter contract 的负例行为，防止 `runtime_targets.json` 重新双写 `health_check`，或 adapter runtime/profile/script/binding 漂移后仍被误放行。

**用法**:
```bash
scripts/check-runtime-health-adapters-fixtures.sh [WORKSPACE_ROOT]
```

**通过标准**:
- pass fixture 能通过 `check-runtime-targets.sh`。
- runtime mismatch、disabled adapter、profile 缺失、script 不可执行、binding 缺失和 legacy `health_check` 残留均必须失败。

---

## 9. check-global-codex-health.sh

**用途**: 校验全局 `~/.codex` 目录的健康状态。该运行目录应由 `~/codex` build/apply 生成，健康检查依赖运行目录中的 control 状态。

**用法**:
```bash
scripts/check-global-codex-health.sh [CODEX_ROOT] [PROFILE]
```
- `CODEX_ROOT` 默认 `~/.codex`
- `PROFILE` 默认 `minimal`

**通过标准**:
- `CODEX_ROOT` 目录存在。
- `~/codex/scripts/doctor.sh` 存在。
- `~/codex/scripts/doctor.sh --scope live --target CODEX_ROOT` 返回 exit 0 且输出 `errors=0`。
- `PROFILE=security|strict` 时，未审查 provider/base URL 会阻断，MCP loaded-list 审计必须可执行或给出降级原因。

**失败排查**:
- `[FAIL] global codex dir missing` → 确认 `~/codex` 已执行 build/apply 到 `~/.codex`。
- `[FAIL] ~/codex doctor script missing` → 确认 `~/codex` 声明式资产仓库存在；不要从 adk 直接补 `~/.codex` 文件。
- doctor 运行失败 → 先在 `~/codex` 运行 `scripts/doctor.sh --scope all` 和 apply dry-run，再修复 `~/.codex` 目录结构。
- security profile 失败 → 审查 base URL / relay / MCP / hooks，必要时设置 `CODEX_TRUSTED_BASE_URLS` 为已审查端点片段后复跑。

---

## 9. check-global-codex-target-policy.sh

**用途**: 确保工作区未回退到使用本地 `codex/` 目录，强制使用 `~/codex` 作为声明式资产仓库，并由它 apply 到全局 `~/.codex`。该检查也会联动 `check-runtime-targets.sh`，确保 target registry 没有漂移。

**用法**:
```bash
scripts/check-global-codex-target-policy.sh [WORKSPACE_ROOT]
```

**通过标准**:
- 工作区根目录下不存在 `codex/` 子目录。
- `subrepos/registry.csv` 中 `codex` 行的 `intake_policy` 不指向本地路径。

**失败排查**:
- `[FAIL] local codex directory still exists: xxx/codex` → 删除或移走本地 `codex/` 目录。
- `[FAIL] registry missing codex row` → 在 `registry.csv` 中确认 `codex` 条目存在。
- `[FAIL] codex row has local target` → 修改 registry 中 codex 行的策略字段，确保指向 `~/codex -> ~/.codex`。

---

## 7. check-adk-target-evidence.sh

**用途**: 防止 `adoption-matrix` 只更新 `llm_agent` 报告却声明已经落地到 `agent-dev-kit`。

**用法**:
```bash
scripts/check-adk-target-evidence.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `subrepos/adoption-matrix.md` 存在。
- 2026-06-29 起，`target` 包含 `agent-dev-kit` 且 `decision=adopt|observe`、`state=done` 的行，`证据` 列必须包含至少一个实际存在的 `agent-dev-kit/...` 路径。

**失败排查**:
- `[FAIL] adk target evidence checks failed` → 要么把实践真正回灌到 `agent-dev-kit` 资产并补 evidence，要么把 `target` 降为 `llm_agent` / `reference-only`。

## 8. check-observe-intake-depth.sh

**用途**: 校验 `observe + done` 行具备 Agent/Skill/Workflow 三层证据及 intake 任务包报告。当无 `observe+done` 行时自动通过。

**用法**:
```bash
scripts/check-observe-intake-depth.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `subrepos/adoption-matrix.md` 存在。
- 若存在 `observe` + `done` 行，每行的 `证据` 列必须同时包含 Agent、Skill、Workflow 三层证据和 intake 报告证据。
- 若无 `observe+done` 行，直接通过并提示 `backlog cleared`。

**失败排查**:
- `[FAIL] observe+done row missing xxx evidence` → 在 `subrepos/adoption-matrix.md` 对应行补充缺失证据路径。
- 若 observe 队列已清零但脚本报错 → 检查是否有行被错误标记为 `observe` + `done`。

---

## 9. check-runtime-routing.sh

**用途**: 校验当前 ADK JSON Manifest 的核心 profile、路由矩阵、Skill 和 runbook；随后执行触发冲突检查与 ADK strict validator。

**用法**:
```bash
rtk scripts/check-runtime-routing.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.json` 存在，并声明 `core`、`embedded-fullstack`、`adk-runtime-router`、`adk-planning-execution-loop` 与非空路由矩阵。
- 当前 routing、planning、upstream、security、team runbook 存在。
- `check-skill-routing-conflicts.sh` 与 `devkit.sh validate --strict` 通过。

**失败排查**:
- `[FAIL] active ADK routing contract is incomplete` → 核对 `manifest.json` 的 profile、Skill 与路由矩阵。
- `[FAIL] skill routing conflicts found` → 核对冲突 Skill 的 `triggers`，确认 primary 触发边界。
- strict validation 失败 → 从 ADK 仓执行 `rtk scripts/devkit.sh validate --strict` 查看实际合同失败项。

---

## 10. check-skill-metadata.sh

**用途**: 校验 `agent-dev-kit` 中所有 skill 的 `SKILL.md` 元数据完整性。

**用法**:
```bash
rtk scripts/check-skill-metadata.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.json` 存在，core 与 optional Skill 列表均非空，名称无重复。
- Manifest 中每个 Skill 的 `path` 指向现存文件，`quality_tier` 已声明。
- `SKILL.md` frontmatter 的 `name` 与 Manifest 一致，`version` 为 semver，`last_updated` 为有效日期；其余字段由 ADK strict validator 检查。

**失败排查**:
- `[FAIL] ... file missing` → 核对 Manifest 中该 Skill 的 `path` 与当前目录。
- frontmatter 字段失败 → 修改对应 `SKILL.md`，再运行 ADK strict validator。
- `[FAIL] manifest missing` → 确认 `agent-dev-kit/manifest.json` 存在。

---

## 11. check-skill-routing-conflicts.sh

**用途**: 检测 core 与 optional Skill frontmatter 中归一化后的 `triggers` 是否被多个 Skill 重复声明。

**用法**:
```bash
rtk scripts/check-skill-routing-conflicts.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.json` 存在。
- Manifest 声明的 Skill 有可读取的 frontmatter `triggers`，归一化后不跨 Skill 重复。

**失败排查**:
- `[CONFLICT] trigger=... skills=...` → 修改相关 Skill 的 `triggers` 或组合路由，使 primary 边界明确。

---

## 综合使用

所有 10 个门禁均已接入 `check-adk-harden-readiness.sh` 主链路，默认自动执行。可单独运行任一脚本进行快速定位：

```bash
# 一次性运行全部门禁
scripts/check-adk-harden-readiness.sh . --require-pilot

# 单独运行某个门禁
scripts/check-adoption-matrix-status.sh .
scripts/check-skill-metadata.sh .
```
