# Tasks

## Ownership

Root consumer implementation, related tests, four runbooks and all seven files in this change belong to `ai/root/native_evidence_audit`. ADK schema/API/policy, release, Root promotion locks, canonical empty G22 index migration and CI belong to `ai/root` and its ADK implementation agent. Independent reviewer `ai/root/external_methods` remains read-only on reviewed worktree source; retained patch transfer during recovery is not a source edit.

## Work list

- [x] TASK-001 — Freeze owner authorization, the one ADK policy/API and explicit review scopes.
- [x] TASK-002 — Implement exact historical base/head/patch, active/archive uniqueness, provenance and source-aware collector scope.
- [x] TASK-003 — Add G22 v6 and LTA v2 delegated-review consumers without changing actual signature, field actor, observation or chronology requirements.
- [x] TASK-004 — Bind actual loaded validator modules to pinned source and verify policy/authorization/validators against parent gitlink and ADK HEAD/index/raw worktree; remove optional ADK from static import requirements while retaining runtime failure and API shape checking.
- [x] TASK-005 — Complete independent Spec/Quality review of the recovered candidate and retain actual new validation timestamps and source identities. Final review at `2026-10-20T12:20:25.352831Z` closed `ROOT-DELEGATED-AUTHORITY-001`; historical 70/72-test review remains separate.
- [x] TASK-006 — Restore proposal, requirements, design, tasks, checklist, negative results and verification report, plus four affected runbooks; state the recovery boundary honestly.
- [ ] TASK-007 — Complete formal ADK release and exact Root component pin promotion through existing interfaces and locks.
- [ ] TASK-008 — Run full G22 fixture integration against that formal pin and complete the combined final review.
- [ ] TASK-009 — Complete Root protected CI and fresh-main readback, then update trackers only to the degree supported by their canonical evidence.

## Recovery checkpoint

Root main `2722715dc44b5226d0eaf488aa00734bdade4345` was restored after the environment reset. At the initial restoration checkpoint, collector and bridge matched the prior final SHA exactly. Other reconstructed byte identities are listed in [verification](verify-report.md) and require fresh review. The recovery environment actually passed the 72 focused tests, default no-ADK mypy, Ruff and full LTA shell suite before `2026-10-20T12:00:00Z`. Full formal-pin G22 and protected delivery are not inferred from those tests.

The subsequent independent review found `ROOT-DELEGATED-AUTHORITY-001` despite those 72 tests passing. After the additional bridge fix, its SHA intentionally changed. The implementer actually reran **79 tests PASS** (5.913 seconds), default no-PYTHONPATH mypy for 9 files, Ruff, shell syntax and `git diff --check` before the observed time `2026-10-20T12:11:22Z`. The independent reviewer then actually ran 79 tests from `12:15:59.379217Z` to `12:16:09.271615Z` and closed the source review with separate Spec/Quality pass at `12:20:25.352831Z`.

No task creates or backfills an authenticated Native campaign, real effect observation or LTA field summary. Their absence remains an external evidence blocker after source work is complete.
