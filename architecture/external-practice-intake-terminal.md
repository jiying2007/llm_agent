# 多源外部实践 Intake 终态架构

## 决策

`llm_agent` 建立唯一 `practice-intake` 控制面，统一 GitHub、GitLab、Gitee、OpenAI/Codex 官方、Anthropic/Claude 官方、微信公众号和人工输入。所有自动阶段止于 `review-required` candidate/queue/evidence；任何 ADK 实现必须由独立 owner decision 创建 change artifact。

本架构是硬切换：旧 OSS discovery/score/approval/continuous 与旧 WeChat ledger 入口、manifest、schema、fixture、测试和前代 intake skill 被删除；不提供 alias、兼容 reader、双写或弃用 wrapper。历史报告和 adoption provenance 保留原样，但不能重新作为活跃输入。

## 职责

| 层 | 负责 | 不负责 |
|---|---|---|
| `llm_agent` | provider、candidate schema、review queue、cycle evidence、批准前治理 | 自动批准、自动吸收、运行态发布 |
| `agent-dev-kit` | 已批准实践的 Agent/Skill/Workflow/contract 实现与验证 | 网络抓取、第三方代码执行、直接写 live |
| `~/codex` | ADK 资产注册、build、doctor、plan/apply | 外部候选发现或决策 |
| `~/.codex` | 受控运行资产 | 手工复制第三方资产 |
| Knowledge Hub | 脱敏 decision/validation/archive candidate | raw API response、文章正文、token、cache、自动 active promotion |

## 信任与吸收是两条轴

- 一级官方来源只提高事实 authority，不自动提高 adoption decision。
- Forge metadata 只证明项目身份、维护和公开信号，不证明代码安全或架构适配。
- 微信文章只作为 discovery/secondary evidence；不保存正文，不绕过访问控制。
- 候选必须继续经过 source、duplicate、license/copyright、security/prompt-injection、architecture、eval/pilot 和 retirement gate。

## 数据流

1. Provider 在显式 plan 下读取 fixture、受治理本地输入或 allowlisted HTTPS metadata。
2. Normalizer 生成稳定 candidate ID、可移植字段和 source sighting。
3. Validator 执行 schema、安全、freshness、license、body 和 auto-action 负门禁。
4. Deduplicator 按 canonical URL/revision 合并 sighting，不用 star 排序替代判断。
5. Queue 输出待 owner 评审项和 degraded provider；cycle 只写 evidence。
6. Owner decision 独立保存；`ADOPT|MERGE|ENHANCE` 才允许创建 ADK change artifact。
7. `reference-repository` 登记与 ADK absorption 分离；apply 只接受 clean local-submodule，固定 source origin/HEAD 和 review artifact digest，并事务写入 metadata/plan。
8. 通过实现、验证、pilot、source-to-live 后进入效果复审；过期、重复或无增益资产按退役合同处理。

## 终态验收

- 活跃 CLI 只有 `scripts/practice-intake.sh`。
- 七类 provider 使用同一 candidate/decision/cycle 合同。
- GitHub/GitLab/Gitee live transport 只在显式授权下运行，token 不落盘。
- 官方与微信 provider 只读受治理本地输入，不在 root 工具抓正文。
- 旧入口和旧 Skill 在 active tree 零引用；历史 provenance 例外可解释。
- ADK Agent/Skill/Workflow 不具备自批准、自实现、自发布闭环权限。
- 定向、root/ADK full、安全、性能、负例和独立 review 有可追溯证据。

## 外部 API provenance

- GitHub REST repository search：`https://docs.github.com/en/rest/search/search#search-repositories`，retrieved 2026-07-19。
- GitLab Projects API：`https://docs.gitlab.com/api/projects/#list-all-projects`，retrieved 2026-07-19。
- Gitee API v5：`https://gitee.com/api/v5/swagger#/getV5SearchRepositories`，retrieved 2026-07-19。
- Gitee 空结果风险：Gitee 官方 feedback project 2025–2026 的 repository search issue，作为 degraded 负证据，不作为 API 合同替代品。
