# Effect / value readiness

`llm-ctl effect-readiness` is the Root machine projection for G22. It is read-only and delegates Agent Value semantics to the exact pinned ADK worktree.

```bash
rtk python3 -m tools.control_plane.cli effect-readiness --root . --summary-json
rtk python3 -m tools.control_plane.cli effect-readiness --root . --require-evidence --summary-json
```

The projection checks three software layers:

1. repeated-task trial contracts and comparator implementation;
2. Agent/Skill/Profile invocation receipt and measurement contracts;
3. ADK 7.5 managed Agent Value trust verifier plus its repository registry.

It then calls the pinned ADK canonical Agent Value contract and empty-measurement path. A healthy software baseline must remain `not-measured/no-valid-receipts` when no real receipt is supplied; missing data is never filled with zero.

## Exit semantics

- default: exit 0 when the projection is valid, even if real effect evidence is still externally blocked;
- `--require-evidence`: exit 2 until the governed real-evidence campaign is complete;
- malformed/mismatched source: exit 1.

A default PASS is **not** an effectiveness claim.

## Current external blocker

Terminal G22 evidence requires all of the following outside the software fixture lane:

- owner-reviewed Agent Value authority enablement and exact managed-registry binding;
- real repeated task trials with fixed runtime/model/control identities;
- sanitized runtime/field invocation receipts;
- representative successes and failures;
- wrong-route and abstain observations;
- outcome measurements and retirement signals;
- owner review for any consolidation or retirement decision.

Synthetic trials and test-layer receipts can validate structure but cannot satisfy those requirements. A retirement signal never authorizes deletion by itself.

ADK v1 also keeps `production_authority=false`, `quality_evidence_eligible=false`, `owner_review_required=true`, and `lifecycle_authority=none-evidence-only`; a future production-quality authority model requires a separate versioned contract/schema change.
