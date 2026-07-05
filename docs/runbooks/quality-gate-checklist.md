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

## 2. check-codex-pilot.sh

**用途**: 统一校验 codex pilot 报告的完整性。支持三种模式：`evidence`（4 个基础证据字段）、`coverage`（7 个覆盖字段 + 场景验证）、`full`（全部检查，默认）。

**用法**:
```bash
scripts/check-codex-pilot.sh [WORKSPACE_ROOT] [MODE]
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
- 报告不存在 → 先执行 codex 试跑并生成 `reports/codex-pilot-report.md`。

> **旧脚本兼容**: `check-codex-pilot-evidence.sh` 和 `check-codex-pilot-coverage.sh` 已标记弃用，自动转发到本脚本。

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

## 5. check-global-codex-health.sh

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

## 6. check-global-codex-target-policy.sh

**用途**: 确保工作区未回退到使用本地 `codex/` 目录，强制使用 `~/codex` 作为声明式资产仓库，并由它 apply 到全局 `~/.codex`。

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

**用途**: 校验 `agent-dev-kit` 的 runtime routing 资产完整性，同时调用 `check-profile-coherence.sh` 防止 profile 继承后重复声明。

**用法**:
```bash
scripts/check-runtime-routing.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.yaml` 存在。
- manifest 中定义的所有 skill 在 routing 中有对应条目。
- routing 条目的 intent 关键词无冲突。
- profile coherence 检查通过（无重复 Agent/Skill 声明）。

**失败排查**:
- `[FAIL] missing routing for skill: xxx` → 在 manifest 的 routing 部分为该 skill 添加路由条目。
- `[FAIL] duplicate intent keyword` → 修正 routing 中冲突的 intent 关键词。
- profile coherence 失败 → 运行 `agent-dev-kit/scripts/check-profile-coherence.sh` 查看详细输出，清理重复声明。

---

## 10. check-skill-metadata.sh

**用途**: 校验 `agent-dev-kit` 中所有 skill 的 `SKILL.md` 元数据完整性。

**用法**:
```bash
scripts/check-skill-metadata.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.yaml` 存在。
- manifest 中声明的每个 skill 目录下存在 `SKILL.md`。
- 每个 `SKILL.md` 包含必填字段：`name`、`description`、`version`、`intent_keywords`、`quality_tier`。

**失败排查**:
- `[FAIL] SKILL.md missing in: xxx` → 在对应 skill 目录创建 `SKILL.md`，按模板填充。
- `[FAIL] missing field in SKILL.md: xxx` → 在 `SKILL.md` 头部 frontmatter 补充缺失字段。
- `[FAIL] manifest missing` → 确认 `agent-dev-kit/manifest.yaml` 存在。

---

## 11. check-skill-routing-conflicts.sh

**用途**: 检测 `agent-dev-kit` 中 skill 路由的 intent 关键词冲突，防止多个 skill 匹配同一意图导致歧义。

**用法**:
```bash
scripts/check-skill-routing-conflicts.sh [WORKSPACE_ROOT]
```

**通过标准**:
- `agent-dev-kit/manifest.yaml` 存在。
- 所有 skill 的 `intent_keywords` 无完全重复项。
- 同一 quality_tier 内的 skill 不共享相同关键词。

**失败排查**:
- `[FAIL] duplicate intent keyword: "xxx" in skills [a, b]` → 修改其中一个 skill 的 intent_keywords，使其与其他 skill 区分。
- `[FAIL] conflict in tier "xxx": skills [a, b] share keyword "yyy"` → 在 manifest 的 routing 部分调整关键词或合并 skill。

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
