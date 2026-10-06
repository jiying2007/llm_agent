# llm_agent 与 ADK 全面审查和本轮源码迭代

审查日期2026-10-06。范围：安装事务、严格JSON、运行边界、维护CLI、端点信任和推广来源、消费者与评测证据边界。真实模型未调用；外部实践只作设计证据，没有增加默认framework/MCP/runtime依赖。

| 问题 | 已落地行为 | 验收边界 |
| --- | --- | --- |
| 安装plan/receipt普通JSON可接受重复键 | 既有strict decoder与安全regular descriptor；producer/readback同4MiB/64层预算，receipt先保守预检再实际复检 | 预算/竞争替换负例、正常安装与rollback；不宣称父目录身份或原子快照 |
| runtime-boundary吞rg错误 | rc1无命中合法、rc>1失败闭合，规则不变 | 模拟rg错误拒绝、正常扫描通过 |
| 维护报告apply1假成功及无界删除/chmod | `.cache`/`dist`有界元数据只读计划，维护--apply blocked/exit2；report written对应实际输出 | MAJOR8.0.0迁移，descriptor缺失平台blocked；不授予后续执行许可 |
| 根仓URL子串误信任 | 精确HTTPS authority/port和路径段边界、拒绝凭据/query/fragment/歧义，诊断脱敏 | 完整fixture HOME/doctor/CLI验证，没有连接真实provider/MCP |
| promotion claims宽松输入与来源失配 | 根仓strict JSON、精确整数、当前main-push workflow/source一致、重复lock拒绝 | 后续真实cosign约束不放宽，不把claims缺口称完整签名绕过 |

根仓信任边界已作为PR183合并main9b038f3，冻结full74/74、定向10/10与独立spec/quality通过。ADK实现PR176已合并main2c5bd3574c660c5d71bd7e71502977f8cadcf0ad，并实际发布immutable v8.0.0；mainCI37411676809九项及release37412113614成功，fixed workflow/issuer/root cosign VerifiedOK，实际归档9712f4e43898727264d528b0a7051ae1c4d6074d39f1f5d7cf0062e471dbf291与API/signed evidence/releasecontract一致。

ADK最终本地Python3.8.20/3.11.15/3.12.13各full98/98、routing30/30、wheel/audit全PASS；支持矩阵receipt79b2756139b3d645c4c95810fd3a084ea9840d8b2ba978de63f1a893ece616c5，source d5239b87d02456c61d59cde7522f9ead30e322525dc9d47bf310363597ed938c。独立复审真实发现并关闭producer预算Major，不重标旧取消矩阵。

Codex exact消费候选PR47使用该签名来源，42Skill/9Agent/四policy原文保持；更新身份、目录、fixture和consumer metadata。独立复审发现三个遗漏消费pins并闭环，最终57项spec/quality PASS，修复后3.8/3.11 full各342、来源audit42/42无gap/blocked、两个binding validator PASS及doctor三scope全0。实际merge/live必须以后续终态receipt确认，本报告不提前推导。

外部一手依据及吸收：

- [Anthropic长期任务harness](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) 与 [harness设计](https://www.anthropic.com/engineering/harness-design-long-running-apps)：增量交接、独立评价和压力测试；外部实验收益不外推为ADK收益。
- [OpenAI agent evals](https://developers.openai.com/api/docs/guides/agent-evals)：工作流/trace评价分层；当前只做工具/fixture，不执行收费模型评测。
- [SLSA1.2 artifact verification](https://slsa.dev/spec/v1.2/verifying-artifacts)：身份/来源/制品期望分开；不声明SLSA等级认证。
- [MCP安全实践](https://modelcontextprotocol.io/docs/2025-11-25/tutorials/security/security_best_practices) 与 [2025-11-25 Tasks](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks)：信任和生命周期设计参考；该版本Tasks为experimental，不引入默认runtime。

保留缺项：OpenSpec/superpowers/vibeflow的owner baseline2026-08-31过期，历史M5 5.0.0-rc.2证据不匹配新source、历史release-clean Codex gitlink未物化；不伪更新owner/date/certification，不恢复旧nested入口。模型成本/成功率、真实长期pilot与当前产品/owner资格需要独立真实证据，未由本轮源码PASS消除。当前generated status的release_authorized仍false，历史资格保留原identity。

源码/组件出版、消费者候选、实际source-to-live与产品资格分别验收。最终Root冻结回归/独立复审、托管SCM、用户dirty保护、实际同计划live结果和Provider reviewing候选在source外阶段交接记录，避免证据完成后改写source snapshot。保留原分支、fixtures、签名、user references及managed备份用于回滚。
