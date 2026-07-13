# Prompt 静态证据分析: OpenSpec

- generated_at: 2026-07-13T05:50:32Z
- source_commit: 3c7a05c5dc88b2397c478805890b55ed392b19e8
- source_ref: HEAD
- worktree_branch: main
- snapshot_mode: git-archive
- analysis_policy: commit-snapshot-only
- analysis_scope: static-evidence
- semantic_review_status: required
- worktree_dirty_classification: mode+content
- worktree_dirty_count: 655

## 项目结构

| 指标 | 数值 |
|---|---:|
| 总文件数 | 658 |
| Markdown | 402 |
| SKILL.md | 0 |
| AGENTS.md | 1 |
| 脚本文件 | 213 |

## Prompt 证据

- 命名相关文件: 4
- 代码信号位置: 50

- `AGENTS.md`
- `src/commands/workflow/instructions.ts`
- `src/core/artifact-graph/instruction-loader.ts`
- `src/core/config-prompts.ts`

## 模式证据

下表只表示可复核的静态信号，不直接构成采纳结论。

| Signal | Present | Evidence count |
|---|---|---:|
| progressive-disclosure-assets | False | 0 |
| tool-backed-skills | False | 0 |
| explicit-guardrails | True | 16 |
| tests-or-evals | True | 20 |

决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。
