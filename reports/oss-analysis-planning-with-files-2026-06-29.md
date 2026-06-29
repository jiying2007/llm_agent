# OSS Analysis: planning-with-files

- 日期：2026-06-29
- 本地路径：`planning-with-files`
- 来源：`https://github.com/OthmanAdi/planning-with-files.git`
- 本地 HEAD：`8f5a3c2e1c347635cf94debde033b3c1ac97e4ab`
- 分支：`master`
- 决策：observe / active-reference / git submodule reference

## 价值判断

`planning-with-files` 的核心价值是用项目内文件承载长任务状态：

- `task_plan.md` 保存目标、阶段、状态和决策；
- `findings.md` 保存研究发现；
- `progress.md` 保存执行日志和验证结果；
- active plan、plan attestation、PreCompact 和 Stop gate 支撑 context loss 后恢复。

这与 ADK 的 context compression、verification before completion、planning-execution-loop 有直接关系。

## 本地适配方式

仅 method-only 观察，不安装 hooks。吸收对象是文件化状态、恢复流程和 gate 条件设计，不是外部命令或全局 hook。

## 风险

- 默认写入多个计划文件会增加仓库噪音；
- hook 注入可能放大 prompt injection 或上下文污染；
- Stop gate 如果条件不严，会阻塞正常收口；
- 对小任务启用会浪费 token。
