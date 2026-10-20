# Intake 原始来源覆盖：需求

## 目标与边界

修复 Root F6：固定提交的 `git archive` 会遵循 `export-ignore` / `export-subst`，此前仅扫描解包文件可能遗漏源文件或分析被替换的字节，却报告 `static-complete`。审查基线为 `f42395a37dced7e59867d0c46891ecd84c218585`。

继续使用批准的 reference pin 或 managed dependency gitlink。保留安全解包、路径和链接约束、既有资源预算及人工采纳边界；不执行来源代码，不自动安装、同步、物化子模块、修改采纳记录或写入 ADK。

## 验收

1. 使用同一固定 commit 的有界原始 Git tree 叶子清单，按 Git blob OID 对账普通文件字节，支持 SHA-1 / SHA-256，避免逐文件 Git 子进程。
2. `source.snapshot_coverage` 区分 `matched-blob`、`archive-omitted`、`archive-transformed`、`skipped-symlink`、`skipped-gitlink`；各计数之和等于原始条目总数，缺口示例有上限并标明截断。
3. `coverage.total_files` 保留解包普通文件数的原有含义。遗漏或转换导致 `static-partial`，包括原始 tree 非空但 archive 为空的情况；真实空 tree 保持完整覆盖。
4. 转换后的字节只用于对象身份对账，不进入内容分析，也不形成源 Skill 的 SHA-256、行数、description、Prompt 或 guardrail 内容证据。
5. archive 和原始清单都受成员/字节预算约束，快照阶段共享时限；超预算失败，无新报告。快照出现固定 tree 之外的普通文件时拒绝分析。
6. 有效的空 Git archive 可以读取；错误 commit PAX、损坏头校验或截断后续首头不能被当作合法空归档。
7. reference pin、dirty 工作树隔离、符号链接不跟随和人工 `review-required` 规则保持有效；更新流水线正确汇总新增来源缺口为 partial。
8. 定向行为回归和消费方端到端通过；完整 L3、受保护 PR 当前 head CI 和合并后 fresh-main 由实际执行结果提供。
