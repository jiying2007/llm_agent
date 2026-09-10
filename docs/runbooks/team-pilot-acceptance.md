# 团队上手与交付试点

目标：验证第二位操作者是否能够独立安装、完成任务、识别失败并恢复；复用 Runtime Bundle、setup、Effect Comparator 和 Software M5 账本，不增加另一套认证层。

状态：review-required 试点设计；尚未执行独立操作者试点。短期上手结果不能替代 [M5 认证计划](../software-m5-certification-plan.md) 的完整 campaign、两操作者及 30 天证据。

## 先冻结输入

| 输入 | 要求 |
|---|---|
| 源身份 | ADK clean commit/tree、bundle hash、Codex source/build/target、profile；由当前 policy 解析 |
| 操作者 | 至少两位真实 human operator，使用匿名稳定 ID；不能用两个 Agent 代替 |
| 仓库 | 至少两个真实仓，其中一个符合 policy 的独立仓定义；不得从 cwd 推断独立性 |
| 工作集 | 预先选择成功、失败、恢复、知识检索、发布准备各类任务；记录 accepted/rejected 及理由 |
| baseline | 固定 runtime/model/环境/任务；隔离额外 Skills、Hooks、MCP、plugins，否则标记 not-comparable |
| 预算与权限 | 模型运行、团队部署、外部网络/写入按既有显式授权执行；只读计划不授权付费 campaign |

## 六个验收场景

| ID | 操作 | 必须观测 | 失败结论 |
|---|---|---|---|
| T1 | 新操作者按团队包 README/setup 上手 | bundle identity、实际 managed profile、首次成功任务耗时、人工介入数 | 安装成功但运行资产不一致，标 setup-incomplete |
| T2 | 再次执行同一 setup | 输入不变时无额外漂移；本机非受管配置保留 | 反复覆盖/重复安装则 needs-fix |
| T3 | 完成小修复与共享逻辑变更各一个 | scope、验证层级、fresh receipt、真实测试结果 | 仅新增文档或 Host pass 不算任务完成 |
| T4 | 人为无效输入导致生成失败 | 旧可用包保持 hash 不变；明确非零返回与恢复办法 | 清空旧输出或伪装成功则拒绝推广 |
| T5 | 在隔离测试目标演练升级/恢复 | source/build/target identity、backup、恢复后的功能与 profile | 只复制旧目录但未复验不算回滚完成 |
| T6 | 检索一项旧决策并交接一个未完成任务 | item ID、当前适用性、下一动作；恢复时不重复副作用 | 旧状态覆盖当前事实或盲目重放则 needs-fix |

T4/T5 先在隔离目标演练，按真实观测标为 test；只有真实 field 发生且满足合同，才记录 field。不能重标 fixture 填补认证缺口。

## 记录一次，复用投影

- 工作结果进入现有 activity-session-receipt；长期可复用结论进入 Hub reviewing candidate。二者使用证据引用连接，不复制原始会话。
- 任务收益复用 ADK Run Evidence / Effect Comparator。记录成功率、一次通过率、人工介入、可信完成耗时、wrong-route、成本与 token。缺失指标为 not-measured；不能只保留成功样本。
- latency 必须区分 wall-clock、human-active、agent-active、并发峰值；warm CLI benchmark 不代表端到端收益。
- asset invocation receiver 当前不是自动采集服务；`agent-value-lifecycle.md` 要求的 authority/verifier 不存在时保留 not-measured，不以自签 hash 代替真实来源。
- 正式 field 事件使用现有 `software-m5.sh append`。不在本 runbook 保存 operator 身份、密钥、raw prompt、log 或客户内容。

## 分阶段推广

1. **本机候选**：修复和定向验证通过；根仓集成失败单列，不发布。
2. **小范围试点**：明确操作者与仓库后完成 T1–T6，保持 report-only；重点验证输入、手工步骤和恢复可操作性。
3. **效果比较**：在匹配 baseline 下比较真实任务结果；优化收益不足时逐项取消候选复杂度，保留安全与身份边界。
4. **正式推广**：满足现有 policy 的 campaign / 周期 / 独立 review 后，由 owner 裁决。没有第二操作者或未达到周期就保持 pending，不凭 elapsed days 或模板表格升级状态。

## 交付责任

- llm_agent：版本/证据一致性、候选与试点入口、效益分析。
- agent-dev-kit：asset contract、export/runtime bundle、确定性验证和 source 发布身份。
- Codex source owner：build → doctor → plan → dry-run → apply → check；不直接手改 live。
- 团队操作者/reviewer：实际操作、失败与恢复证据、可用性意见及正式签收。

回滚锚点以本次 source-to-live plan 的 backup/receipt 为准。任何 profile、bundle、模型或任务集变化都需要记录新条件，不能继续复用旧的效果比较。
