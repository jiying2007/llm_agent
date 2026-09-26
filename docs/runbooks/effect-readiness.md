# Effect / value readiness

`llm-ctl effect-readiness` is the Root machine projection for G22. It is read-only and delegates comparison and measurement schema semantics to the exact pinned ADK worktree.

```bash
rtk python3 -m tools.control_plane.cli effect-readiness --root . --summary-json
rtk python3 -m tools.control_plane.cli effect-readiness --root . --require-evidence --summary-json
```

The projection separates two independent questions:

1. **software_ready** — repeated-task comparison, Agent Value contracts, managed receipt trust, schemas and canonical empty-measurement behavior are present and coherent;
2. **effect_evidence_ready** — governed, digest-bound real evidence exists and covers every current Agent/Skill/Profile.

A default PASS only means the projection is valid. It is not an effectiveness, retirement or release claim.

## Canonical evidence index

The Root SSOT is:

```text
reports/runtime-evidence/effect-value/evidence-index.json
```

The default index is intentionally empty:

```json
{
  "schema": "llm-agent-effect-value-evidence-index/v2",
  "status": "active",
  "entries": []
}
```

Each future entry binds exactly four Root-relative files beneath the index directory:

- the original ADK `adk-effect-trials/v1` campaign input;
- the resulting ADK `adk-effect-trial-comparison/v1`;
- one ADK `adk-asset-value-measurement/v1`;
- one Root `llm-agent-effect-owner-review/v2`.

Every path has an exact SHA-256 in the index. Root recomputes the comparison from the pinned campaign input using the exact pinned ADK and requires byte-equivalent JSON semantics. The campaign/comparison ID must equal the index entry ID.

## Evidence required for terminal readiness

A comparison is accepted only when its verdict is decisive: `improved`, `non-inferior`, or `regressed`. It remains test-only, `quality_evidence_eligible=false`, `owner_review_required=true`, `lifecycle_authority=none-evidence-only`, and `release_authorized=false`. Test-only comparison authority is not enough by itself: Root must recompute it from the indexed campaign input, then require every campaign run `trace_ref`, both baseline/candidate bundle digests, and the campaign runtime target to be covered by the same entry's managed runtime/field Agent Value measurement. This prevents a synthetic comparison from being paired with unrelated runtime-looking measurement data.

A measurement is accepted only when:

- `measurement_status=measured`;
- `manifest_ref` matches the exact pinned ADK manifest;
- top-level scope is `runtime-verified`, `field-verified`, or `mixed`;
- every counted asset measurement is runtime/field evidence with `source_verification=managed-authority-verified`;
- authority IDs are present;
- task-success, wrong-route, and abstain-precision are actually measured;
- at least one substantive retirement signal is present: retain, consolidate-candidate, or retire-candidate.

The union of accepted measurements must cover **every current** Agent, Skill, optional Skill, and Profile in the pinned ADK manifest. Unknown assets are rejected; stale manifest measurements are rejected.

## Owner review contract

The owner-review document is deliberately simple and has no execution authority:

```json
{
  "schema": "llm-agent-effect-owner-review/v2",
  "status": "approved",
  "campaign_id": "campaign-id",
  "campaign_sha256": "<64 hex>",
  "comparison_sha256": "<64 hex>",
  "measurement_sha256": "<64 hex>",
  "reviewed_at": "2026-09-26T00:00:00Z",
  "reviewed_by": "<real human reviewer identity>",
  "reviewer_role": "owner",
  "automation_generated": false,
  "observed_cases": {
    "success": true,
    "failure": true,
    "wrong_route": true,
    "abstain": true
  },
  "asset_decisions": [
    {
      "asset_id": "example",
      "asset_kind": "skill",
      "decision": "retain"
    }
  ],
  "raw_content_stored": false,
  "release_authorized": false,
  "lifecycle_authority": "owner-review-recorded-execution-separate"
}
```

The review must bind the exact campaign/comparison/measurement digests, identify the real reviewer, set `automation_generated=false`, and cover every asset in its measurement. Allowed decisions are `retain`, `consolidate-candidate`, `retire-candidate`, and `reject-change`. Conflicting decisions for the same asset across active entries invalidate the index.

A recorded decision does **not** delete an asset, merge a skill, mutate a profile, or authorize a release. Execution remains a separate reviewed change.

## Safe defaults are not permanent blockers

ADK intentionally keeps its canonical Agent Value contract disabled and the trust registry empty by default. Those safe defaults are reported for observability, but they do not make terminal readiness impossible.

Real measurements may be produced by a separately owner-reviewed managed contract and verified receipt path. The readiness projection judges the resulting governed evidence artifacts, not whether the canonical default contract was globally enabled.

## Exit semantics

- default: exit 0 when the projection/source is valid, including the normal `blocked-external-evidence` state;
- `--require-evidence`: exit 0 only when software is ready, the index is non-empty, all entries are valid, and full current-asset coverage plus owner decisions are present;
- `--require-evidence`: exit 2 while terminal evidence is incomplete;
- malformed, stale, unknown-asset, digest-mismatched, conflicting-review, or schema-invalid evidence: exit 1.

The integration gate uses the canonical index path. `--evidence-index` exists so deterministic fixtures and separately reviewed campaigns can be validated without rewriting the canonical index before review.

## Current expected state

Until real evidence is added, the canonical state is:

```text
software_ready=true
effect_evidence_ready=false
terminal_status=blocked-external-evidence
```

Synthetic repeated trials and generated fixture measurements validate the state machine only; they cannot be committed as canonical runtime/field evidence. Index v2 specifically prevents an unbound synthetic campaign from becoming terminal by requiring campaign→comparison recomputation and campaign trace/bundle/runtime-target coverage from managed runtime/field measurement evidence.
