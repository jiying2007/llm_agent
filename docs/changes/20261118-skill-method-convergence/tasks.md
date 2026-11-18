# 两仓 Skill 方法沉淀：任务与证据

1. 完成四个既有入口的收敛，保留真实差异供独立 Spec/Quality 审查。
2. 在受保护 PR 运行原 required CI、文档同步、预算和治理检查；仅以实际 workflow 回执认定验证通过。
3. ADK 完成本候选发行后，另以 source-only transaction 更新 gitlink 与生成的 `reports/current-status.md`；消费 CI 核对 tag、checksum、digest、签名和 exact source。
4. main 验证与消费通过后，交付原始 PR/release/Actions 入口；真实模型、Token/费用、原生宿主和现场效果保持未测。

当前编辑环境无真实 `rtk` 且非完整 checkout，未运行本地项目测试或生产部署。原 knowledge-provider / Execution Policy 宿主入口在此环境不可用；本次耐久方法通过受保护仓库规范和独立审查提交，不伪造 Provider candidate、policy receipt 或宿主验收。恢复真实宿主工作时仍须沿原 Provider 与 Execution Policy gate。

验证原件保留在关联 PR 与 Actions，避免另建结果状态台账。Root 文档改动、ADK 发行、Root 消费分别有自己的提交和验证身份。
