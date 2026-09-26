# Terminal closure

`llm-ctl terminal-closure` is the final read-only projection for the llm_agent / agent-dev-kit optimization program.

It does **not** create a new evidence authority. It aggregates the existing machine authorities:

- G9: durable Knowledge Hub reviewing-capture evidence;
- G21: `native-readiness`;
- G22: `effect-readiness`;
- the machine-readable optimization backlog.

## Commands

```bash
rtk python3 -m tools.control_plane.cli terminal-closure --root . --summary-json
rtk python3 -m tools.control_plane.cli terminal-closure --root . --require-terminal --summary-json
```

The default form exits 0 when the projection itself is valid, including the normal case where software is complete but real-world evidence is still blocked.

`--require-terminal` exits:

- 0: every backlog item is done and all domain readiness projections are terminal-ready;
- 2: software is coherent but one or more external facts are still missing;
- 1: source/projection/backlog inconsistency.

## Current closure model

Software is considered ready only when:

- the backlog has no unexpected non-terminal software item;
- native-readiness reports `software_ready=true`;
- effect-readiness reports `software_ready=true`;
- the Knowledge Hub architecture candidate is durably captured in `reviewing`, with merge + post-merge Quality evidence and no fabricated owner review.

The remaining domains are not collapsed into one authority:

### G9 — Knowledge retention

The candidate already exists on Knowledge Hub master in reviewing state. Root keeps historical handoff evidence immutable and tracks it through `reports/runtime-evidence/knowledge-retention/evidence-index.json`. Terminal completion requires a **new** indexed `llm-agent-g9-hub-owner-decision/v1` file produced after a real human Knowledge Hub owner lifecycle decision. Automation must not fill `reviewed_by`, fabricate authorization, or infer active/archive/reject.

### G21 — Runtime adapter conformance

Terminal completion requires at least one real authenticated, version-pinned direct-target discovery/load/trigger campaign, a complete typed receipt, reviewed signature/provenance, exact managed-registry binding, and pinned-ADK production-loader verification.

Source-layout probes and synthetic campaigns remain non-native evidence.

### G22 — Agent/Skill/Profile value lifecycle

Terminal completion requires real repeated-task comparison plus managed runtime/field Agent Value measurement covering every current Agent/Skill/Profile, representative success/failure/wrong-route/abstain observations, substantive retirement signals, and digest-bound per-asset owner review.

Synthetic/test-only fixtures remain software validation only.

## Authority boundary

The terminal projection:

- cannot execute a lifecycle decision;
- cannot create provider/runtime evidence;
- cannot create effectiveness evidence;
- cannot fill human owner review;
- cannot authorize a release.

Its purpose is to prevent further software work from being confused with missing external facts and to make the exact remaining actions visible in one command.

## External action queue

Each blocked terminal item carries a durable `external_tracking` entry in the optimization backlog. `terminal-closure` validates that routing and emits it as `tracking_issue` in both the open backlog projection and the external blocker queue, including a normalized GitHub issue URL.

Current queue:

- G9 → `jiying2007/knowledge-hub#125`: real human Knowledge Hub lifecycle decision;
- G21 → `jiying2007/agent-dev-kit#153`: authenticated version-pinned native conformance campaign;
- G22 → `jiying2007/llm_agent#154`: governed real effect/value campaign and per-asset owner review.

These issue references are routing metadata only. Their existence does not count as lifecycle, native-runtime, effect/value, owner-review, or release evidence.

## G9 owner decision evidence

The knowledge-retention index deliberately separates historical capture evidence from the future owner decision:

```json
{
  "schema": "llm-agent-knowledge-retention-evidence-index/v1",
  "status": "active",
  "handoff": {
    "path": "reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json",
    "git_blob_sha1": "<git blob id>"
  },
  "owner_decision": null
}
```

After the Hub owner has actually reviewed the item, create a **new** Root evidence file under the same runtime-evidence directory and update `owner_decision` to its path + Git blob SHA-1. The decision document must use `llm-agent-g9-hub-owner-decision/v1`, record a real reviewer, exact Hub revision, one lifecycle decision (`activate`, `continue-reviewing`, `archive`, or `reject`), and keep `automation_generated=false`, `raw_content_stored=false`, `release_authorized=false`.

Do not modify the dated handoff evidence to simulate a later owner review.

A recorded `continue-reviewing` decision is valid owner evidence but intentionally keeps G9 blocked. Only `activate`, `archive`, or `reject` is a terminal lifecycle decision for `--require-terminal`.
