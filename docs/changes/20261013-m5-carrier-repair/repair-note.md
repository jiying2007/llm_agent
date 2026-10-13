# 模型身份 carrier 兼容与严格负诊断修复

failed_scope：真实 run 38355568555 返回 HTTP200、流完成、已接受模型 header 数量0；严格身份验收拒绝。历史摘要无法判断具体 carrier，不能事后升级成通过。

passing_scope_to_preserve：固定原生 Codex/源码/任务/信任根，真实失败制品导出和准确 runner 注销；全部旧证据、原 dirty、live 与凭据不修改。此次不新增模型或 GitHub 写入。

root_cause_status：兼容缺项已确认；该缺项是否触发历史失败仍未知。固定官方 Codex rust-v0.159.2 `codex-rs/codex-api/src/sse/responses.rs` 的 response_model 对 `response.headers` 和顶层 `headers` 做 fallback，不仅限于 metadata；其测试明确忽略 response.model。该文件 blob c01b13f1fe63d5065babac0d96cf1d74e4a4dbb4、SHA256 6c7b6e9d121c03658954b759d5febf71667f673a9647bcd41f674fa7ecd63f65。

复现：未修观察器接收生命周期事件顶层合法模型 header，随后完成事件，result 仍抛出身份缺证。修复前定向测试失败，修复后读取 lifecycle/metadata 的顶层 header；不读取 generated text/item header，继续要求 response ID、完成态和唯一精确预期模型，冲突比官方客户端 fallback 更严格地拒绝。HTTP X-OpenAI-Model 仍不用于验收，和固定原生客户端的 HTTP 分支保持一致。response.model 始终不用于资格。

诊断：仅增加固定布尔位，表示 HTTP 已支持 header、HTTP alias、SSE response header、SSE 顶层 header、不采信事件中的顶层 header、response.model 字段是否出现；固定 failure_kind 枚举区分未完成、缺 header、模型不匹配/冲突、native/transport 失败。不采信 carrier 只记录存在位，不提升模型身份。不存在自由 header 名称、值、正文、Token 或 raw SDK log。

版本：旧 raw diagnostics 继续产出 failure-summary/v1；带严格 identity_diagnostics 的新记录产出 v2。旧严格读取器会拒绝 v2，因此下次真实运行的负制品读取器必须显式升级，不能盲目复用旧临时 helper。正测量协议/身份 scope/签名要求不变。所有 negative 仍 qualification=false、model_request_count_verified=false、retry=false。

minimal_rerun：observer、producer provenance 及相关 runtime/consumer Python 回归，diff-check、validation plan、独立审查。确定性输入只证明解析器行为，不替代真实模型、usage、签名或 owner/field。

rollback_anchor：main 23aeb9a760e2e0e13740e1cdba913cb684158fcb；隔离 branch codex/m5-carrier-repair-20261013，保留未提交结果，不自动发布。下一步先审查/发布，再在明确授权的一次真实取证中验证实际 carrier；旧 run 保持 FAIL/BLOCKED。
