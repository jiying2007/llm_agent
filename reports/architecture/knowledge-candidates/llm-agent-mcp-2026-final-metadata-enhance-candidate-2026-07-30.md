# Knowledge Hub Candidate：MCP 2026-07-28 final metadata ENHANCE

- source:
  `agent-dev-kit/docs/changes/mcp-2026-final-metadata-refresh-2026-07-30/verify-report.md`
- captured_at: 2026-07-30
- last_verified: 2026-07-30
- topic: mcp-2026-final-metadata-enhance
- candidate_kind: decision
- intended_domain: projects/llm-agent
- status: reviewing
- owner: leiwenjun
- review_after: 2026-10-28

## Summary

独立 owner 对 candidate `epc-c6f947d482aa8aa0c78f` 作出受限 `ENHANCE` 决策。MCP
`2026-07-28` final tag、commit、release 和许可证边界已刷新到现有 ADK compatibility
staging，但 active protocol 仍为 `2025-11-25`，runtime、Tasks、Apps、extensions、final
compatibility claim 和 activation 均保持 disabled。

## Durable Decisions

1. final release metadata 与 compatibility/activation evidence 是两个独立状态；不得由
   `release_status=released` 推导 compatible。
2. `final_spec_retrieved=true` 只表示 final source 已取回。
3. Tasks、Apps、extensions 必须有独立机器可读 false 状态；不能只依赖
   `runtime_enabled=false`。
4. schema fixture、version-pinned client/server smoke、auth boundary review 和 rollback smoke
   均完成后，仍需要新的独立 owner activation decision。
5. 上游存在 Apache-2.0、MIT、CC-BY-4.0 过渡边界；当前只保存 metadata，不复制 code、
   specification 或文档正文。

## Verification

- decision schema：1/1 pass。
- ecosystem：492 checks、13 negative fixtures、runtime=false。
- ADK full parity：Python 3.11.15 与 3.12.13 各 57/57，routing 各 30/30，dependency
  audit 无已知漏洞。
- root scoped governance、adoption、docs 与 diff checks 通过。
- root aggregate：17/18；唯一失败来自本轮前已有 dirty removal-plan hash，不属于 MCP diff。

## Provenance

- release:
  `https://github.com/modelcontextprotocol/modelcontextprotocol/releases/tag/2026-07-28`
- final tag commit: `5f5440bb26a62e2cf3440b92da5a667efa03b267`
- retrieved_at: 2026-07-30
- owner decision:
  `reports/external-practice-targeted-decisions-2026-07-30.jsonl`
- implementation:
  `agent-dev-kit/docs/changes/mcp-2026-final-metadata-refresh-2026-07-30/`

## Sanitization

- 不包含 token、凭证、raw API response、网页正文、specification 正文、SDK code、cache
  或 runtime state。
- 只保存公开 URL、不可变 revision、状态、决策、验证摘要和回退边界。

## Residual Risk

- schema/client-server/auth/rollback runtime evidence 尚未执行，不能声明 compatibility。
- 上游许可证按文件/用途区分，任何未来内容复制都必须重新审查。
- 根工作区存在与本 change 无关的 dirty removal fixture hash，整体健康仍为 needs-fix。

## Memory Candidate

`no`。该结论属于项目级 source/compatibility decision，不应静默提升为个人 memory 或
全局 AGENTS 规则。

## Gate Result

`reviewing`。Knowledge Hub dry-run transaction：
`kh-20260730T162731Z-88135f66`，`read_only=true`、`dry_run=true`、
`active_promotion=false`、`write_applied=false`。

dry-run 前两次负结果已保留：

- 相对 source 被按 Hub root 解析，改用明确的绝对只读 source。
- `scope=project`、`visibility=internal`、`ai_role=verifier` 不属于 Hub enum，改用
  `project-specific`、`team-internal`、`drafted`，未放宽 schema。

允许项目级 Knowledge Hub decision candidate 复核；不授权 active promotion、runtime
enablement、source-to-live、commit、push 或 publish。
