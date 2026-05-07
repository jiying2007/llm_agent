# adk v1 迁移与回滚方案（2026-05-02）

## 1. 变更类型判定

本轮存在“治理契约级 Breaking Change”，范围如下：

1. `subrepos/registry.csv` 字段从 7 列扩展到 11 列：
- 旧：`repo,group,priority,sync_mode,branch,enabled,notes`
- 新：`repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy`
2. `check-adk-harden-readiness` 默认新增三类强校验：
- `check-skill-metadata`
- `check-skill-routing-conflicts`
- `check-doc-sync`

影响边界：仅影响本仓治理流程与门禁脚本，不影响业务代码运行时逻辑。

## 2. 迁移步骤（落地到 v1）

1. 同步脚本与文档
- 确保以下脚本存在并可执行：
  - `scripts/check-skill-metadata.sh`
  - `scripts/check-skill-routing-conflicts.sh`
  - `scripts/check-doc-sync.sh`
  - `scripts/check-adk-harden-readiness.sh`
- 文档同步：
  - `scripts/README.md`
  - `subrepos/adoption-matrix.md`

2. 数据与契约迁移
- 将 `subrepos/registry.csv` 迁移到 11 列新表头。
- 为每个仓填充 `status/owner/last_reviewed_on/intake_policy`。

3. 验证迁移结果
- `rtk scripts/check-doc-sync.sh .`
- `rtk scripts/check-adk-harden-readiness.sh . --require-pilot`

## 3. 回滚策略

### 3.1 运营级快速回滚（优先）

当新增门禁导致紧急阻断时，先降级到“兼容模式”：

```bash
rtk scripts/check-adk-harden-readiness.sh . \
  --require-pilot \
  --skip-skill-metadata-check \
  --skip-routing-conflicts-check \
  --skip-doc-sync-check \
  --skip-full-suite
```

说明：保留基础安全门禁（`validate_assets`、`optional_skills`、`no_external_refs`、`pilot`、`global_codex_health`），临时绕过新增强校验，保障流程可继续。

### 3.2 代码级回滚（必要时）

若需恢复到重构前脚本版本：

1. 回退以下文件到上一个稳定提交：
- `scripts/check-adk-harden-readiness.sh`
- `scripts/diff-scan.sh`
- `scripts/sync-subrepos.sh`
- `scripts/check-global-codex-target-policy.sh`
- `subrepos/registry.csv`
- `subrepos/adoption-matrix.md`
2. 回退后强制复验：
- `rtk scripts/check-adk-harden-readiness.sh . --skip-full-suite`

## 4. 回滚演练记录（已执行）

- 时间：2026-05-02 09:52:51 CST
- 演练命令：
  - `rtk scripts/check-adk-harden-readiness.sh . --require-pilot --skip-skill-metadata-check --skip-routing-conflicts-check --skip-doc-sync-check --skip-full-suite`
- 演练结果：
  - `[PASS] adk harden baseline checks passed`
  - `[PASS] codex pilot evidence ready`
  - `[PASS] global codex health ready`

结论：运营级回滚路径可执行，可作为紧急兜底策略。
