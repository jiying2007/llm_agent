# 当前候选模型观测修复与证据边界

已完成根仓模型观测适配、安全修复与新鲜软件验证；当前候选 M5 完整资格仍 blocked。默认请求继续为 `gpt-6.1-sol`、`medium`，没有修改本机 live 配置、ADK pinned source 或历史 scorecard。

## 实现与真实性

新增可选 `--observe-provider-model`，必须与 `--execute --allow-network --limit 1` 一起使用。collector 冻结观察器源码，记录执行快照 SHA256；消费者验证当前 adapter bytes、固定上游、模型身份、完成状态、response ID、header 来源、请求摘要及单任务计数。原无观察器路径继续可用。

Codex 负责登录和生成原生请求；临时转发器监听 127.0.0.1，POST 只转向 `https://chatgpt.com/backend-api/codex/responses`，使用默认 TLS 校验。认证头只在内存转发，不读取认证文件、不保留请求/响应正文、不保存 native stderr。工具被禁用；WebSocket 与第二次上游请求被拒绝。所有读取、连接和子进程有 deadline/容量限制，失败诊断独占新建，不覆盖文件。

app-server ThreadStartResponse 的 model/reasoningEffort 明确不是每轮执行 telemetry，不能作为实际模型身份。观察器仅接受实际 HTTP OpenAI-Model 或官方 native parser 接受的 SSE response.headers.OpenAI-Model，并标注不同来源；不接受 response.model、配置或模型输出文本。必须有同一 response ID 的完成事件，精确匹配请求模型，不接受 fallback。

## 本轮真实复采

- 第一次：ADK 生成失败原始报告，没有有效模型身份。无推理探针随后确认 Codex 0.159.2 禁止覆盖内置 model_providers.openai，属于启动配置失败；改用官方 root openai_base_url。
- 无推理探针：实际 native Codex 请求到达本地 relay，但在创建上游 HTTPS socket 前由测试拦截；没有外部模型调用，不能作为资格证据。
- 第二次：实际上游返回 HTTP 200，未进入已验证的 SSE 流阶段；没有可核验的 model/completion/usage，collector 拒绝生成有效 runtime evidence。旧版诊断只能定位为内容类型或响应头检查阶段，不能精确归因为某一种协议问题。后续诊断已细分阶段与允许的内容类型类别，但本轮没有追加真实调用。
- 两次采集额度已使用，不以测试、HTTP 200 或 requested_model 填充 observed model；没有可靠 usage，不能声称第二次没有推理或没有费用。

失败回执仅存 ignored `.cache/m5-model-observation-20261010/`，不归档 raw 为资格：两个 raw report SHA256 均为 `8871255c5b50746756a5ef01795f6f8ed1b7bdf412760a7029e99e34c22656c5`；第二次脱敏 failure metadata SHA256 为 `4410bbd72a927a577da5a2482fc8fae03f5c409dee13694e89ddc17c4ef5c861`。原始 grader 会将执行异常归一化，两份相同 digest 不表示两次过程相同。

## 新鲜验证

- M5 定向：52/52，ResourceWarning 为 error；主代理和独立 reviewer 分别通过。
- root 完整：74/74；回执 SHA256 `54cc4fb9c4233621a207cf86f3f721c72790b33968db1c651a107d674ca067a8`。
- ADK quick：56/56；回执 SHA256 `edca2443dca836a1b689f6c3a8aee3b8250350aa5d7e8437703e87bed175c2fe`，ADK tracked clean。
- Ruff E9/F、git diff --check、doc sync：PASS。
- 离线 wheel：55 个 Python 源文件逐字节匹配；5 个 CLI 在非仓库目录 help 通过；未安装、未发布。wheel SHA256 `ccc9a1d74c351df6f98104fe6cb9ebcc100f9adc59ae05c638a2cae17a972264`；source-map SHA256 `e246bd277753250695e0319e9231a9edea2c6f0f23dc9c814c75c2a477fa9dc4`。
- 独立复审：Spec PASS / Quality PASS，无未关闭的新 major/minor；见同目录 review.md。
- 真实 Cosign 新鲜复验：共享消费者与原 promotion gate 均 PASS。验证的是 exact ADK 8.0.5 promotion，producer run 37636892408，不是当前根仓 dirty 变更的 CI。
- 串行聚合：51/52，workspace-fingerprint-stability PASS。唯一失败为 check-software-m5-readiness.sh：历史候选、当前 runtime/qualification 与过期 scorecard 声明仍不满足。总体 FAIL，保留真实失败。
- Token budget 检查：PASS，3 项既有 AGENTS soft-limit warning、0 failure；未为消除警告修改运行规则。

## 剩余条件与下一步

当前 diagnostics 确认 `software_m5_certified=false`、`release_authorized=false`；candidate、promotion claims/signature 与最低 field 策略通过，runtime、qualification、historical_declaration 阻断。

1. 核实 native HTTP 与实际返回内容类型/模型 header 的兼容性，再在明确预算内重新取证；只有任务完成、可核验模型身份与 usage 满足时才形成新 runtime evidence。
2. 当前根仓仍 dirty，未 commit/push/触发外部 CI。待明确 SCM 授权后以评审后的同一基线产生受信签名 CI receipt，再准备新资格；不能用旧 run ID 替代。
3. 当前候选的 field/owner 完整资格需独立验收。历史候选 5.0.0-rc.2 与当前 ADK 8.0.5 不匹配，旧声明及日期不修改；新资格通过后才更新当前声明，保留历史。

本地 Execution Policy 按当前实际线程登记本报告并运行 final；当前目标有剩余项，保持 active，不为了通过 final 将未完成目标标为 complete。该策略不能代表 Runtime/CI/field/owner 域资格。全域资格没有关闭，不声明已完全修复、可发布或可合并。

仅形成本地可审查变更与证据报告。Provider status 为 READY_FOR_CALL，但 activity-capture 只提供 subject_configured=true，没有通过公开契约给出本轮可消费的显式 subject_id；未执行活动写入，不从身份、路径、Git 或 memory 推断主体，不直接读取或写入 Hub 内部目录，不声明归档成功，不写 memory。

## 官方设计依据

- [Codex app-server](https://learn.chatgpt.com/docs/app-server)：原生协议；实际使用本机 0.159.2 离线导出的 schema 核验 telemetry 边界。
- [官方配置 schema](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/config.schema.json)：openai_base_url 入口。
- [官方 SSE parser](https://raw.githubusercontent.com/openai/codex/main/codex-rs/codex-api/src/sse/responses.rs)：区分服务端 response.headers 和 response.model。
- [官方 client](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/client.rs)：ChatGPT 原生请求压缩的实现参考。

上游 main 源码用于设计依据，不冒充 exact 0.159.2 源码；实际版本兼容性由本机 CLI、schema、无推理探针和真实采集结果分别取证。
