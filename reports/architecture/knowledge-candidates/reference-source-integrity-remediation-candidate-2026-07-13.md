# Reference Source Integrity Candidate

- source: `reports/reference-source-integrity-remediation-2026-07-13.md`
- topic: reference-source-integrity
- captured_at: 2026-07-13
- last_verified: 2026-07-13
- review_status: candidate
- target_route: `projects/llm-agent/validation`
- memory_candidate: no

## Reusable Decision

外部参考仓的工作树只能作为本地状态证据，不能直接充当上游事实。可采纳分析必须锚定明确 commit，并从不可变 snapshot 读取；分析产物写入治理仓或独立 evidence 目录，不写回来源仓。

dirty 状态至少区分 mode、content、file type、untracked 和 staged。fingerprint 只能证明状态未变化，不能证明来源可信；内容或文件类型变化必须显式进入 owner review。

## Verification Contract

- 报告记录 source commit、snapshot mode、dirty classification 和 analysis policy。
- commit snapshot 不包含 uncommitted 或 untracked 文件。
- 来源仓在分析前后不产生新增文件或状态变化。
- dirty pull 在任何远端操作前被拒绝。
- 正向 fixture 与 dirty/untracked/path traversal 负向 fixture 同时通过。

## Sanitization

未包含凭证、私有端点、原始会话、完整第三方内容或运行态缓存。仓库名只用于本项目 provenance，不提升为通用 runtime 依赖。

## Promotion Boundary

本文件仅为可审查候选，不代表 Knowledge Hub active/archive 已更新；promotion 需要 owner review 和独立 Hub gate。
