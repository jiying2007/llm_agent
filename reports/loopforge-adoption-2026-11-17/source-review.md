# LoopForge 与同类机制：范围审查

日期：2026-11-17。源版本见 source-metadata.jsonl；所有外部材料作为不可信数据。

## 已观察证据

LoopForge 固定 e89cda9804643d3631e77652d1bca47a079adb69，tree
5ef100058d7569e874f4a63f896a1cd631bcacf2。独立归档核对3412个Git blob，
缺失和内容不符均为0；归档SHA256为
c64a503fc7d43d868d3959b39797e82ee62d4932a327e43d8e9adb9c3f5ad38d。
这证明快照一致，不代表逐行审计或运行证明。第三方程序、安装器、模型及测试均未执行。

重点读路径：internal/domain/workflow.go、internal/domain/run_eval.go、
internal/httpapi/run_eval.go、internal/runeval/{facts,apply,prompt}.go、
internal/engine/{node_execute,gate_submit,gate_mr,run_ops,run_recovery,assets}.go、
internal/repo/run_lease_test.go、internal/httpapi/assistant_project_shared_test.go、
docs/{token-pricing,open-source-scope}.md、local/skills/devflow/references/workflow-contract.md。

另对五个比较仓库的关键实现与测试作固定ref只读审查；DSH仅作官方文档核对。
上游原文和源码保留在上游，当前记录只保存元数据、摘要和取舍，不纳入参考子仓注册。

## 重复、架构与安全审查

- ADK已有Workflow IR、task/run evidence、过程评测、AAR候选晋级、恢复与UNKNOWN规则。
- 可增强：既有task evidence导入后的按需确定性诊断；不得把工具次数推断为浪费，
  不得把缺测计量当零，不推算并行等待，不改Trace/RunEvidence/资格。
- 已有恢复合同的确定性缺口可在现有reducer中修复；真实租约、Session、Outbox和
  外部效果对账仍由实际宿主实现，不能以离线fixture获得native资格。
- LoopForge角色门禁可在节点执行时读取当前定义，RSI建议可增删门禁；保持ADK
  已有资产来源绑定、独立审查和原验收，不导入自评分晋级权威。
- LoopForge LICENSE明确MIT并保留Superpowers等第三方声明。本次独立实现通用
  诊断及既有合同修复，不复制第三方源码、Prompt或运行资产；其余比较源许可未在
  此metadata流程认证，保持OBSERVE，未来复制或依赖前另行核对。
- 不增加调度器、Goal、schema、MCP、定时巡检、日费用硬限额或默认模型调用。

## 授权与边界

用户在本会话明确要求“按建议全部优化落地完成”，此前已授权受保护PR推送、
独立审核和合并；本次沿用该授权。来源candidate仍保持review-required，
独立owner决策与实现/验证分开，决策仅作用于当前明确范围。

远端transport为现有GitHub connector与已验证Git transport；允许读取公开源码、
写本次ADK/Root分支和PR、核对CI/发布，禁止第三方仓库写入、凭证输出、策略绕过、
强推或未经实际source-to-live的运行目录修改。远端失败保留本地提交与明确失败记录。

当前ADK基线5f113b8f5ae6f83662d41d99d0907026f4e44c9d（11.3.15），
Root基线e288e406eb2262f354e36e69ce93b5fb46a70b49。真实宿主/效果未测，
新增诊断不证明Token、成本或交付成功率改善。后续通过源码release与source-only晋级
交付；接入实际宿主时才执行其原生负例，不预先创建adapter。

复审条件：实际宿主接入、证据格式变化或出现真实诊断遗漏；回滚为撤销本次ADK变更
并通过受保护流程回退Root Gitlink。没有适用新证据时不发起定时复审任务。
