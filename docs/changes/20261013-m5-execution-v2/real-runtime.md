# Execution v2 真实运行证据

本次在已发布的 execution v2 基线上完成真实 Codex 任务测量及签名核验。新测量证据已保存于 `reports/runtime-evidence/codex-execution-v2-8.0.6-2026-10-13.json`，按原字节保留签名及内容摘要。

| 项目 | 实际证据 |
|---|---|
| Source baseline | `4b6f548a9d09c21fa4649fa0e03547bc0c9b717e` |
| Source tree | `a3e27bf7eadd11bc4e834da9aeca1e9aff4264ec` |
| ADK | 8.0.6 / `97cf0167e837c2095d9ec6a9431f5aa8c20a812b` |
| Workflow | [38392843037](https://github.com/jiying2007/llm_agent/actions/runs/38392843037)，workflow_dispatch，attempt 1 |
| Artifact | `software-m5-runtime-signed`，ID `11811276691` |
| Artifact SHA256 | `4fa9f025ab6fde9122ecce2010d39ab2c32733ccb00ade0c4bfb73545fb10663` |
| 任务 | `route-001`，1/1 PASS，质量、安全、路由、错误门禁全通过 |
| 报告 usage | 16609 total_tokens |
| 请求配置 | `gpt-6.1-sol` / medium |
| Runtime | Codex CLI 0.159.2 |
| 时间 | generated_at `2026-10-13T11:51:39Z`，review_after `2026-11-12` |
| 设施清理 | 临时 runner 26 已确认注销 |

主验证和独立复核均使用生产 measurement contract、固定实体 Cosign 及 trusted-root 校验；run/head/attempt、任务、usage、源码摘要与签名绑定通过。没有重新下载或自动重试模型任务。证据本身不含 raw session、raw SDK log、认证材料或实际模型身份字段。

## 使用与资格边界

此证据是一次真实任务测量，不认证实际 backend 模型身份，也不替代完整 campaign、field、人类 owner 或 release 验收。签名中的 baseline 是上述实际执行提交，不能改成新增此证据的文档提交或重新签名旧 payload。

本次未改写 policy 中的历史测量引用、qualification record、scorecard 或旧 field ledger。已有 digital-worker 试点仍绑定 ADK 5.0.0-rc.2；2026-10-10 的 GROS/A123X 记录为 ADK 8.0.5 候选筛选提案，并明确不是 pilot_started。当前 8.0.6 的 field 证据未核实前，整体 M5 保持未通过。不得通过改版本、日期或摘要把历史事件提升为当前现场证据。

该记录过期后保留为历史来源，后续资格仍需按当时有效期、当前输入和真实证据重新核验。
