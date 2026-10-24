# 8.0.40 接入验证

本记录冻结于 Root promotion source `4de6364d18d65d3ae43364dc4625a0c2c4be3bb6` 的交付阶段。独立普通用户完整回归已实际 79/79 PASS，295.901 秒，2026-10-24T17:20:21.095768–17:25:16.996707 UTC；Root/ADK 源码与工作区前后不变。14 项严格维护预算全部通过、零警告。受保护候选 CI、实际 main CI 与新 qualification-followup 是后续独立交付门禁，其最终结果在本 PR 的 Delivery 节记录；这里不预填通过结果。

## 已完成的真实上游验证

- ADK [PR #221](https://github.com/jiying2007/agent-dev-kit/pull/221) 已合并；实际 main `80ba8954c7d9f6225a2c5a4a2f0d805e8eb157c4`，tree `cda8f8223beb236bebb08df17908168a883fad90`。
- 本地原完整套件 101/101 PASS，248.573 秒，前后源码与工作区稳定；候选 [40113818339](https://github.com/jiying2007/agent-dev-kit/actions/runs/40113818339) 与实际 main [40114372768](https://github.com/jiying2007/agent-dev-kit/actions/runs/40114372768) 三个 Python 版本各 101/101 PASS。实际 main CI 9/9 成功。
- [v8.0.40](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.40) 于 2026-10-24T17:12:55Z 正式发布，Release 422869029 为 immutable；[发布运行 40114884700](https://github.com/jiying2007/agent-dev-kit/actions/runs/40114884700) 成功。Annotated tag `360645efabf9ca1778c540812478437abc3ee7cf` 精确指向该 main。
- 三项正式下载资产与 exact-main clean rebuild 逐字节相同；canonical CLI 输出与官方 contract 字节一致，publishable 断言及嵌入 commit/tree 校验通过。详见 `evidence/adk-release-verification.json`。
- 正式 tar SHA256 为 `b5e6220337bc34d326bfaa781a23cf144e1689be8c65d997cda3caac539f9196`，与实际 main 的原始签名 evidence 完全一致。
- 原升级演练实际安装 8.0.39 的 39 项、升级 8.0.40 的 39 项，再回滚恢复 39 项；旧版文件 hash、mode 和原 receipt 字节/mode 均通过。完整报告为 `evidence/adk-upgrade-rollback.json`。

## 原始签名与六路径事务

主线 artifact 12567828449 的 ZIP SHA256 为 `61ea192d400614bb5a3ece26ad60d3f845ed374df44e98328e9f42b346045b46`。原 evidence SHA256 为 `20fe84342225f36fdd9f4e79105bcb8d5f390bf1392419d4a3e5cd3373481904`；原 attestation SHA256 为 `e93dc0fb335dc6b68cf668a70d11003bcf8c02f0c6b3a18e554397629da19b1a`。

Pinned Cosign v3.1.3、固定 GitHub Actions main workflow identity 与 OIDC issuer 的真实 `verify-blob` 返回 `Verified OK`。Root 原 `scripts/check-adk-promotion-evidence.sh` 同时完成消费者 claims 和真实签名校验。

Canonical dry-run 与 apply 均成功，原回执分别保存在 `evidence/promotion-dry-run.json` 与 `evidence/promotion-apply.json`。Apply 从规划 source `33878cc1dac2faa28a32f4899afa7e0397fe1d0f` 原子暂存六路径，状态保留 `applied-not-verified`；原回执没有因后续验证被改写。

`reports/current-status.md` 仅更新 ADK 身份及派生输入摘要。原 Native、G22、LTA、现场与产品资格保持真实边界，`release_authorized=false`。原 F3 review 的时间与 source 绑定保持历史身份；本次独立 review 负责新的 pin、签名输入与状态投影。

## 原失败、证据与限制

`evidence/delivery-observations.json` 完整保留上述实际执行的原始记录及 stdout/stderr。首次本地 Cosign 因 scratch executable mode 0644 未启动；恢复同一已校验二进制的 0755 后，以新唯一 label 实际校验通过。原空 raw 和失败观察保留，不伪造首次进程退出状态。

发布产物核验者曾实现 F2，本记录仅表示公开制品与发布合同的独立执行核验；F1/F2 源码语义独立审核沿用 ADK 内各自独立记录。无付费模型或 provider 调用，无 Native/live/effect/field/G22/LTA/Product M5 资格提升。隔离环境缺少 canonical `~/codex` Knowledge Provider / Execution Policy 入口，相关 live 验收为 not-run，不能据此推断用户主机故障。

回退使用已保留的正式 8.0.39 来源与原签名证据，经同一 promotion/受保护 PR 路径执行；正式 tag 与历史审核记录不重写。
