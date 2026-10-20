# 设计

## 控制面复用

在 Root 现有 `llm-ctl` 增加 `qualification-followup` 诊断入口。复用既有 native/effect/longitudinal/M5/Harness 实现和原始变更状态；不建立新的认证规则、审批 schema 或第三方执行框架。

每项输出包含稳定任务标识、canonical issue、既有命令、实际退出码、客观状态、原结果及明确的后续输入。整体标识表示六项收集是否完成，资格字段始终明确没有授权。异常输入、超时和输出预算用有界、脱敏错误记录；一项异常不阻止其他项诊断。

## 自动执行

新的只读 GitHub Actions 工作流在相关 push/PR、每日定时和 `workflow_dispatch` 触发。PR 验证候选实现；主线和定时执行绑定当前受保护 main 及其 ADK gitlink。报告写入 runner 临时目录并上传 artifact，Actions 摘要列出六项状态与阻断。只用标准库和已有依赖，不调用模型、远程 runtime 或不可信材料中的命令。

## 安全与验证

命令向量由代码确定，复用 `process_budget.run_bounded`，不经过 shell。严格解析有界 JSON，保留退出码和输出来源。使用真实 UTC 采集时间，不使用 `--as-of` 产生当前资格。输入/输出文件类型与目录边界复用现有严格 IO。

共享 CLI、CI、回归入口和质量配置由主 Agent 串行整合；子 Agent 只在各自文件边界内工作。实际验证覆盖正负契约、只读不变性和完整回归；最终通过 required checks、受保护合并以及 fresh-main 复核。
