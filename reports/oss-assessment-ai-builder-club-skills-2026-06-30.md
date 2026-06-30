# AI-Builder-Club/skills 吸收评估

Date: 2026-06-30
Source: https://github.com/AI-Builder-Club/skills
Original URL checked: https://github.com/JayZeeDesign/loop-engineer-template
Read status: GitHub README and selected raw `SKILL.md` files were reviewed.

## Decision

`adapt` / `method-only`.

Do not add the repository as an active reference subrepo. Do not install its Claude Code plugin, copy its `CLAUDE.md` knowledge-base layout, or import `crabbox` / Daytona runtime assumptions.

## Adopted

| Candidate | Local landing | Gate |
|---|---|---|
| First loop run must produce reviewable evidence | `agent-dev-kit/manifests/automation_worktree_contracts.json` now requires `first_run_evidence` for report-only automation contracts | `agent-dev-kit/scripts/check-openai-developers-governance.sh` |
| Subjective or user-visible feature proof should not be self-certified by the implementer | `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` now requires `Subjective Feature Proof` with an independent verifier | `agent-dev-kit/scripts/check-codify-governance.sh` |
| E2E should exercise real flows and preserve meaningful assertions | Preserved as guidance inside the same completion and automation evidence rules; no new runtime imported | ADK validation and governance checks |

## Rejected

| Candidate | Reason |
|---|---|
| Active reference subrepo | Overlaps existing `vibeflow`, `planning-with-files`, `oh-my-codex`, `scale-engine`, and ADK harness-loop contracts. |
| Claude plugin layout and `CLAUDE.md` scaffolding | Runtime-specific and duplicates existing AGENTS / skill / Knowledge Hub boundaries. |
| `crabbox` / Daytona isolated cloud boxes | External runtime, credentials, billing, and supply-chain surface are too large for default ADK. |
| One-command Web dev stack as global default | Useful for Web profiles only; not a universal embedded-fullstack or ADK core requirement. |

## Validation

```bash
rtk bash scripts/check-openai-developers-governance.sh --summary-json
# pass: status=pass, automation_contracts=2, worktree_contracts=1, failures=0

rtk bash scripts/check-codify-governance.sh
# pass

rtk bash tests/test_skill_content.sh
# pass: 440 checks, 0 failures

rtk bash tests/test_openai_developers_governance.sh
# pass

rtk bash scripts/devkit.sh validate --quick --summary-json
# pass: agents=12, skills=55, optional_skills=9, profiles=9, workflows=6

rtk bash ../scripts/check-doc-sync.sh ..
# pass

rtk bash ../scripts/check-adk-lock.sh
# pass
```

Parent `check-subrepo-state.sh . --summary-json` remains non-clean while this change is uncommitted: `unexpected_dirty=1` is the edited `agent-dev-kit` subrepo. This is expected before commit and does not indicate a content gate failure.
