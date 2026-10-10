# 执行检查点

- primary_skill: adk-planning-execution-loop
- goal: 五类 M5 消费边界修复与源码闭环
- work_item_kind: implementation
- owner: 当前实现 Agent；独立 reviewer 只读
- handoff_target: 源码审查与验证结果，不是产品发布
- retention: 本 change 保存脱敏设计和结果；raw 验证输出在临时目录
- heartbeat: 阶段转换和每 60 秒有信息增量时更新会话进度
- completion_claim: 重审发现的源码问题已修复，定向/完整回归、独立复审与离线构建闭环；Runtime final 单独检查，产品资格 blocked
- required_evidence: 定向负例、根仓回归、门禁分类、独立 whole-diff review、线程 final gate
- verifier: fresh independent reviewer Spec PASS / Quality PASS，2026-10-10 根仓 74/74、ADK 56/56、hardening 19/19、runtime command 9/9、真实 pinned ADK 假运行器调用链 PASS
- open_items: 0（本轮两项已确认 P1）；Runtime final 与真实 M5 资格输入单列

## Replan：2026-10-10 执行边界修复

- status: complete-source-validation
- scope: 根仓 collector、共享消费契约、测试和本 change 文档。
- acceptance: Bash 启动环境不执行；选定可执行文件真正被调用，执行前后摘要一致；旧报告导入标为 unverified-import 并拒绝作为 M5 资格证据。
- risk: 保持原启动器路径以保留相对资源；摘要复核不宣称文件系统原子执行或动态依赖全闭包。
- excluded: 不修改 ADK、历史证据、live runtime，不调用真实模型、不提交或推送；未核验 Git filter 路径不列为已确认缺陷。
- retry_budget: 每类验证最多重试 2 次；源码变化后原验证失效。
- verification: 根仓 74/74、ADK 56/56、聚合 50/52 且剩余两项原资格阻塞；独立 Spec/Quality PASS；离线 wheel 的 54 个 Python 文件逐字节匹配。
- runtime_goal: task-c3d899451781e5fab0d09ac0，线程绑定真实当前请求；final gate 在交付前独立执行，不授予 M5 资格。

## Phase 1：边界与回归基线

- status: complete
- done_criteria: 真实请求登记、5 类负例固定、共享契约设计可审查

## Phase 2：实现与定向验证

- status: complete
- done_criteria: 生产入口复用加固校验，合法 fixture 和负例通过，无真实资格修改

## Phase 3：验证与审查闭环

- status: complete
- done_criteria: 整批验证、独立 whole-diff review、问题修复与复验、实际 final gate

## Replan：第二轮新发现

- trigger: 初审和 fresh whole-diff 两轮都有新的 major finding class
- decision: 保持五类修复目标；明确新增 hosted consumer 参数迁移与 collector 单次读取快照验收
- required_evidence: CI 的 CERTIFIED 分支显式 owner trust 配置和 ADK 初始化、输入内容与摘要同源负例、最终 whole-diff 复审
- preserved_boundary: 不修改历史资格，不触发外部 CI，不写 live runtime，不提交或推送

## 整批门禁反馈

- frozen regression: 73/74；唯一 workflow-action-compatibility 将本仓 CLI 的 `--trusted-root` 误判为 workflow 内 Cosign 命令。
- remediation: 限定到真实 Cosign logical command；共享 verifier 按本仓固定 Cosign 3.1.3 契约显式使用 `--new-bundle-format`，保持 legacy promotion 命令独立。
- required_evidence: workflow compatibility、共享 verifier 参数与全部 M5 消费链定向复验；追加独立 review。

## Replan：重新审查后的修复

- request: 重新审查；继续推进落地闭环。
- confirmed_findings: P1 canonical task/manifest 的工作树内容没有绑定 pinned blob；P1 hosted CERTIFIED 浅克隆缺少 signed source baseline。
- status: complete-source-validation
- scope: 根仓 collector/shared runtime/core 的源码身份检查、software-m5 checkout、确定性测试与本 change 文档。
- acceptance: assume-unchanged/skip-worktree 不得隐藏 ADK 或 root 源码；消费的 manifest/task 快照必须匹配 HEAD blob；hosted checkout 必须包含历史 baseline，合法历史比较仍成功。
- verification: 定向正负例、根仓完整回归、聚合门禁分类、fresh independent whole-diff review、离线 wheel 与 final gate。
- excluded: 不改 ADK 源码、历史资格、live runtime，不提交、推送或触发外部 CI。
- verification_fix: consumer-chain/reference-pins 的全工作区 cp fixture 复制无关参考仓、嵌套 .git 和 worktree，实际触发 ENOSPC；改用已有 owned snapshot helper 的 root-only 模式，保留根仓 index/gitlink 身份和篡改负例。
- final_validation: frozen snapshot e2a88c6367aaf9412417a2469ea8e4d536a18a33835a259e3fb48d5b9d76120d，根仓 74/74、ADK 56/56、聚合 50/52 且 fingerprint 稳定。两项既有外部资格阻塞不改写。
