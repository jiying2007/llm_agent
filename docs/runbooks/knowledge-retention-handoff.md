# Knowledge retention handoff

G9 的 Root 职责止于“生成可复核的脱敏候选并提供当前 Knowledge Hub dry-run handoff”。Knowledge Hub registry、review queue、owner decision、active/archive promotion 属于独立 Hub authority。

## Root 检查

```bash
rtk python3 -m tools.control_plane.knowledge_retention_handoff --root . --summary-json
rtk bash tests/test_knowledge_retention_handoff.sh
```

候选固定为：

`docs/knowledge-candidates/llm-agent-adk-target-architecture.md`

投影会校验 candidate identity/status/promotion、SHA256、引用来源以及 secret/private-path-like 内容，并输出当前 Hub 命令。

## Hub dry-run

从 llm_agent 仓根执行投影返回的 `commands.capture_dry_run`。当前稳定语义是 `knowledge-capture.sh --source ... --kind architecture ... --status reviewing --dry-run --json`。

旧的 `knowledge-promote.sh --target projects/llm-agent` 已不是当前接口：promote 是 owner-reviewed lifecycle transition，不是项目路径写入入口。

## 权限边界

- Root 不执行 `--apply`。
- Root 不创建 Hub owner decision 或 authorization。
- capture dry-run 通过也只说明候选可以进入 Hub reviewing 计划，不代表已 capture，更不代表 active。
- Hub status/review queue 和最终 owner review 必须在 knowledge-hub 独立完成。
- 若 owner 决定不 promotion，可保留 reviewing/archive/reject 结果；Root 不把“没有 active promotion”视为软件失败。


## 2026-09-26 Hub dry-run evidence

The Root candidate was exercised through the **actual Knowledge Hub canonical wrappers** in a read-only temporary Hub PR:

- Hub base: `d2e15c31a2562ce92cee99e4695dc7835062512d`
- Root source: `109949bf36001548d03a96732a8d6020395b518a`
- candidate SHA256: `3d56a96bba926f014fcf68de8bb880bdf2356d88651ca66a3964df41ac7fbd6d`
- Hub workflow run: `36214654406`
- artifact: `10897225255`
- artifact SHA256: `d8d0a6c493f52f1d3254c5fe6823352b1d50f083c3decdaeca744e07d5b6d2d8`

Observed capture semantics:

```text
status=planned
created_status=reviewing
dry_run=true
transaction.read_only=true
active_promotion=false
promotion_authorized=false
```

The Hub status projection returned `needs-review`. The temporary evidence PR was closed without merge, so no Hub item/registry mutation occurred.

The durable Root evidence record is:

`reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json`

### Remaining authority

The governed capture was subsequently applied through Knowledge Hub PR #124 and merged to Hub master `0fb7ed1e2dbd5f715b9b4382581d696081af1b8c`. The item is now `reviewing`, `manual-entry-pending-review`, `manual_validation_pending=true`, and `promotion=none`.\n\nG9 no longer has a software, dry-run, or mechanical-capture blocker. The only remaining blocker is a **real human Knowledge Hub owner lifecycle decision**. Automation must not fill `reviewed_by`, fabricate authorization, promote to active/archive, or infer a lifecycle outcome.


Hub master post-merge Quality run `36218784210` completed successfully across Python 3.8–3.14, MCP 2026, engineering/supply-chain, and the final Quality gate. This validates the merged reviewing capture without changing its owner-review boundary.
