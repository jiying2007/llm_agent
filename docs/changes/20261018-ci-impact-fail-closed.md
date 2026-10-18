# Git impact classification: fail closed on missing history

## Requirements
A missing, malformed, all-zero or unreadable Git comparison base on PR and push must not produce `integration-deep: NOT_REQUIRED`. Keep the gate DAG and existing required check names. Do not change Python compatibility or require a paid service.

## Design
- For PR/push, the GitHub integration-impact job requires an exact nonzero full SHA and an accessible commit before running the canonical typed impact CLI.
- The canonical `_git_changed_paths` rejects empty or unavailable comparison bases, rather than returning an empty file list.
- Explicit manual dispatch remains opt-in to forced deep integration, with no Git base by default; that mode is not used as a protected PR gate.
- Missing history blocks until checkout/fetch is repaired; it does not manufacture a positive deep-integration receipt.

## Verification contract
Existing always-run `tests/test_ci_incremental_gate_dag.sh` now covers missing empty base, nonexistent SHA and process exit status, plus workflow guard presence. Protected PR checks and separate fresh-main CI remain mandatory. No production/runtime/field qualification is inferred from passing these tests.

## Rollback
Revert this change through a protected PR only if a replacement impact classifier proves equivalent fail-closed semantics. Never restore missing-base-as-empty-diff behavior.
