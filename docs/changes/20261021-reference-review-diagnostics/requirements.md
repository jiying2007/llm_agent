# Reference review failure diagnostics

## Frozen goal

Distinguish a rejected reference-worktree review from a failure to read the
current working tree. The checker currently reports `current snapshot
unavailable` even when an expired review stops execution before `snapshot()`.

## Acceptance

- An expired, invalid or unavailable review remains a failing gate and prevents
  the working-tree snapshot from being attempted.
- Such a review reports `review record invalid or unavailable`.
- An actual snapshot error, reached only after a valid review, retains
  `current snapshot unavailable`.
- Deterministic tests observe the snapshot call boundary while using the real
  review validator, and the existing content-identity tests continue to pass.
- The current expired production baseline remains failed after the correction.

## Boundary

Only the checker, its existing test module and this change record are in scope.
No reference checkout, baseline date/content, qualification authority, shared
validator, CI configuration or runtime installation changes are authorized by
this correction. No external evidence is created.
