# Prompt 静态证据分析: oh-my-codex

- generated_at: 2026-07-13T05:50:32Z
- source_commit: f947e3a41c062c25fd107686862b68ee5d1b66a5
- source_ref: HEAD
- worktree_branch: main
- snapshot_mode: git-archive
- analysis_policy: commit-snapshot-only
- analysis_scope: static-evidence
- semantic_review_status: required
- worktree_dirty_classification: clean
- worktree_dirty_count: 0

## 项目结构

| 指标 | 数值 |
|---|---:|
| 总文件数 | 1259 |
| Markdown | 402 |
| SKILL.md | 75 |
| AGENTS.md | 1 |
| 脚本文件 | 756 |

## Prompt 证据

- 命名相关文件: 81
- 代码信号位置: 50

- `crates/omx-sparkshell/src/prompt.rs`
- `docs/prompt-guidance-contract.md`
- `docs/prompt-migration-changelog.md`
- `docs/qa/ci-speedups-after-prompt-worker-fix.md`
- `plugins/oh-my-codex/skills/ai-slop-cleaner/SKILL.md`
- `plugins/oh-my-codex/skills/analyze/SKILL.md`
- `plugins/oh-my-codex/skills/ask/SKILL.md`
- `plugins/oh-my-codex/skills/autopilot/SKILL.md`
- `plugins/oh-my-codex/skills/autoresearch/SKILL.md`
- `plugins/oh-my-codex/skills/autoresearch-goal/SKILL.md`
- `plugins/oh-my-codex/skills/best-practice-research/SKILL.md`
- `plugins/oh-my-codex/skills/cancel/SKILL.md`
- `plugins/oh-my-codex/skills/code-review/SKILL.md`
- `plugins/oh-my-codex/skills/configure-notifications/SKILL.md`
- `plugins/oh-my-codex/skills/deep-interview/SKILL.md`
- `plugins/oh-my-codex/skills/design/SKILL.md`
- `plugins/oh-my-codex/skills/doctor/SKILL.md`
- `plugins/oh-my-codex/skills/hud/SKILL.md`
- `plugins/oh-my-codex/skills/omx-setup/SKILL.md`
- `plugins/oh-my-codex/skills/performance-goal/SKILL.md`
- `plugins/oh-my-codex/skills/pipeline/SKILL.md`
- `plugins/oh-my-codex/skills/plan/SKILL.md`
- `plugins/oh-my-codex/skills/prometheus-strict/SKILL.md`
- `plugins/oh-my-codex/skills/ralph/SKILL.md`
- `plugins/oh-my-codex/skills/ralplan/SKILL.md`
- `plugins/oh-my-codex/skills/skill/SKILL.md`
- `plugins/oh-my-codex/skills/team/SKILL.md`
- `plugins/oh-my-codex/skills/ultragoal/SKILL.md`
- `plugins/oh-my-codex/skills/ultraqa/SKILL.md`
- `plugins/oh-my-codex/skills/ultrawork/SKILL.md`

## 模式证据

下表只表示可复核的静态信号，不直接构成采纳结论。

| Signal | Present | Evidence count |
|---|---|---:|
| progressive-disclosure-assets | True | 3 |
| tool-backed-skills | False | 0 |
| explicit-guardrails | True | 20 |
| tests-or-evals | True | 20 |

决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。
