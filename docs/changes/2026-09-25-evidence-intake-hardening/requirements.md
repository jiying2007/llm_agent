# 取证链路修复：需求

来源：[2026-09-25 双仓优化方案](../../../reports/optimization/2026-09-25/llm_agent-adk-optimization-plan.md)。本变更覆盖 R1/R2 和 R3 的结构计数与任务包部分，不声称完成 A1/A2 或真实运行时资格。

## 验收

1. 干净 Root 无 reference checkout 时，显式 cache 物化的 exact pin 可以直接分析；commit/tree/origin 必须一致，dirty worktree 不得污染快照。
2. 默认来源只能是批准 reference pin；managed dependency 必须显式选择并匹配 Root gitlink，无 fallback。
3. cache 与报告不得写入 Root 源仓、声明的 runtime source/live 或敏感目录；链接逃逸和特殊归档条目必须拒绝或明确跳过。
4. Rust/Go 进入文本与 prompt 代码信号扫描；YAML 多行和 CRLF 描述解析正确，拒绝危险标签、alias、重复键、超深 metadata。
5. 时间、stdout/stderr、归档生成及展开字节、成员数和文本读取均有预算。失败 JSON 与退出码一致。
6. 报告区分 analyzed/unsupported/oversized/decode-error 与 static-partial；文件计数不得伪装成有效性得分。
7. 不变更 ADK pin、用户 live 配置、R2 authority、LTA-04 field evidence。

## 风险

analysis/result schema v1 → v2 与来源选择为明确 hard-cut，Root package 0.1.0 → 0.2.0；保留历史报告原文，不重写、不提供旧 Root checkout fallback。PyYAML 由 pyproject 声明，CI 显式安装。
