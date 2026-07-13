# Prompt 静态证据分析: superpowers

- generated_at: 2026-07-13T05:50:31Z
- source_commit: 6efe32c9e2dd002d0c394e861e0529675d1ab32e
- source_ref: HEAD
- worktree_branch: main
- snapshot_mode: git-archive
- analysis_policy: commit-snapshot-only
- analysis_scope: static-evidence
- semantic_review_status: required
- worktree_dirty_classification: mode+content+type
- worktree_dirty_count: 115

## 项目结构

| 指标 | 数值 |
|---|---:|
| 总文件数 | 146 |
| Markdown | 73 |
| SKILL.md | 14 |
| AGENTS.md | 0 |
| 脚本文件 | 35 |

## Prompt 证据

- 命名相关文件: 25
- 代码信号位置: 6

- `docs/superpowers/plans/2026-01-22-document-review-system.md`
- `docs/superpowers/specs/2026-01-22-document-review-system-design.md`
- `skills/brainstorming/SKILL.md`
- `skills/brainstorming/spec-document-reviewer-prompt.md`
- `skills/dispatching-parallel-agents/SKILL.md`
- `skills/executing-plans/SKILL.md`
- `skills/finishing-a-development-branch/SKILL.md`
- `skills/receiving-code-review/SKILL.md`
- `skills/requesting-code-review/SKILL.md`
- `skills/subagent-driven-development/SKILL.md`
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- `skills/subagent-driven-development/implementer-prompt.md`
- `skills/subagent-driven-development/spec-reviewer-prompt.md`
- `skills/systematic-debugging/SKILL.md`
- `skills/test-driven-development/SKILL.md`
- `skills/using-git-worktrees/SKILL.md`
- `skills/using-superpowers/SKILL.md`
- `skills/verification-before-completion/SKILL.md`
- `skills/writing-plans/SKILL.md`
- `skills/writing-plans/plan-document-reviewer-prompt.md`
- `skills/writing-skills/SKILL.md`
- `skills/writing-skills/testing-skills-with-subagents.md`
- `tests/claude-code/test-document-review-system.sh`
- `tests/explicit-skill-requests/prompts/use-systematic-debugging.txt`
- `tests/skill-triggering/prompts/systematic-debugging.txt`

## 模式证据

下表只表示可复核的静态信号，不直接构成采纳结论。

| Signal | Present | Evidence count |
|---|---|---:|
| progressive-disclosure-assets | True | 1 |
| tool-backed-skills | True | 1 |
| explicit-guardrails | True | 10 |
| tests-or-evals | True | 20 |

决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。
