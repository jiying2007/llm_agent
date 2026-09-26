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
