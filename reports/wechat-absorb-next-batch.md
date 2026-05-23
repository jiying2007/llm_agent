# WeChat Article Absorption Next Batch

- 数据源：`wechat-articles/`
- Ledger：`reports/wechat-article-intake.jsonl`
- 批次策略：优先 P0/P1；外部代码仅登记，不自动纳入子仓。
- 批次上限：10

## Summary

| Metric | Count |
|---|---:|
| articles | 313 |
| external_code_mentions | 99 |
| priority:P0 | 125 |
| priority:P1 | 21 |
| priority:P2 | 167 |
| risk:high | 99 |
| risk:low | 119 |
| risk:medium | 95 |

## Batch Distribution

| Batch | Count |
|---|---:|
| P0-context-memory-token | 22 |
| P0-skill-agent-sop | 103 |
| P1-multi-agent-review | 10 |
| P1-test-release-quality | 11 |
| P2-external-code-candidates | 48 |
| P2-reference-only | 119 |

## Next Batch Candidates

| id | category | priority | batch | candidate | risk | title | path |
|---|---|---|---|---|---|---|---|

## Absorption Gate

- 每篇文章先生成候选摘要，不复制原文到 adk 核心资产。
- 已有等价能力时只允许增强现有 skill/workflow/script，不新增平行资产。
- 含 GitHub/源码/安装命令的条目先进入供应链审查，默认不新增子仓。
- 每批完成后运行 `rtk scripts/check-all.sh --quick` 与相关 `agent-dev-kit` 门禁。
