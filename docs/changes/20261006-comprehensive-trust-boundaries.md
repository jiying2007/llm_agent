# 根仓来源与端点信任边界审查候选

基线main c79151a。内部审查实证security审计按URL子串信任，https://api.anthropic.co被当作api.anthropic.com；promotion claims接受布尔ID和与source.commit不同的workflow SHA，普通JSON也允许重复键。后者仅claims验收缺口，不宣称绕过完整cosign。所有复现均/tmp或stub doctor/CLI，无实际provider/MCP连接或配置写入。

端点审计移至tools.codex_assets.runtime_security：有界TOML只读解码，精确HTTPS authority/port与路径段边界，拒绝凭据/query/fragment、控制字符、编码或dot-path歧义，错误只输出原因/计数，不回显秘密。CODEX_TRUSTED_BASE_URLS改为完整受审URL边界，不再接受任意字符串子串；根仓要求Python3.11，与现有pyproject/CI一致。旧doctor与loaded-list流程保留，typed审计本身不连接网络。

来源claims复用root intake_io公共read_json的byte/depth/duplicate/nonfinite约束，避免验证器依赖尚未安装的producer SDK；直接脚本入口也明确root bootstrap。run_id/run_attempt须精确正整数，workflow_sha==source.commit仅绑定当前canonical main-push producer契约，lock重复键拒绝。真实签名/issuer/source/projection的其它约束不放宽。

一手设计证据：SLSA1.2 Approved要求签名后核consumer expectations（https://slsa.dev/spec/v1.2/verifying-artifacts）；MCP安全实践要求边界与凭据隔离（https://modelcontextprotocol.io/docs/2025-11-25/tutorials/security/security_best_practices）。没有自动启用experimental Tasks或新增runtime依赖，外部实践仅设计输入。

验收为定向正负回归、standalone非repo help、原promotion shell正负、全root回归与独立只读审查，最终hash和结果在source外记录。保护原root references和Codex用户dirty；未修改M5/owner/过期日期以刷绿。真实模型评测与产品资格仍独立缺证。回滚按此包consumer-owned代码与文档恢复，不改上游mirror或用户runtime配置。
