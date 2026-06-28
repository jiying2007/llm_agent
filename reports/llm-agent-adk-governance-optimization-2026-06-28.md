# llm_agent / agent-dev-kit governance optimization - 2026-06-28

## Summary

This run implemented the one-round governance consolidation plan for `llm_agent` and `agent-dev-kit`.

- Scope: phase gate review, ADK boundary validation, known dirty confirmation, and `~/codex -> ~/.codex` live evidence refresh.
- Non-scope: upstream sync, reference subrepo cleanup, new ADK skill/workflow creation, and production-field release claims.
- Result: governance checks passed, ADK full regression passed, Codex live refresh completed without asset copy/overwrite/delete, and phase gate review metadata was refreshed.

## Baseline

| Check | Result |
|---|---|
| Root branch | `main...origin/main` |
| Root dirty state | `OpenSpec`, `superpowers`, and `vibeflow` are dirty reference subrepos |
| ADK subrepo state | clean: `main...origin/main` |
| Subrepo summary | `status=pass clean=2 dirty=3 known_dirty=3 unexpected_dirty=0 stale_baseline=0` |
| Health summary | `adk_version=2.9.0 adk_lock_state=ok active_repos=5 tracked_subrepos=5 check_scripts=47` |
| Phase gate before update | `phase=fallback-sunset allow_upstream_sync=yes next_review_by=2026-06-29` |
| Knowledge Hub route | `project_id=llm-agent`, no current/recent matched items for this specific query |

## Evidence Index

| Command | Exit Code | Result Summary | Layer |
|---|---:|---|---|
| `rtk scripts/check-subrepo-state.sh . --summary-json` | 0 | `known_dirty=3`, `unexpected_dirty=0`, `stale_baseline=0` | Root governance |
| `rtk scripts/check-phase-gate.sh . --summary-json` | 0 | `phase=fallback-sunset`, `allow_upstream_sync=yes`, previous `next_review_by=2026-06-29` | Root governance |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | 0 | ADK strict validation passed | ADK |
| `rtk bash agent-dev-kit/tests/run_all.sh` | 0 | `tests=42 pass=42 fail=0` | ADK |
| `rtk scripts/check-skill-metadata.sh .` | 0 | skill metadata checks passed | Root/ADK governance |
| `rtk scripts/check-skill-routing-conflicts.sh .` | 0 | no skill routing conflicts | Root/ADK governance |
| `rtk bash /home/leiwenjun/codex/scripts/build.sh` | 0 | build completed, `profile=team-collab`, `managed=725` | Codex source |
| `rtk bash /home/leiwenjun/codex/scripts/doctor.sh --scope all` | 0 | repo/build/live checks passed, `errors=0 warnings=0` | Codex source/live |
| `rtk bash /home/leiwenjun/codex/scripts/plan.sh --target /home/leiwenjun/.codex --prune-stale --output /home/leiwenjun/codex/build/apply-plan.json` | 0 | `copy=0 keep=466 overwrite=0 delete=0 mkdir=261 skip=0` | Codex source/live |
| `rtk bash /home/leiwenjun/codex/scripts/apply.sh --plan /home/leiwenjun/codex/build/apply-plan.json --dry-run` | 0 | dry-run confirmed `copy=0 overwrite=0 delete=0` | Codex source/live |
| `rtk bash /home/leiwenjun/codex/scripts/apply.sh --plan /home/leiwenjun/codex/build/apply-plan.json` | 0 | live apply completed, `copy=0 overwrite=0 delete=0` | Codex source/live |
| `rtk bash /home/leiwenjun/codex/scripts/check-routing-precedence.sh` | 0 | `default_profile=team-collab`, `active_superpowers_in_default=0` | Codex runtime routing |
| `rtk bash /home/leiwenjun/codex/scripts/check.sh` | 0 | full Codex source/live/smoke checks completed | Codex source/live |
| `rtk scripts/check-global-codex-health.sh /home/leiwenjun/.codex minimal` | 0 | global Codex health ready, `errors=0 warnings=0` | Codex live |

## Decisions

- Keep `phase=fallback-sunset` and `allow_upstream_sync=yes`.
- Update `last_live_refresh` to `2026-06-28` because the source-to-live chain completed through actual apply.
- Update `next_review_by` to `2026-07-06` for the next weekly fallback/upstream intake review.
- Leave `OpenSpec`, `superpowers`, and `vibeflow` untouched because they are known dirty reference subrepos and not part of this ADK governance change.
- Do not add ADK skills or workflows in this run; current evidence supports governance consolidation, not new capability promotion.

## Residual Risk

- Production-field readiness remains limited by missing real device evidence: hardware flashing/readback, HIL, OTA rollback, boot logs, and field package validation are still not proven by this run.
- Reference subrepos remain dirty by baseline. They are not blocking this governance pass because `unexpected_dirty=0`, but strict release cleanup would need a separate review.
- Knowledge Hub preflight found the canonical `llm-agent` route and recommended candidate handling for validation tasks. This run records evidence in this repo report; no separate Hub candidate was written.
