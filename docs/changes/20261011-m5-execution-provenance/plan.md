# M5 执行来源、Gitlink 身份与联网门禁修复

- goal_statement: 修复 2026-10-11 作者侧审查的三项反例；真实资格仍按证据验收。
- primary_skill: adk-planning-execution-loop；supporting: adk-interface-contract-design、adk-code-review-loop、adk-verification-before-completion。
- work_item_kind: implementation；implementation_permission: 用户“按建议全部优化落地闭环”。
- scope_write: Root runtime 消费/采集/签名、field 消费、受控 runtime workflow、反例测试与本目录；共享契约串行。
- excluded: 原 main dirty、ADK/Codex 子仓、live、历史资格与 scorecard、真实模型调用、现场设备、SCM 发布。
- base: 134d124ad2973f621f920f68eb14f4d0cbdbce65；复用本会话清洁交付 worktree，保留原 main 与 index。
- dirty_worktree_decision: 原 main 保留；隔离工作树在本轮前 clean；本轮修改不复制回 main。
- phase_1: verified；签名执行回执、生产者与拒绝语义已冻结，runbook 已回读。
- phase_2: verified-local；三项修复、真实 Git fixture 反例、隐藏 index 补强、合成 rollover 事务通过。
- phase_3: verified-local；根仓 74/74、ADK quick 56/56、独立复审 Spec/Quality PASS、quick 49/52 且 fingerprint 稳定；归档与 Runtime final 独立记录。
- required_evidence: unsigned/伪造报告拒绝、签名身份/摘要/源码绑定、managed gitlink 实体/仓库/commit 负例、无联网授权零执行、完整回归、原工作区指纹稳定。
- claimant: 主代理；verifier: 实际反例与回归；作者侧复审不冒充独立人类 owner 审查。
- retry_budget: 同类失败最多两次；无新增条件不调用模型。
- staleness_threshold: 代码变更后定向；最终冻结后完整回归一次。
- stop_condition: 本地修复 verified；缺真实签名执行/当前 field/owner 时 qualification-blocked。
- completion_claim: producer clean-source Major 的本地修复、正常流程测试、完整回归与独立复审 verified-local；本地实现 open_items 0。真实签名 runtime、当前 human field/owner 与同基线 qualification 仍独立阻断，不属于本地代码完成声明。
- heartbeat: 本轮里程碑更新本计划；automation: disabled；worktree_closeout: 保留，不自动提交推送合并。
- handoff_target: 当前实际线程；exit_gate: 实际修复证据与 Runtime 本地 final gate 分开报告。
- plan_completeness: 三阶段及其验收已定义；attestation_readback: 修改后回读。
- review_round: 3；review_mode: whole-increment；independence: 复用既有只读 reviewer；修复及最终 fixture 复验后 Spec/Quality PASS，独立 55/55；此前 round 2 NEEDS_FIX 保留为负结果。
- feedback: managed clean checkout 不得相信 porcelain，已拒 assume-unchanged/skip-worktree；两种隐藏修改反例通过。
- negative_evidence: 首次 aggregate 期间补强源码导致 fingerprint 失败，不能作为最终稳定快照通过；冻结后复跑。
- budget: 沿用用户此前提高预算授权，当前 Runtime task 调整为 20000000；累计计量与 baseline 保持不变。
- followup_goal: 允许 status 成功的空输出，保留身份查询非空约束、Git 错误拒绝和 dirty/hidden-index 拒绝；新增实际 clean/dirty Git fixture 与 collect → payload → envelope 的离线正常流程。
- followup_permission: 用户“按建议全部优化落地闭环”；scope 仍限隔离 Root 源码、测试、验证与 reviewing 归档；SCM/live/真实模型和 field 不在本轮操作范围。
- followup_exit: 定向及共享逻辑回归 PASS、原工作区保护、fresh whole-increment 独立复审关闭该 Major、完成前门禁与证据回读。
- followup_contract_change_decision: none；属于既有 clean-source 契约实现修复；retry_budget 2，逻辑任务持续推进，源码冻结后复验。
- validation_resource_matrix: root full 使用独立 mktemp/临时 Root fixture；ADK quick 只读 ADK 源与独立临时输出；定向 unittest 各自 TemporaryDirectory，无共享输出；aggregate 串行到所有回归与源码编辑结束后执行，避免 fingerprint 漂移。
- followup_negative_evidence: 首次 root full 在新增错误 Git 路径负例失败；TMPDIR 位于原仓内，Git 向上发现父仓，临时目录不等于无 Git 仓库。改用不存在的 checkout 路径后，同一 TMPDIR 16/16 PASS；生产源码未变，root full 重跑一次，保留首轮负结果。
- followup_verified: producer Major 已关闭；主代理 85/85、独立 55/55、ADK quick 56/56、最终 root full 74/74 PASS；冻结 aggregate 49/52，fingerprint 稳定，三项环境/资格负结果保持。归档和 Runtime final 由实际 Provider/Policy 回执独立验收，不推出 domain PASS。
- followup_stop_condition: split；本地实现与验证完成，保留隔离 worktree；现实 workflow 发布/受治理 runner/真实模型与签名 runtime/current field/owner 移交各自授权和验收线。

## 新鲜全量审查后的源码完整性修复

- goal_statement: 关闭 fsmonitor 隐藏执行脚本、继承 Git 环境导致 clean-source 查询错仓两项 Major；此前 PASS 只对应旧快照。
- implementation_permission: 用户再次要求“按建议全部优化落地闭环”；共享 Git 边界串行修改，仅隔离 Root 仓。
- phase_1: verified；两项已由真实临时 Git 仓复现，后者仅证实预检错仓，不宣称签发绕过。
- phase_2: verified-local；统一 source Git 命令和实际字节绑定落地；两 Major 及父仓递归 child-filter 同类漏项关闭；主代理/独立90项全过。
- phase_3: verified-local；主代理/独立90/90、ADK quick56/56、Root full74/74；冻结 quick49/52且fingerprint稳定，三项环境/资格负结果保持。Provider reviewing 和 Runtime final 由实际回执独立收口。
- required_evidence: 原 fsmonitor 反例拒绝、同 HEAD 另类 clean 仓不得遮蔽 dirty root、filters 不执行、同 stat 源字节篡改拒绝、正常 producer flow 保持通过。
- retry_budget: 同类失败最多2次；staleness_threshold: 源码变更后定向，最终冻结后完整验证。
- contract_change_decision: none；保持既有“锁定源码且 clean”的契约，修复校验实现。
- stop_condition: verified-local 或有证据的 blocked/split；model/field/owner 资格缺项独立阻断。
- budget: 沿用会话提高预算授权 20000000；上一轮 review 已凭实际审查结果收口，本轮另行绑定 implementation intake。
- completion_claim: 本次Git源码完整性实现、反例回归与独立复审完成，open_items=0限本地实现；真实签名runtime/current field/owner及历史声明仍qualification-blocked。
- final_review: independent whole-diff Spec PASS / Quality PASS；同一Git配置边界的递归child-filter扩展反例已闭环，未出现新confirmed finding class；功能源码冻结后仅补记录文档。
