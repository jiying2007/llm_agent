# Prompt 静态证据分析: scale-engine

- generated_at: 2026-07-13T06:46:08Z
- source_commit: ace49169c4191db656989b738f31edb19a380a63
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
| 总文件数 | 966 |
| Markdown | 193 |
| SKILL.md | 19 |
| AGENTS.md | 1 |
| 脚本文件 | 647 |

## Prompt 证据

- 命名相关文件: 23
- 代码信号位置: 50

- `.cursor/skills/kc-autopilot/SKILL.md`
- `.deepseek/instructions.md`
- `.harness/SKILL.md`
- `.scale/skills/api-design/SKILL.md`
- `.scale/skills/code-review/SKILL.md`
- `.scale/skills/debugging/SKILL.md`
- `.scale/skills/documentation/SKILL.md`
- `.scale/skills/fix/SKILL.md`
- `.scale/skills/frontend-design/SKILL.md`
- `.scale/skills/git-workflow/SKILL.md`
- `.scale/skills/performance/SKILL.md`
- `.scale/skills/planning/SKILL.md`
- `.scale/skills/pr-creator/SKILL.md`
- `.scale/skills/refactoring/SKILL.md`
- `.scale/skills/release/SKILL.md`
- `.scale/skills/security-audit/SKILL.md`
- `.scale/skills/storage-analyzer/SKILL.md`
- `.scale/skills/tdd/SKILL.md`
- `.scale/skills/update-docs/SKILL.md`
- `AGENTS.md`
- `docs/AGENT_ECOSYSTEM.md`
- `docs/workflow/PROMPT_OPTIMIZATION.md`
- `src/cli/promptCommands.ts`

## 模式证据

下表只表示可复核的静态信号，不直接构成采纳结论。

| Signal | Present | Evidence count |
|---|---|---:|
| progressive-disclosure-assets | True | 1 |
| tool-backed-skills | True | 1 |
| explicit-guardrails | True | 20 |
| tests-or-evals | True | 20 |

决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。
