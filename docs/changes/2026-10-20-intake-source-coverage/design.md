# Intake 原始来源覆盖：设计

## 实现

变更保留在 `tools/codex_assets/intake_pipeline.py` 现有快照分析责任边界中，不新增生产模块或依赖。来源解析、pin 校验、报告路径约束和人工 decision/task-pack 保持原有流程。

1. 对批准 commit 生成 archive 并安全顺序解包，继续拒绝逃逸路径和特殊成员，不创建链接。
2. 将同一 commit 的 `git ls-tree -r -z --full-tree` 输出写入有字节预算的临时文件，按 NUL 分隔流式读取原始叶子清单。模式、对象类型、完整 OID、路径和重复条目都须有效；tab/newline 保留为文件名内容。
3. 流式计算解包普通文件的 Git blob 对象 ID，覆盖 Git blob 头与原始文件字节，再与清单中的 OID 比较。使用 SHA-1 或 SHA-256，无逐文件 Git 调用。tree 中遗漏、转换、符号链接和 gitlink 计入覆盖缺口；多余解包普通文件直接拒绝。
4. 转换路径传入现有文本扫描器，记录 `archive-transformed` 而不读取其内容进行分析。普通文本扫描只在已匹配源 blob 的字节上产生内容证据。

`archive_bytes` 分别限制 archive 输出、解包字节、tree 清单输出与对账读取；`archive_members` 分别限制 archive 成员与 tree 叶子条目。单条 tree 元数据限制为 64 KiB。archive、解包、清单和哈希共享 `command_seconds` deadline，读取按 64 KiB 分块检查；文本分析保留独立预算。

## 覆盖契约

analysis/result 继续使用 v2，并添加以下可加性字段：

- `source.snapshot_coverage.scope=git-tree-leaf-entries`、`identity_check=git-blob-object-id`，配套 `status`、`total_entries`、`by_status`。
- `gap_path_examples` 每种缺口最多 20 个路径；`gap_examples_truncated` 表示是否存在未展示条目。
- `coverage.scope=extracted-archive-files`，明确原有 `total_files` 仍只统计解包普通文件。

状态的完整定义见 [reference intake runbook](../../runbooks/reference-intake.md)。`matched-blob` 只证明对象字节身份，并不声称该文件已完成文本分析。顶层 `static-complete` 同时要求来源覆盖完整、全部解包文件已分析、无无效 frontmatter 和跳过链接。`update_pipeline` 复用现有 `analysis_status` 汇总，无需新增汇总分支。

转换的 Skill 记录 `frontmatter_status=not-read`，`sha256=null`、`lines=null` 和空 description；文件名及目录结构仍是结构观察。decision-candidate 始终 `review-required`、`auto_apply=false`，任何覆盖状态均不提供采纳授权或真实效果证明。

## 空 archive 的窄兼容

Python tarfile 会拒绝仅含 Git commit 全局 PAX 头的空 archive。实现先用标准 `TarInfo.frombuf` 校验首头；只有其为全局 PAX 且 payload 恰好等于该固定 commit 的 Git comment 记录时才跳过该 provenance 头。剩余内容仍由 tarfile 的顺序模式从相对 offset 0 解析，避免把损坏或截断的首成员当作归档结束。

这不是对 `ReadError` 的宽泛忽略。错误 commit、损坏头校验和截断后续首头都有拒绝回归；空 archive 仍继续原始 tree 对账。

## 迁移与回滚

不批量改写历史 v2 报告。缺少 `source.snapshot_coverage` 的旧结果没有本次原始 tree/blob 对账证明，需要重新分析后再形成覆盖结论。此前因 archive 属性得到完整结论的源可能改报 `static-partial`，应先人工解释缺口。

如需回滚，整体撤回实现、行为测试和本次文档；不能移除 pin、路径、预算或人工采纳保护。回滚会恢复 archive 属性造成的来源覆盖缺口，不能把恢复后的旧结果当作原始 tree 已完整分析。
