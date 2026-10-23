# 来源到实际实现与验收

本映射按 Owner 的明确吸收指令建立。十二项来源的原始 URL、固定 revision、未知许可证和静态依赖审查保存在 sources.json；collector 只生成 review-required candidate，独立 decision 保存在 decisions.jsonl。第三方内容没有复制到生产资产。

## 方法映射

| 来源 | 决策 | 既有 owner 与实际落点 | 验收依据 | 保留的限制 |
|---|---|---|---|---|
| EXT-01 OpenAI Skill evals | ENHANCE | evidence-driven-optimization 第 1/4 节；现有 ADK effect/repository campaign | 三组缺陷均保留原失败、修复结果和正常控制；执行完成与实际效果分开 | 未重新全量认证 Skill；没有真实模型收益测量 |
| EXT-02 OpenAI deprecations | OBSERVE | runbook 第 6 节；sources.json dependency_audit | 指定执行面静态搜索没有发现活跃调用，原匹配逐项分类 | 仅在已读两仓范围成立；不是生产外部配置的全面证明 |
| EXT-03 Anthropic evals | ENHANCE | runbook 第 1/3/4 节；现有 G21/G22/M5 证据合同 | 使用真实可观察文件、退出、进程和产物结果；保留失败分母 | fixture pass 不提高 Native、效果或产品资格 |
| EXT-04 Anthropic harness | ENHANCE | runbook 第 2/3 节；现有 validation-plan | 有风险的共享边界全回归；小范围审查反馈只做必要回归再整合 | 本轮没有证明所有既有 harness 组件的净收益 |
| EXT-05 Addy Skill evals | ENHANCE | runbook 第 1/3 节；既有 matcher 与 effect 流程 | 明确结构、词法路由、运行成功和效果的不同解释 | 没有新增 catalog、runner 或付费 CI |
| EXT-06 Matt Codebase Design | ENHANCE | ADK atomic_io/release_contract；Root process_budget | Native 重复输出写入收敛到既有 atomic_io；Gate 复用 bounded runner；publish 复用 canonical verifier | 模块行数和文件数量不充当收益分数 |
| EXT-07 Cursor benchmark | ENHANCE | runbook 第 4 节；现有 effect-trial 比较 | 缓存反例证实 HEAD 不足以代表全部输入；九项生产缓存禁用 | 没有把快速失败、no-op 或局部时长包装成效率改善 |
| EXT-08 Cursor idempotence | ENHANCE | ADK compiler/native_campaign/atomic_io；现有 release/promotion | 全输出预检、staging、补偿和保留恢复材料的确定性回归；远端写入前后按精确标识读回 | 单文件替换及多文件补偿不等于任意中断点的跨系统事务 |
| EXT-09 OpenAI safety | ENHANCE | runbook 第 6 节；既有 policy/receipt/发布门禁 | metadata、decision、review、真实执行和发布权威分离 | 不复制已退役平台，也不增加与用户授权冲突的确认流程 |
| EXT-10 LangGraph | OBSERVE | runbook 第 5 节；现有恢复 owner | 明确 checkpoint、重放、观察到的失败补偿和崩溃窗口 | 没有引入 LangGraph；没有 exactly-once 声明 |
| EXT-11 GitHub immutable release | ENHANCE | ADK release_artifacts/archive_io/release_contract；Root adk_promotion | 固定 Git 来源、完整 source 摘要、同字节三资产验证；真实远端闭环另由发布记录证明 | local pass 不能代替签名、immutable 状态或产品资格 |
| EXT-12 GitHub lockfiles | OBSERVE | runbook 第 6 节；既有 SHA-pinned workflow | 保留 Enterprise Cloud/公开预览/零新增费用边界 | 未采用不构成缺陷；没有升级计划或第二套依赖权威 |

## 审查缺陷与代码变更追溯

| 缺陷 | 代码 owner | 需求与可复验依据 |
|---|---|---|
| ADK-01 ignored 或 index 隐藏漂移污染合格构建 | distribution/release_artifacts | agent-dev-kit/docs/changes/20261023-release-contract；固定 tree/blob、Git attributes、replace refs 和 mode 回归 |
| ADK-02 公开 publish 与正式发布合同不一致 | release / distribution/release_contract | 同变更；改名版本拒绝、三资产集合、上传字节快照和 dry-run 反例 |
| ADK-03 tar 内 source 漂移未完整核验 | distribution/archive_io | 同变更；source count/digest/embedded manifest、重复和异常成员、有界读取 |
| ADK-04 Native 多输出互相覆盖 | native_campaign_contract / atomic_io | agent-dev-kit/docs/changes/20261023-output-boundaries；相同路径、硬链接、输入输出别名、父子重叠 |
| ADK-05 Native 晚发失败与非普通文件 | native_campaign / atomic_io | 同变更；执行前预检、编码/staging 失败不触碰目标、后项失败恢复、恢复失败保留备份 |
| ADK-06 export 同根链接清理错误目录 | compiler / installation_contract | 同变更；原始路径和 inode 检查、writer lock、同根及根外 no-clobber 反例 |
| ROOT-R1 Git 路径错误与无效比较 | control_plane/impact | docs/changes/20261023-gate-correctness；NUL/UTF-8/rename/raw path 和公共 CLI 空 base 回归 |
| ROOT-R2 后代进程晚写与无界输出 | control_plane/gate_runner / process_budget | 同变更；真实进程组 timeout、stdout/stderr 预算及正常退出控制 |
| ROOT-R3 不完整输入缓存旧 PASS | control_plane/gate_runner / manifests/gates.json | 同变更；实际 production 图同 HEAD 暂存区变化反例，纯 fixture 缓存保留 |
| METHODS-REVIEW-01 GitHub 文件来源归属错误 | codex_assets/practice_intake | 本变更；通过 collector 修复后重生 ledger，保持完整 URL、revision、candidate/decision 关联 |

路径为仓库相对路径；ADK 新增 change 的可达性随精确组件接入完成，不能用 Root 原 pin 推断已获得新修复。ADK 的可追溯实现候选为 c06fd629fa9a08f3079e7a606f45e65fcccbfc28；完整回归、受保护 CI、实际 Release 和 Root 接入需分别核验。

## 关闭条件

采纳表的 done 只代表方法/观察决定与实际落点确定。代码问题须具有独立 Spec/Quality 审查和新鲜回归，组件交付须有受保护 PR、精确主线 CI、immutable 三资产和 Root pin 的读回。缺真实 Native receipts、G22 trials、LTA field events 或当前 Product M5 authority 时继续由原检查器返回 blocked/conditional；本映射不生成它们。

本轮没有实际调用收费模型，也没有新增外部评估框架。现有 Native executor 的 asyncio transport 清理告警已在输出变更中保留为独立未关闭事项，不能用输出写入修复覆盖该观察。
