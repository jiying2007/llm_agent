# Maintainability Evidence Candidate

`scripts/generate-maintainability-evidence.sh` 从当前仓库两个真实 Git commit 生成 churn evidence candidate。
它只生成 `review-required` 候选，不会修改 `manifests/comprehensive_optimization_backlog.json`，也不会自行
标记 reviewed。

## 输入门禁

- revision start/end 必须解析为当前 root 的完整 commit，且 start 是 end 的 ancestor。
- 固定时间窗口必须包含两个 commit 的 committer time，并满足 `start < end <= generated_at`。
- population 是 start/end 两个 Git tree 的路径全集；records 必须覆盖全集并绑定 count/digest/complete。
- binary numstat 直接拒绝，不能用零行掩盖二进制变更。
- Git 输出有 16 MiB 上限；非 UTF-8、危险路径、凭证或 raw-content 路径均拒绝。

## Dry-run

```bash
rtk scripts/generate-maintainability-evidence.sh \
  --repository-id llm-agent \
  --revision-start <start-commit> \
  --revision-end <end-commit> \
  --window-started-at <RFC3339> \
  --window-ended-at <RFC3339> \
  --output /tmp/churn-candidate.json \
  --summary-json
```

默认只报告 candidate ID、content digest 和 record count，不创建文件。显式 `--apply` 仅允许写到仓库
`reports/` 或系统 `/tmp`，拒绝 symlink、既有目标和隐式覆盖。

## Owner review

Candidate 内的 `evidence_content_sha256` 是 canonical content digest，不是未来 evidence 文件的字节 SHA。
Owner 决定接受后仍必须：

1. 单独保存脱敏 evidence object；
2. 对实际文件重新计算 SHA-256；
3. 审查 repository/window/population；
4. 显式更新 backlog 的 source 与 expected population；
5. 重跑 strict maintainability gate。

Ownership 和 inactive-asset candidate 需要显式受审 scope/receipt population；本工具不会从 Git 身份或缺失
telemetry 推断它们。

## Hosted review-only collection

`.github/workflows/maintainability-candidate.yml` reuses the canonical Git-history candidate generator on Monday 02:17 UTC, explicit manual dispatch, or a PR that changes this workflow/generator/test. It checks out the protected main source with full Git history, selects the most recent first-parent commit at/before the seven-day cutoff, and freezes the exact two commits and their commit-time window.

The job runs with `contents: read`, no external model/provider request, and no repository mutation. It records only a `review-required` candidate and compact result as temporary workflow artifacts. If no two distinct eligible revisions exist, it emits explicit `not-available` rather than inventing zero churn; source-history parse or budget errors fail the job. Artifacts expire and must not be described as a reviewed baseline.

Promoting churn to a maintainability budget still requires the existing owner-review steps above. `owner_concentration` and `inactive_assets` remain `not-available` until independent reviewed ownership and genuine sanitized invocation snapshots exist. No new tool or shadow evidence authority is introduced.

## 同一完整人口的可诊断 Churn 分组

`scope_diagnostics` 是 candidate/result 中额外的 **report-only** 视图，不是新的 Evidence Index 或维护预算，也不改变 `llm-agent-maintainability-evidence/v1` 的全人口、记录或 SHA-256。

该视图按已存在的文件路径拆分 `audit-evidence`、`change-docs`、`documentation`、`reports`、`tests`、`implementation`、`manifests`、`other` 八类，报告每类实际变动行数和发生变动的文件数（不把原本就存在的零变动文件算成活跃文件）。`changed_lines_total` 与各类总和必须相等；所有类别包括历史审查证据，**没有任何门禁排除或预算豁免**。

用途：避免海量留存审查证据把真正需要维护的源码或测试热点淹没。所有优化/淘汰仍须基于完整原始证据和对应 Owner 审查；即使 implementation 变动低，也不得推导效果或无风险。
