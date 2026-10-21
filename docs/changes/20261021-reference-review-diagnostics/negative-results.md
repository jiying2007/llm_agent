# Negative results

## Original production failure

At 2026-10-21 13:18:59 UTC the checker failed, as required, because the
OpenSpec, superpowers and vibeflow baseline/review expired on 2026-10-14.
Each review was rejected before the code could attempt a current snapshot.
The combined exception handler nevertheless called that failure
`current snapshot unavailable`.

The added regression was run against the original checker at 13:20:57 UTC.
It returned exit code 1 with two subtest failures: expired review and invalid
review digest both received the misleading snapshot diagnostic. The valid
review followed by an unavailable snapshot retained the expected diagnostic.
The immutable raw stderr is 3302 bytes, SHA-256
`75a3b61e578b1183119f48df7a96c3dd81d60411a795bfbe49b90470cc9ec815`,
under `oct21-next-evidence/reference-diagnostics-regression-red/` in the
delivery audit.

The canonical working-tree paths are also absent in this environment, but
that is a separate path observation. It cannot be inferred from a snapshot
call that never occurred. Re-cloning clean upstream commits or extending
dates would not recover or review the original dirty content.

## Corrected production failure is retained

At 13:21:17 UTC the corrected production checker still returned exit code 1.
The three expired baselines are unchanged. Their associated review failures
now identify the failed review stage and do not imply a current snapshot was
attempted. The actual missing working trees and the original negative result
remain independent facts; this change grants no source or runtime approval.

## Environment boundary

The real `/root/codex` Hub is absent. The apply preflight retains
`status=BLOCKED` and `policy_invoked=false`; no replacement HOME or Hub is
created by this change.
