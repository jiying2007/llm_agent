# 历史 M5 运行原件复核

复核时间：2026-10-20 03:24 UTC。此次只读下载、原字节比较和密码学验签均真实执行；没有重新运行模型、修改历史测量或产生当前版本资格。

## 原件与来源

| 项目 | 实际核验值 |
| --- | --- |
| Workflow | [38392843037](https://github.com/jiying2007/llm_agent/actions/runs/38392843037)，`workflow_dispatch`，attempt 1，实际 success |
| 历史 Root | `4b6f548a9d09c21fa4649fa0e03547bc0c9b717e` |
| 历史 ADK | 8.0.6 / `97cf0167e837c2095d9ec6a9431f5aa8c20a812b` |
| 原始 artifact | `software-m5-runtime-signed`，ID `11811276691`，ZIP 11198 bytes |
| ZIP SHA256 | `c64ff06697bb44c96fa6bdc3ddfff46ce30ca55772bf73df5a0a5c2af8b5bcb6`，下载字节与 GitHub artifact digest 一致 |
| 签名测量 JSON | 18187 bytes，SHA256 `4fa9f025ab6fde9122ecce2010d39ab2c32733ccb00ade0c4bfb73545fb10663` |
| 已归档原件 | [`reports/runtime-evidence/codex-execution-v2-8.0.6-2026-10-13.json`](../../../reports/runtime-evidence/codex-execution-v2-8.0.6-2026-10-13.json) 与重新下载的 JSON 逐字节相等 |
| 原始生成时间 | `2026-10-13T11:51:39Z`；原 `review_after=2026-11-12` 保持不变 |
| 托管 artifact 到期 | API 当前为 `expired=false`，`expires_at=2026-10-27T11:51:54Z`；已有 Git 归档保存了完整签名 JSON，无需复制或重新签名 |

## 实际验证

从原件严格 Base64 解码既有 payload 和 bundle，验证测量摘要、Root source、repository、workflow、ref、event、run ID 和 attempt，均与其原始身份相符。payload SHA256 为 `59d09f7565598237f581a99239edf4ba55a62aa248b275fb910b72ce9f0ee29d`；bundle SHA256 为 `0efea29c7ec3dc8e0569cf2595e82b7f25363dfd942fcd3ee37db3763f4dc06d`。

使用官方 Cosign 3.1.3 实体（SHA256 `4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71`）独立执行：

```sh
cosign verify-blob --bundle bundle.json \
  --certificate-identity https://github.com/jiying2007/llm_agent/.github/workflows/software-m5-runtime.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  payload.json
```

实际退出码 0，输出 `Verified OK`。另外通过 `git show` 对比历史 Root 的 collector 和 producer 原字节，两个源码摘要均与签名测量中记录的 pin 一致。

## 对既有资格任务的影响

该原件证明历史源上的一次 Codex CLI 0.159.2 路由任务成功：`route-001`，1/1 PASS，记录 total_tokens 为 16609，`cost_usd=null`。它没有证明一个完整的效果 campaign、Claude Code/OpenCode 原生目标、现场运行窗口或人工 Owner 结论；请求模型字段也不等同于认证实际 backend 模型身份。相关原始说明见 [Execution v2 真实运行证据](../20261013-m5-execution-v2/real-runtime.md)。

当前 Root 与 ADK 已推进，虽然两个 producer 文件的摘要仍相同，历史 ADK 8.0.6 和 Root source 绑定没有因此改变。Root #236 的当前候选资格仍须由当前 canonical certifier 消费符合其源码与政策要求的真实证据。此次确认历史原件已经持久保存且签名有效，不将其改写为当前证据，不改 policy、scorecard、field ledger 或资格锁。
