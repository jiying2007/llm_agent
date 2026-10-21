# 设计

在返回报告前统一执行 `_bounded_report`，覆盖正常收尾及来源无效的早返。预算是 `_json(report)` 的 UTF-8 字节数加一个末尾换行，不使用字符数或 pretty JSON 大小。

超过 4 MiB 时保留原失败路径并追加 `aggregate-report-byte-budget-exceeded`，清除原始 `result`；两份来源快照保留 `git`、`scope`、`sha256`，用 `inputs_omitted=true`、`input_count`、`input_file_bytes` 代替逐项 `inputs`。`sha256` 和顶层 `input_digest` 始终指省略前完整 `git + inputs` 身份；`input_file_bytes` 是原已读文件的 bytes 合计，缺失项只计入条目数。摘要不再含 `inputs` 空对象，以免被误读为没有输入。

若剩余诊断仍超限，显式省略命令参数、剩余证据说明和下一步文本，保留六项 ID、状态、实际退出码、已有输出摘要及错误字段。最终再次核对实际编码长度；无法容纳最小结构的内部预算导致明确异常，不输出部分 JSON。正常报告不增加省略标记。

不重读输入、不重算审核结论、不运行模型、不修改既有原始证据。`source_consistent` 记录压缩前实际比较结果；扫描错误仍使所有资格汇总为 false。当前 workflow 不读取逐输入清单，错误报告保持 v2 的必需摘要字段。

协调与实现：`ai/root`；独立 Quality：`ai/root/followup_quality_audit`；独立 Spec：`ai/root/fresh_qualification_audit`。发现者独立于源码作者。回滚仅撤销本聚合器、定向测试和说明修改，不涉及 ADK 或现场资料。
