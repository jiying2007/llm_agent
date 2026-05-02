# 报告目录说明

本目录用于沉淀持续迭代证据，避免“只有结论没有验证”。

## 文件约定

- `weekly-change-report.md`：由 `scripts/diff-scan.sh` 生成的最新周报
- `weekly-change-report.template.md`：周报模板
- `codex-pilot-report.md`：`codex` 实战试跑报告
- `codex-pilot-report.template.md`：`codex` 试跑模板

## 最小流程

1. 执行 `scripts/sync-subrepos.sh . fetch`
2. 执行 `scripts/diff-scan.sh . 7 reports/weekly-change-report.md`
3. 评估候选项并写入 `subrepos/adoption-matrix.md`
4. 在 `codex` 试跑后更新 `reports/codex-pilot-report.md`

