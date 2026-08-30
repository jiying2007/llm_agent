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
