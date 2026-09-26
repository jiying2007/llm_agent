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

It then calls the pinned ADK canonical Agent Value contract and empty-measurement path. A healthy software baseline must remain `not-measured/no-valid-receipts` when no real receipt is supplied; missing data is never filled with zero. The Root `manifests/effect_value_evidence_index.json` is the only terminal evidence index and is intentionally empty until a real campaign is reviewed.

## Exit semantics

- default: exit 0 when the projection is valid, even if real effect evidence is still externally blocked;
- `--require-evidence`: exit 2 until the governed real-evidence campaign is complete;
- malformed/mismatched source: exit 1.

A default PASS is **not** an effectiveness claim.

## Evidence index and transition to ready

A campaign may enter `manifests/effect_value_evidence_index.json` only after all referenced files are stored under `reports/effect-evidence/`. Each record binds, by SHA-256:

1. the complete `adk-effect-trials/v1` input;
2. the exact `adk-effect-trial-comparison/v1` output;
3. every runtime/field invocation receipt used by the measurement;
4. the exact `adk-asset-value-measurement/v1` output;
5. one `llm-agent-effect-owner-review/v1` record.

The readiness gate does not trust those files merely because they exist. It:

- re-runs the pinned ADK repeated-trial comparator and requires the stored comparison to be identical;
- checks comparison `input_ref`, `plan_ref`, and `controls_ref` against the frozen input;
- takes `plan.bundles.candidate` as the candidate asset identity;
- validates every invocation receipt against the pinned receipt schema;
- when Agent Value authority is enabled, re-runs the pinned managed verifier and `emit_measurements` over the exact receipt set and fixed measurement window/as-of, requiring an identical measurement;
- requires runtime/field, not test/mixed, measurement scope and managed-authority verification;
- binds every measured asset to the candidate bundle;
- requires accepted evidence to cover agent, skill, and profile assets plus measured task-success, wrong-route, abstain-precision, human-intervention and non-insufficient retirement signals;
- requires owner review to bind the exact trial/comparison/measurement digests and candidate bundle, occur after the evidence window, and cover every measured asset;
- permits owner `observe`, but any retain/consolidate/retire decision must be supported by the corresponding measurement retirement signal.

A rejected owner review is valid historical evidence but does not make the campaign ready. No owner review auto-applies a merge, deletion, profile change, release, or runtime mutation.

## Current external blocker

The canonical evidence index is empty today. Terminal G22 therefore still requires:

- owner-reviewed Agent Value authority enablement and exact managed-registry binding;
- real repeated task trials with fixed runtime/model/control identities;
- sanitized runtime/field invocation receipts;
- representative successes and failures;
- wrong-route and abstain observations;
- outcome measurements and retirement signals;
- an accepted digest-bound owner review added to the canonical evidence index.

Synthetic trials and test-layer receipts validate software/state-transition behavior only and cannot populate the canonical index. A retirement signal never authorizes deletion by itself.

ADK v1 also keeps `production_authority=false`, `quality_evidence_eligible=false`, `owner_review_required=true`, and `lifecycle_authority=none-evidence-only`. G22 readiness records that real evidence and review exist; it does not create production release authority. A future production-quality authority model remains a separate versioned contract/schema change.
