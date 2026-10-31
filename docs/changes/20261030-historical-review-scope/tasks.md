# 独立表达历史审核完成范围：任务

状态：VERIFYING。实现与定向验证完成；真实独立审核、受保护 CI 与合并仍待完成。

- [x] 实现上述既有入口的最小变更。
- [x] 从验收条件补充确定性临时目录/fixture 回归。
- [x] 运行定向验证，保存原始输出并检查差异。
- [ ] 运行适用完整回归和受保护 CI。
- [ ] 取得真实独立 Spec/Quality 审核后，正常合并并核验 main。

环境：当前工作区不含用户的 ~/codex Knowledge Provider/Execution Policy，相关运行时记录为 NEEDS_REVIEW；不冒充 Dot 运行记录，不创建运行时策略或知识收据。

验证记录（2026-10-30，Python 3.12）：qualification-followup 的 106 项测试通过；完成历史证明后不再产生重复待办，归档缺失/来源变化/旧版校验失败仍拒绝，未知 scope 不能豁免当前阻断。README 同步增加使用资产、判断可用、发布升级三条既有入口。

完整回归的本地环境差异均保留原始失败：受限 PID namespace 无法读取夹具父进程的 `/proc/<pid>/stat`，同一未修改测试在正常进程视图下通过；root 的 DAC 绕过能力使 chmod 555 无法制造预期写入失败，移除该能力后同一未修改注册恢复测试通过。未修改测试或生产权限策略来掩盖环境差异。

79 组 Root 回归均已取得通过结果：正常进程视图的全量运行先通过 53 组；权限测试单独复验通过，随后续跑余下 25 组通过。这是分次验证记录，不标成单次全量 PASS。锁定 ADK 8.1.3 的 quick suite 为 59/59 PASS。`git diff --check` 通过。

真实归档只读复验：原 v8.0.36 三份历史归档全部验证通过，#201 为 `historical-fulfilled` 且没有 remaining_evidence/next_actions；整份扫描 complete、来源前后一致、errors 为空。当前 source review 保持 false，native/effect/longitudinal 仍 blocked，#236 conditional，产品授权 false。

`check-all.sh --quick --working-tree` 初次为 43/52。补齐当前进程 PATH 并移除 root 的 DAC 绕过能力后，Harness loop、reference source integrity 和 practice intake 已单独复验通过。其余失败涉及本机缺少 Cosign、活动 `~/codex` 不存在、既有 reference dirty baseline 过期，以及历史 Software M5 候选与当前 promotion 身份不匹配；未修改历史政策、延期 baseline 或伪造 runtime 来换取通过。公开 CI 和独立审核仍须分别完成。

负面查证：本工作区未找到 `knowledge/L2-domain/lessons.md`；没有可复用的已登记独立审核自动任务。未调用 Codex/Work、付费模型或额外代理。Native/effect/longitudinal 的真实证据缺口及 `release_authorized=false` 保持原判据。
