# 当前候选 field 绑定修复计划

- goal_statement: 关闭历史 field 被当前候选诊断接受的身份缺口，继续保留真实模型、CI、owner 和声明的独立验收。
- primary_skill: adk-planning-execution-loop；supporting: adk-code-review-loop。
- replan_reason: 上轮 field PASS 只验证最低策略，ledger 与 hash-bound pilot-start 均绑定 5.0.0-rc.2 / 251edf2b，而当前 promotion 是 8.0.5 / ef538430；候选身份没有参与 field 消费校验。
- work_item_kind: implementation；implementation_permission: 用户继续推进及既有全部优化授权。
- scope_write: 根仓 field 消费端、当前诊断、定向测试和本轮文档；shared contract 串行修改。
- excluded: ADK 子仓、live、历史 policy/scorecard/field/qualification、参考 dirty 目录、凭据、提交推送和外部 CI。
- phase_1: verified；ledger candidate_version 与 hash-bound 独立 pilot-start 的 canonical ADK commit 同时绑定，版本重标与跨文件拼接均拒绝。
- phase_2: verified-local；68/68 定向、完整合成 rollover、独立最终快照复审及离线 wheel 通过；根仓 74/74、ADK quick 56/56 通过。
- phase_3: qualification-blocked；实体 cosign 验签通过，当前 runtime/field/qualification/historical_declaration 缺项；最终串行聚合和线程检查点以本轮回执为准。
- required_evidence: candidate ledger 与事件证据绑定、负例拒绝、定向/适用完整回归、独立审查、新鲜真实诊断。
- claimant: 主代理；verifier: 独立复审与实际工具回执；completion_claim: local-field-binding-verified / qualification-blocked；open_items: 模型、当前 CI/qualification、当前 field/owner、历史声明。
- retry_budget: 本轮不增加模型调用；只读本地证据与验签，每个失败假设最多两次定向重试；同类无增量失败不重试。
- staleness_threshold: 修改后定向测试；最终源码冻结后一次完整回归；共享输出串行。
- stop_condition: 本地缺陷 verified，真实证据缺项 blocked；不重标历史资格。
- exit_gate: 新鲜校验及证据适用边界；handoff_target: 当前实际线程；retention: 脱敏工程报告。
