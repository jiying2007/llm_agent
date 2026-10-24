# 外部方法吸收与审查闭环

用户于 2026-10-23 在完整两仓审查后明确要求“全面吸收，全面优化，落地闭环”。本变更把审查已核实的 12 项来源落实为方法采纳、观察边界和现有模块的验证要求；用户是实际 Owner，既有委派审核继续有效。

## 验收

- 每个来源记录实际 URL、已知 revision、检索日期及未知许可证；candidate 保持 review-required，decision 独立记录，不能假称用户完成了技术试验。
- GitHub 文件级来源的 repository.full_name 必须是 owner/repository；完整文件 URL、固定 revision、candidate ID 与 decision 关联保持不变。实际独立审查发现的归属错误必须通过既有 collector 修复和重新生成消除。
- 可验证的方法对应到既有 owner、当前三组修复或已有 effect/campaign 能力，避免重复 runner、Skill 或编排框架。
- 形成可复用的行为验收、逐项简化、失败恢复、效率比较操作说明，明确成本、回滚和退出条件。
- 托管 Evals/Agent Builder 退役作为选型限制；没有活跃调用不新增迁移。workflow lockfile 在现有免费资源约束下观察。
- 实际修复、确定性回归与组件发布能够闭环；真实运行、G22、LTA、Product M5 继续使用原资格权威，不生成缺失证据。

本轮不新增付费资源，不重新全量认证既有 Skill，不复制或执行外部 Skill Pack。
