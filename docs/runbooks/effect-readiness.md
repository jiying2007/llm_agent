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
  "schema": "llm-agent-effect-value-evidence-index/v5",
  "status": "active",
  "entries": []
}
```

Each future entry binds the full replay package beneath the index directory:

- one canonical `llm-agent-effect-preregistration-package/v2` containing the exact plan, six content-addressed control artifacts, and baseline/candidate bundle manifests whose asset content refs bind the pinned ADK;
- one GitHub-OIDC/Sigstore signature bundle over the **entire canonical package**, created by `.github/workflows/effect-preregister.yml` before any effect-trial run or managed observation;
- the original ADK `adk-effect-trials/v1` campaign input;
- the resulting ADK `adk-effect-trial-comparison/v1`;
- one reviewed enabled Agent Value contract;
- one reviewed managed Agent Value trust registry;
- one `llm-agent-effect-receipt-set/v1` containing the raw sanitized runtime/field receipts plus fixed aggregation window/as-of;
- one ADK `adk-asset-value-measurement/v1`;
- one Root `llm-agent-effect-owner-review/v5`.

Registry signature-bundle paths are resolved relative to the evidence-index directory by ADK 7.11.0's portable managed verifier and shared digest-pinned Sigstore blob verifier. Root replays every raw receipt through the exact contract/registry/cosign trust semantics and recomputes the measurement with ADK `emit_measurements()`. A committed aggregate measurement is accepted only when it is exactly equal to that recomputation.

Every path has an exact SHA-256 in the index. Root recomputes the comparison from the pinned campaign input using the exact pinned ADK and requires byte-equivalent JSON semantics. The campaign/comparison ID must equal the index entry ID.

## Build the frozen package deterministically

Do not hand-maintain the six control `ref:` values or the baseline/candidate bundle SHA-256 values. Keep one source document with no derived hashes:

- `schema=llm-agent-effect-preregistration-source/v1`;
- exact campaign timing/task/trial/policy fields;
- only the six non-derived runtime/model identity fields under `plan.controls`;
- six canonical control artifact objects;
- baseline/candidate bundle manifests with explicit pinned asset `content_ref` identities;
- `provider_execution_performed=false`, `raw_content_stored=false`, `release_authorized=false`.

Then build and immediately validate the frozen package against the exact pinned ADK:

```bash
rtk python3 -m tools.control_plane.effect_preregistration_package \
  --adk agent-dev-kit \
  --source reports/runtime-evidence/effect-value/preregistrations/<campaign>.source.json \
  --output reports/runtime-evidence/effect-value/preregistrations/<campaign>.package.json \
  --summary-json

# independently replay validation at any time
rtk python3 -m tools.control_plane.effect_preregistration_package \
  --adk agent-dev-kit \
  --package reports/runtime-evidence/effect-value/preregistrations/<campaign>.package.json \
  --summary-json
```

The builder computes all six control refs and both bundle digests from canonical content and then calls the same v5 validator used by readiness. Source documents are rejected if they contain derived refs/digests, if pinned asset content refs drift, or if baseline/candidate differ only by labels/metadata. Existing output is not overwritten unless `--overwrite` is explicit.

The builder does **not** choose a model, time window, task population, intervention, budget, or provider. Those remain explicit reviewed experiment inputs, and a decisive campaign still requires `model_identity=revision-bound`.

## Real campaign execution path

After the content-addressed package has been committed and signed by the no-execution preregistration workflow, do not write an ad-hoc model loop. The pinned ADK 7.11.0 campaign state machine is the canonical long/paid execution path:

```bash
adk eval campaign run \
  --contract <reviewed-campaign-contract.json> \
  --state-dir <state-dir> \
  --execute \
  --approve-budget-usd <owner-approved-budget>

# interrupted work resumes from digest-validated state
adk eval campaign run \
  --contract <reviewed-campaign-contract.json> \
  --state-dir <state-dir> \
  --execute --resume \
  --approve-budget-usd <owner-approved-budget>

