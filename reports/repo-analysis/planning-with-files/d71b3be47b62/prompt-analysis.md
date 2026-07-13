# Prompt 静态证据分析: planning-with-files

- generated_at: 2026-07-13T06:46:07Z
- source_commit: d71b3be47b62fe49d60fb2ede800e1907ebea3d9
- source_ref: HEAD
- worktree_branch: master
- snapshot_mode: git-archive
- analysis_policy: commit-snapshot-only
- analysis_scope: static-evidence
- semantic_review_status: required
- worktree_dirty_classification: clean
- worktree_dirty_count: 0

## 项目结构

| 指标 | 数值 |
|---|---:|
| 总文件数 | 421 |
| Markdown | 167 |
| SKILL.md | 17 |
| AGENTS.md | 1 |
| 脚本文件 | 161 |

## Prompt 证据

- 命名相关文件: 13
- 代码信号位置: 50

- `.codebuddy/skills/planning-with-files/SKILL.md`
- `.codex/hooks/user-prompt-submit.sh`
- `.codex/skills/planning-with-files/SKILL.md`
- `.continue/prompts/planning-with-files.prompt`
- `.continue/skills/planning-with-files/SKILL.md`
- `.cursor/hooks/user-prompt-submit.ps1`
- `.cursor/hooks/user-prompt-submit.sh`
- `.cursor/skills/planning-with-files/SKILL.md`
- `.factory/skills/planning-with-files/SKILL.md`
- `.gemini/skills/planning-with-files/SKILL.md`
- `.hermes/skills/planning-with-files/SKILL.md`
- `.kiro/skills/planning-with-files/SKILL.md`
- `.mastracode/skills/planning-with-files/SKILL.md`

## 模式证据

下表只表示可复核的静态信号，不直接构成采纳结论。

| Signal | Present | Evidence count |
|---|---|---:|
| progressive-disclosure-assets | True | 5 |
| tool-backed-skills | True | 15 |
| explicit-guardrails | True | 20 |
| tests-or-evals | True | 20 |

决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。
