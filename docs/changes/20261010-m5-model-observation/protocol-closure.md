# 模型协议闭环恢复检查点

- goal_statement: 继续关闭真实模型协议缺口，保留当前候选资格的独立验收边界。
- primary_skill: adk-planning-execution-loop。
- scope: 根仓 observer/collector/验证；ADK exact pinned、live 配置及历史资格不改；不提交、推送或触发外部 CI。
- replan_reason: 上轮诊断不能区分内容类型与模型响应头拒绝；用户明确继续，恢复有界取证。
- phase_1: verified；第一取证定位 HTTP 200 后的 MIME gate，后两次解析到完整 SSE 完成事件。
- phase_2: verified；按实际 SSE 校验协议，支持受信服务器 metadata 别名与平坦字符串数组；显式响应 ID 全程一致，55/55 定向测试及独立复审通过。
- phase_3: blocked；本轮三次预算已用完，后两次 completed=true 但 observed_models=[]，没有有效 runtime evidence；软件验证与资格阻塞分别记录。
- required_evidence: 实际返回协议、有效任务完成、上游模型身份、usage、源码/runtime/任务摘要及复审；配置、HTTP 200 和合成测试均不能替代。
- claimant: 主代理；verifier: 独立 review 与实际工具回执；completion_claim: local-protocol-fixes-verified / qualification-blocked；open_items: 3。
- retry_budget: 初始两次预算已使用；第一定位 MIME gate，第二确认实际 SSE 完成但模型 header 缺失。按新失败阶段重审，允许一次最终 metadata 兼容复采，本次总上限三次，每次一个 canonical task；同类无增量失败不重试。
- contract_change_decision: 原生 parser 的 response.metadata / x-openai-model 与字符串数组属于服务端元数据；支持这些渠道，所有数组模型必须一致且精确匹配，仍拒绝 response.model/配置/模型文本。
- transport: 临时 127.0.0.1 relay，只向固定官方 HTTPS 转发原生 Codex 登录请求；内存转发认证、不读取认证文件、不保留 headers/body/stderr、不允许工具或任意 endpoint；缺观测 fail-closed，原路径可回退。
- staleness_threshold: 源码改变后定向验证；里程碑结束做必要整仓和稳定聚合；共享输出串行。
- stop_condition: pass / replan / blocked；不能自动制造 CI、field 或 owner 资格。
- work_item_kind: implementation；implementation_permission: 用户继续修复授权；exit_gate: 新鲜证据及真实资格边界；handoff_target: 当前线程检查点。
- excluded_context: 用户 reference dirty 目录、raw credential、旧声明重标、本机 live 和 SCM 外部写入。