# after the selected runtime is complete
adk eval campaign materialize-effect \
  --contract <reviewed-campaign-contract.json> \
  --state-dir <state-dir> \
  --effect-plan <frozen-effect-plan.json> \
  --runtime <codex-or-claude> \
  --output campaign.json
```

The campaign contract may select a bounded non-empty subset of Codex/Claude runtimes. The materializer performs no provider call: it validates campaign-plan/result digests, exact runtime/model identity, task/trial completeness and observation-window membership, then emits trace-only Run Evidence inside `adk-effect-trials/v1`. Those test-only traces are the comparison input, **not** the managed runtime/field Agent Value receipts required later by G22.

A terminal-capable plan must use `model_identity=revision-bound`; alias-only model identity deliberately yields an inconclusive comparison. Provider/runtime execution therefore starts only after an immutable model identifier, budget and preregistered package are reviewable.

## Evidence required for terminal readiness

Before any provider/runtime trial is accepted, Root verifies the entire canonical preregistration package through the pinned ADK shared Sigstore verifier. Before signing, the package validator also validates `package.plan` against the exact pinned ADK `effect-trials-v1` plan schema, then recomputes all six plan control refs, both bundle digests, and pinned ADK Agent/Skill/Profile content refs; baseline and candidate must also differ in their actual asset identity/content-ref sets, so condition or metadata labels alone cannot manufacture an intervention. The signature bundle must use the reviewed Root workflow certificate identity, and its verified Rekor `integratedTime` must be strictly earlier than every effect-trial Run Evidence `observed_at`, every managed receipt `observed_at`, and every corresponding verified receipt signature time. The human-readable `registered_at` field is not temporal authority; a package signed after execution cannot be repaired by backdating JSON. The no-execution workflow performs no provider/model call.

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
  "schema": "llm-agent-effect-owner-review/v5",
  "status": "approved",
  "campaign_id": "campaign-id",
  "campaign_sha256": "<64 hex>",
  "comparison_sha256": "<64 hex>",
  "authority_contract_sha256": "<64 hex>",
  "authority_registry_sha256": "<64 hex>",
  "receipts_sha256": "<64 hex>",
  "measurement_sha256": "<64 hex>",
  "preregistration_package_sha256": "<64 hex>",
  "preregistration_bundle_sha256": "<64 hex>",
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

The review must bind the exact preregistration package/signature bundle, campaign/comparison, authority contract, authority registry, receipt-set and measurement digests, identify the real reviewer, set `automation_generated=false`, and cover every asset in its measurement. The measured asset set must exactly equal the preregistered candidate bundle asset set. The `observed_cases` flags must also exactly match representative success/failure/wrong-route/abstain cases derived from the verified raw receipts. Allowed decisions are `retain`, `consolidate-candidate`, `retire-candidate`, and `reject-change`. Conflicting decisions for the same asset across active entries invalidate the index.

A recorded decision does **not** delete an asset, merge a skill, mutate a profile, or authorize a release. Execution remains a separate reviewed change.

## Safe defaults are not permanent blockers

ADK intentionally keeps its canonical Agent Value contract disabled and the trust registry empty by default. Those safe defaults are reported for observability, but they do not make terminal readiness impossible.

Real measurements may be produced by a separately owner-reviewed managed contract and verified receipt path. The readiness projection judges the resulting governed evidence artifacts, not whether the canonical default contract was globally enabled.

ADK 7.11.0 also retains `ManagedInvocationObservation` + `prepare_managed_receipt()` so a real runtime/field adapter can deterministically construct the manifest-bound receipt, authority attestation and receipt ID from explicit observed facts instead of hand-assembling JSON. This is producer ergonomics only: the prepared receipt is **not verified evidence** until the reviewed registry/signature bundle path is replayed by the managed verifier.

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

Synthetic repeated trials and fake verifier fixtures validate the state machine only; they cannot be committed as canonical runtime/field evidence. Index v5 requires cryptographic pre-registration of the complete content-addressed package before all effect-trial runs and managed observations/signatures, then campaign→comparison recomputation, portable managed signature replay of every raw receipt, exact aggregate measurement recomputation, exact candidate-bundle asset coverage, campaign trace/bundle/runtime-target coverage, and digest-bound human review.
