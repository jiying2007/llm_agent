# Tasks

## Ownership

Root consumer implementation, related tests, four runbooks and all seven files in this change belong to `ai/root/native_evidence_audit`. ADK schema/API/policy, release, Root promotion locks, canonical empty G22 index migration and CI belong to `ai/root` and its ADK implementation agent. Independent reviewer `ai/root/external_methods` remains read-only on reviewed worktree source; retained patch transfer during recovery is not a source edit.

The delivery coordinator `ai/root` adds the final delivery sections and retained raw evidence after the validation freeze ends. This documentation increment receives its own independent review; it does not change the previously reviewed consumer implementation.

## Work list

- [x] TASK-001 — Freeze owner authorization, the one ADK policy/API and explicit review scopes.
- [x] TASK-002 — Implement exact historical base/head/patch, active/archive uniqueness, provenance and source-aware collector scope.
- [x] TASK-003 — Add G22 v6 and LTA v2 delegated-review consumers without changing actual signature, field actor, observation or chronology requirements.
- [x] TASK-004 — Bind actual loaded validator modules to pinned source and verify policy/authorization/validators against parent gitlink and ADK HEAD/index/raw worktree; remove optional ADK from static import requirements while retaining runtime failure and API shape checking.
- [x] TASK-005 — Complete independent Spec/Quality review of the recovered candidate and retain actual new validation timestamps and source identities. Final review at `2026-10-20T12:20:25.352831Z` closed `ROOT-DELEGATED-AUTHORITY-001`; historical 70/72-test review remains separate.
- [x] TASK-006 — Restore proposal, requirements, design, tasks, checklist, negative results and verification report, plus four affected runbooks; state the recovery boundary honestly.
- [x] TASK-007 — Complete formal ADK release and exact Root component pin promotion through existing interfaces and locks. Immutable `v8.0.36` was published at `2026-10-20T12:51:18Z`; Root promotion C2 `ee47d8597aabe1ab7530905c8076dcebe13aa1cc` pins ADK `42ae95d146ceb441ff91ea33dbbed581c33de305`.
- [x] TASK-008 — Run full G22 fixture integration against that formal pin and complete the source/promotion review. The actual G22 run passed at `13:52:07.255248Z`; independent six-file promotion Spec/Quality review passed at `13:53:07.527685Z`.
- [ ] TASK-009 — Independently review the final documentation/evidence increment, complete final-head protected Root CI and fresh-main readback, then update trackers only to the degree supported by their canonical evidence.

## Delivery record boundary

This is the pre-delivery evidence snapshot for [Root PR #265](https://github.com/jiying2007/llm_agent/pull/265). TASK-009 is deliberately not pre-checked before its final commit and main CI exist. The final PR body is the authoritative post-delivery record for final-head review, protected merge, clean-commit checks, main CI, original qualification artifact and tracker readback; it must cite actual outcomes rather than require a self-referential documentation commit.

At the frozen C1-plus-six-promotion-files checkpoint, all 79 original Root regression scripts passed with canonical exit 0. The strict capture returned 3 because a test-generated untracked canary remained; all 2,387 tracked entries and their index/mode/content identities were unchanged. The original failure record is retained, and exact cleanup restored the original snapshot. The subsequent aggregate check actually returned 1 with 47 PASS / 5 FAIL and an unchanged before/after snapshot. These distinct results, the two earlier environment failures and their bounded diagnoses are recorded in [verification](verify-report.md), [negative results](negative-results.md) and [retained evidence](evidence/README.md).

## Recovery checkpoint

Root main `2722715dc44b5226d0eaf488aa00734bdade4345` was restored after the environment reset. At the initial restoration checkpoint, collector and bridge matched the prior final SHA exactly. Other reconstructed byte identities are listed in [verification](verify-report.md) and require fresh review. The recovery environment actually passed the 72 focused tests, default no-ADK mypy, Ruff and full LTA shell suite before `2026-10-20T12:00:00Z`. Full formal-pin G22 and protected delivery are not inferred from those tests.

The subsequent independent review found `ROOT-DELEGATED-AUTHORITY-001` despite those 72 tests passing. After the additional bridge fix, its SHA intentionally changed. The implementer actually reran **79 tests PASS** (5.913 seconds), default no-PYTHONPATH mypy for 9 files, Ruff, shell syntax and `git diff --check` before the observed time `2026-10-20T12:11:22Z`. The independent reviewer then actually ran 79 tests from `12:15:59.379217Z` to `12:16:09.271615Z` and closed the source review with separate Spec/Quality pass at `12:20:25.352831Z`.

No task creates or backfills an authenticated Native campaign, real effect observation or LTA field summary. Their absence remains an external evidence blocker after source work is complete.
