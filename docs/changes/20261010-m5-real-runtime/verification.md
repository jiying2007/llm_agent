# 默认模型迁移及真实资格推进证据

本轮已将根仓 M5 采集与 rollover 默认模型统一为 `gpt-6.1-sol`，推理强度默认 `medium`。本机原配置已为这组值，不需要修改 live 配置。本轮不执行 commit、push、merge、外部 CI 触发或 source-to-live apply。

## 真实模型调用

采集使用 pinned ADK 8.0.5，Codex CLI 0.159.2，ChatGPT 登录认证；`codex exec` 使用 read-only sandbox、ephemeral 临时会话、结构化输出、一个 canonical `route-001` 任务。临时 PATH shim 在 exec 子命令注入 `--ignore-user-config` 与 `model_reasoning_effort="medium"`；配置请求单独记录为 requested，不能冒充实际模型或推理强度观察。

- 第一次尝试在版本预检退出，没有进入推理。原因是将 exec 专属参数置于全局位置，已修正并复审。
- 第二次真实调用完成：路由/安全判定为 pass，1/1，input tokens 25,085，output tokens 77，total tokens 25,162；`reported_models=[]`。
- 采集器以 `runtime report has no valid observed model` 拒绝生成有效 evidence。当前 CLI 事件没有 ADK 可核验的模型身份，不使用 requested_model、聊天模型或本机配置补造 observed model。
- 本轮两次采集预算已用完。后续需要受信模型身份观测支持与 fresh capture；这个单任务 smoke 也不构成完整 runtime campaign。

原始结果保留于工作区 ignored `.cache/m5-real-runtime-20261010/raw-attempt-1.json` 与 `raw-attempt-2.json`，不将 raw 内容归档为项目资格。

## 真实 Cosign 与 promotion

官方固定 Cosign v3.1.3 本体为 141,178,250 字节。通过官方文档规定的 Sigstore root-history/10 bootstrap root，用 TUF 7.0.1 验证 root/timestamp/snapshot/targets 链并下载 `artifact.pub` 与 `trusted_root.json`。先以系统 OpenSSL 验证 release KMS 签名，通过后才执行 Cosign。工具及依赖仅存工作区隔离缓存。

- binary SHA256：`4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71`。
- trusted root SHA256：`6494e21ea73fa7ee769f85f57d5a3e6a08725eae1e38c755fc3517c9e6bc0b66`。
- promotion evidence SHA256：`d607402e2e0e5248e0f53a4a525748e218b24bebeed9ef01d1397a49a73fbd02`。
- attestation SHA256：`bb4dd5781c7af2b249721bec2d6aaccc65b0a74aa3bd4cfafe457c91846c9894`。
- 共享签名消费者使用四个显式 pin，冻结工具/根/签名/原文后离线验签，固定 canonical ADK main CI 身份与 GitHub OIDC issuer：PASS。
- 原有 `check-adk-promotion-evidence.sh` 使用真实工具：PASS，`Verified OK`。
- 验证对象为 ADK 8.0.5，commit `ef5384305421700ca01e89b3df3b3f7878a70265`，producer run `37636892408`。此验证不代表根仓当前未提交实现已有签名 CI 或 owner 放行。

发现并修复原消费者 128 MiB 上限不足：提高到有限 256 MiB，保留 pin、输入冻结、安全读取与离线验证。新增测试证明边界接线，真实验签另外取证。

## 独立资格审计

当前 diagnostics 的 candidate、policy contract、promotion claims、promotion signature、field 最低策略通过；总体 `status=blocked`，`software_m5_certified=false`、`release_authorized=false`。

- runtime：旧证据 manifest_version 与当前 lock 不匹配；新调用缺实际模型身份。
- qualification：旧 CI 资格 ADK identity 与 lock 不匹配；根仓当前 dirty，也没有同基线受信签名 CI receipt。
- historical declaration：历史候选 `5.0.0-rc.2` 的声明不能作为当前候选资格。未修改历史 policy、qualification 或 scorecard 日期来消除失败。
- field：当前策略的最低事件要求通过，证据为历史 independent pilot start。不能由此推导当前候选完整现场验证、30 天效果或 owner 批准。
- 公共 Sigstore trust 的本地验证不自动写入 hosted owner-reviewed repository variables。

