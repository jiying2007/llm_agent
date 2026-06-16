# Subrepo Removal Plan: codex

Date: 2026-06-16
Mode: dry-run
Status: planned

## Decision

`codex` is eligible for a removal plan because its lifecycle state is `disabled` and it is not `agent-dev-kit` or `active-core`.

## Planned Changes

- Remove `.gitmodules` entry for `codex`.
- Remove the root gitlink for `codex`.
- Mark `subrepos/registry.csv` and `manifests/subrepo_lifecycle.json` as removed.
- Drop any matching `subrepos/dirty-baseline.tsv` row only after confirming no unrelated dirty state is hidden.

## Gates

- Precheck: `rtk scripts/check-all.sh --quick`
- Postcheck: `rtk scripts/check-all.sh --quick`
- Rollback: `rtk git revert <removal-commit>`

No removal has been applied by this report.
