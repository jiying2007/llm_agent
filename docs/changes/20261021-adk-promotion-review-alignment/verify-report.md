# 验证检查点

## 已实际完成

| 项目 | 原始结果 |
| --- | --- |
| ADK [PR #218](https://github.com/jiying2007/agent-dev-kit/pull/218) | 已受保护 squash 合并；候选 tree 与主线 tree 均为 `4d6f92286ce32aee3afec88399301be6dce7c07a` |
| [PR CI 39584257463](https://github.com/jiying2007/agent-dev-kit/actions/runs/39584257463) | Python 3.8 / 3.11 / 3.12 均实际 101/101；必需检查通过 |
| [main CI 39584973370](https://github.com/jiying2007/agent-dev-kit/actions/runs/39584973370) | 精确 `19a89bab...`，三版本均实际 101/101；生成原始 promotion artifact |
| [release workflow 39585485699](https://github.com/jiying2007/agent-dev-kit/actions/runs/39585485699) | success；[不可变 v8.0.37](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.37) 于 2026-10-21T10:36:26Z 发布 |
| 原始 promotion 验签 | 2026-10-21T10:38:29–10:38:30Z，真实 Cosign exit 0 / Verified OK |
| 本地 clean-source 重建 | 10:42:06–10:42:07Z，exit 0；10:42:38Z 核对 tar、checksum 与 release manifest 逐字节等于正式制品 |
| 正式前后版本隔离演练 | 10:43:19–10:43:21Z，exit 0；各安装 39 项，回滚 removed 39 / restored 39，恢复原收据字节、资产摘要和权限 |
| Root canonical promotion | 10:43:13–10:43:14Z，exit 0，恰好六路径，`staged_transaction_complete=true` |
| Root promotion verifier | 10:43:27Z，exit 0；声明匹配且真实 Sigstore Verified OK |

上述未单列日期的时间均为 2026-10-21 UTC。正式 tar 为 2,239,510 bytes，SHA-256 `0f7a12e9e68f0d197ebd3a03e34218f1b9bb028f737ae8ad3dc481fd9a629495`。原始 promotion ZIP 为 artifact `12338538933`，SHA-256 `4997ab37bd4fddf5abb30f72eac2c4ea03595dfd5de1f48e6a337dd3bf10a6ad`。

Root 原始 promotion evidence SHA-256 为 `03bfd67e9d990167259d93391c89e297cc13b99ebf9c21fdc2e97eaf7b4c5658`，bundle 为 `a22dad09e19639d7c56764711e2c12f79c37a5232b2db68c6ec6bd7cf0e20586`。证书身份限定为 ADK `ci.yml@refs/heads/main`，OIDC issuer 为 `https://token.actions.githubusercontent.com`。Git annotated tag 指向精确正式 commit；签名结论来自 Sigstore 凭证。

## 最终 Root 验证

本文件冻结后，以原主线 `d89d2cdd23b799bb89ee3d069f6ea78d921fae90` 为 baseline 运行实际 validation plan。按 L4 执行 Root `tests/run_all.sh --fail-fast`、`scripts/check-all.sh --quick --working-tree`、单独 token-budget、独立审查及受保护交付；clean commit 后执行 `--release-clean`。原始 exit、开始/结束时间、前后源摘要和远端 run 身份进入本次 Root PR 最终正文与最终审计记录。

同一完整 Root runner 已覆盖 G22 / LTA / qualification-followup 定向脚本，无需重复执行。Docker parity 的实际不可用结果见 negative-results；主线 CI 和本地宿主测试分别陈述各自结果。

## 外部观察

[Digital Worker 2026-10-19 治理审计](https://github.com/jiying2007/digital-worker/actions/runs/39218854669/job/117949126415) 的实际日志在 07:52:57Z 报告 `DEFERRED_CURRENT_STAGE`、`iterative-development`、`advisory`、`branch_protected=false`、ruleset count 0。这是该次开发阶段治理观察，不构成现场观测或零事故证明；没有新的 field 状态变化可据此改写 Root #67。

资格终态以本次 fresh-main 原始 qualification-followup 报告为准。该诊断报告的 release authority 始终为 false。