## 软件验证

- M5 定向 unittest：37/37 PASS，涵盖 default model、model binding、exec-only shim、拒绝无效或未绑定输入、签名边界。
- 首轮 root：72/74；两项失败已定位为 shell fixture 仍使用旧默认模型，以及 workspace 内 TMPDIR 与 reference cache 隔离门禁冲突。已同步模型 fixture，将 plan-only cache 的空临时目录移至 /tmp；两项定向复验通过。
- 独立复审：模型与执行参数 17/17，新增签名边界回归 4/4；Spec PASS、Quality PASS，无新增 blocker/major。该审查不替代真实资格。
- Ruff E9/F 与 git diff --check：PASS。
- 隔离离线 wheel 构建：PASS；54 个 Python 源文件逐字节匹配，4 个 CLI 在非仓库 cwd help 通过，未安装或发布。
- wheel SHA256：`10d49344c968bd42f13e67142ef3d7b0fe765710c76f900209b11644e23149ee`。
- source-map SHA256：`f5d27bc231360e2f637967d5f469f042e32d771c7a7c56b2512263d4d738ae0c`。
- 最终完整 root：74/74 PASS；回执 `.cache/m5-real-runtime-20261010/root-tests-final.json`，SHA256 `2bdae7785e50263f45592a624a6834c3815d78e85a6ccc571d2dcb347a22241a`。
- ADK quick：56/56 PASS；回执 `.cache/m5-real-runtime-20261010/adk-tests.json`，SHA256 `5b1d9c085beaec9867dba38a37ab31fe05f5ed42832508591a455329828e5706`；ADK tracked clean。
- 稳定串行聚合：51/52，workspace-fingerprint-stability PASS。唯一失败为 `check-software-m5-readiness.sh` 的历史 candidate/当前资格/scorecard 声明。真实 promotion gate PASS，未将聚合总体写成 PASS。
- 聚合首次在全量测试并发期间出现 workspace fingerprint 漂移，并因隔离 PATH 遗漏本机 PCRE2 rg 失败；已使用现有支持 PCRE2 的 rg，在全量测试结束后串行复验。保留环境负结果，不改生产扫描门禁。
- Provider reviewing candidate dry-run：PLANNED、persisted=false；未声明已归档或 owner 审批。
- 活动登记未执行：Provider capabilities 仅提供 `subject_configured=true`，没有提供本轮可消费的显式 subject_id；遵循 Provider-only 与不推断主体的项目规则，不直接读取 Hub 内部配置或写 receipt。
- 本地 Execution Policy 由当前线程单独绑定 repo/build/review 与本报告后执行 final gate；它不代表 M5 或 release 放行。

## 官方来源

- [GPT-6.1-Sol 模型说明](https://developers.openai.com/api/docs/models/gpt-6.1-sol)：模型标识与支持的 reasoning effort。
- [Codex 非交互执行](https://learn.chatgpt.com/docs/non-interactive-mode)：exec 使用边界。
- [Cosign 官方安装及本体验证](https://docs.sigstore.dev/cosign/system_config/installation/)：TUF artifact.pub 与 KMS signature 的自举验证步骤。
- [Cosign v3.1.3 固定发布](https://github.com/sigstore/cosign/releases/tag/v3.1.3)：官方制品与 release API SHA256。

结论：本轮授权范围内实现、真实取证与软件复验已完成；真实签名缺项已关闭，当前候选 M5 完整资格仍 blocked。没有以确定性测试、假运行器或配置请求替代真实模型身份、签名、field 或 owner 证据。根仓保持未暂存、未提交、未推送；原有 untracked reference 目录保留。
