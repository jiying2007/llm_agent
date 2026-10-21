# Verification record

This file records executed checks only. The diagnostic correction and focused
verification are complete; independent review and parent integration are
pending at this checkpoint.

The original production checker was executed on 2026-10-21 at
13:18:59 UTC. It returned exit code 1 and reported three expired baselines
plus three `current snapshot unavailable` diagnostics. Its stdout was 446
bytes with SHA-256
`80f7b080c3f6b5f5fe30dd427cde5f418cf22760e99cda584ecb81eef72a8f87`.
The original stdout, empty stderr and timing receipt are retained in the
delivery audit under `oct21-next-evidence/reference-diagnostics-before/`.

The canonical Hub apply preflight at 13:19:35 UTC returned exit code 2:
`/root/codex` is absent, the current thread identifier exists, and the real
policy was not invoked. Source work proceeds under the existing explicit
user authorization; this observation is not a policy PASS or runtime proof.

## Executed regression and corrected checks

The actual validation plan at 13:20:53 UTC classified the current managed
changes as L3. The parent integrator owns its full Root regression, ADK quick
regression and working-tree aggregate requirements; this focused result does
not claim those have passed.

The new regression was first run against the original checker at 13:20:57
UTC and failed in the two expected review-error subtests. That output remains
unchanged in `reference-diagnostics-regression-red/`.

After separating the two exception boundaries, the complete existing
`tests.test_reference_content_identity` module ran from 13:21:17.838499 to
13:21:19.609604 UTC and passed **13 tests**. The new test uses three cases:
expired review, invalid review digest, and unavailable snapshot after a valid
review. The first two assert that no snapshot call occurs. The last asserts
one snapshot call per repository and the unchanged snapshot-error message.
Existing content drift, Git hook isolation, mode, index, symlink and resource
boundary checks also passed. The raw stderr is 2255 bytes with SHA-256
`8f27119743f83096766301e269a8139c6d6aeed23f7bf486786d791cd7af9052`.

The actual production checker at 13:21:17 UTC still returned **exit code 1**.
Its three existing baseline-expired messages remain. The three misleading
snapshot messages are now `review record invalid or unavailable`. The stdout
is 470 bytes with SHA-256
`769b33083c112db11165f8775a5195e7653daf023dce56d6e08d25cc8c44049b`.
No dates, content identity or qualification result were refreshed.

`bash -n scripts/check-reference-dirty-triage.sh` returned exit code 0 with
empty stdout and stderr. All commands used the real RTK wrapper and recorded
actual timestamps, exit status, byte counts and digests. The delivery audit
retains the corrected outputs under `reference-diagnostics-tests/`,
`reference-diagnostics-after/` and `reference-diagnostics-shell-syntax/`.
