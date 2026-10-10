# 当前候选真实资格推进

- request: 按建议全部推进，默认模型改为 GPT-6.1-Sol medium。
- primary_skill: adk-planning-execution-loop；supporting: OpenAI Docs、独立代码审查。
- scope: 根仓采集器及消费者默认模型、确定性测试、有界真实 Codex smoke、真实 promotion 签名验证和资格缺项审计。
- authorization: 允许当前候选有界真实模型采集，替代此前对此采集的禁止；不授权 commit/push/merge、外部 CI 触发或 live 配置修改。
- model: gpt-6.1-sol；reasoning_effort: medium；每次最多一个任务结果，真实采集最多两次，不静默换模型。
- phase_1: complete；默认模型一致，显式 reasoning override，临时运行忽略用户配置以隔离 MCP/插件/hook；保留登录认证与本机配置文件。
- phase_2: executed / qualification-blocked；两次预算已用完，首次未进模型，第二次真实任务通过但 reported_models 为空；缺 observed model，不生成有效证据。
- phase_3: audited；官方固定版本 Cosign 已经 TUF + OpenSSL 自举验证，真实 promotion 实体验签通过；独立 field 最低策略通过，根仓签名 CI 及当前候选资格仍缺项。
- phase_4: verified；定向 37/37、root 74/74、ADK quick 56/56、离线 wheel 与独立复审通过；稳定聚合 51/52，唯一失败为真实 M5 资格/历史声明缺项；Provider 仅 PLANNED，final gate 单独登记。
- rollout_precondition: 根仓 clean source 和同基线的受信签名 CI receipt；当前 dirty，不绕过门禁或重标历史资格。
- risk: 当前 /tmp 空间约 77 MB；生成物及临时缓存使用工作区 .cache 下隔离目录，不清理用户数据。
- retry_budget: 每类确定性失败最多两次；真实采集最多两次；未知外部写入结果先对账。
- staleness_threshold: 生产源码修改后重新验证并绑定快照。
- stop_condition: 软件与采集结果有新鲜证据；无法自动生成的 CI/field 证据明确 blocked，不声明认证通过。
- completion_claim: 本轮授权范围内实现、取证与复验已完成；当前候选 M5 资格未关闭，software_m5_certified=false / release_authorized=false。
- open_items: 0 个本轮本地实施项；外部资格仍缺受信实际模型身份、同基线签名 CI 与有效当前声明；verifier: fresh independent review 与实际门禁回执。
