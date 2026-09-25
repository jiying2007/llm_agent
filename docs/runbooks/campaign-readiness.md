# Campaign readiness projection

`llm-ctl campaign-readiness` is a read-only projection over existing Root and ADK authorities. It creates no registry, receipt, qualification or runtime state.

```bash
rtk llm-ctl campaign-readiness --root . --summary-json
rtk llm-ctl campaign-readiness --root . --require-adk-worktree --gate software --summary-json
```

The projection separates three questions:

- **software_status**: are the repeated-effect and managed-native-trust software contracts present in the exact pinned ADK worktree?
- **campaign evidence**: has real external execution evidence been supplied? Missing real tasks/runtime/model/native receipts remains `external-input-required`.
- **product_authority**: current-source release authorization continues to come only from the existing status/qualification projection.

The CI gate is deliberately **software-only**. Missing real model/native evidence does not block ordinary source integration, but the projection keeps those blockers visible and never labels them PASS.

## Effect lane (G22)

Software readiness requires the pinned ADK repeated-trial schemas, implementation and runbook. Once ready, the next real action remains an external campaign:

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval compare-trials \
  --input /absolute/evidence/campaign.json \
  --output /absolute/evidence/comparison.json \
  --summary-json
```

The readiness projection does not read or persist raw prompts, messages, credentials or task payloads. It therefore reports real effect evidence as `external-input-required` until a separately governed review consumes that external comparison.

## Native lane (G21)

Software readiness requires the native receipt schema, managed trust registry, verifier implementation and runbook. The projection reports the number of enabled managed authorities and repository target conformance levels.

An empty registry or no runtime-certified target remains a blocker. Source-layout probes and static target checks do not satisfy native evidence.

## Exit semantics

- no `--gate`: 0 when the projection itself is valid, even if external evidence is still missing;
- `--gate software`: 0 only when both effect/native software foundations are available from the exact pinned ADK worktree; 2 when software prerequisites are incomplete;
- malformed/missing authoritative source: 1.

There is intentionally no automatic evidence/product gate here. Real campaign evidence and current-source product authorization remain independent authorities.
