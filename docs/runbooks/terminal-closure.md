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
- G9 knowledge retention has a durable, indexed real-human lifecycle decision when the backlog marks G9 done; historical reviewing-capture evidence remains immutable and separate from that later decision.

The remaining domains are not collapsed into one authority:

### G9 — Knowledge retention

G9 is closed on current main. Root keeps the historical reviewing-capture evidence immutable and separately indexes the later real-human `llm-agent-g9-hub-owner-decision/v1` lifecycle evidence through `reports/runtime-evidence/knowledge-retention/evidence-index.json`. Automation still must not fill `reviewed_by`, fabricate authorization, or infer a lifecycle outcome.

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

- G21 → `jiying2007/agent-dev-kit#153`: authenticated version-pinned native conformance campaign;
- G22 → `jiying2007/llm_agent#154`: governed real effect/value campaign and per-asset owner review.

G9 → `jiying2007/knowledge-hub#125` is retained as closed historical routing/evidence provenance, not as a current external blocker.

These issue references are routing metadata only. Their existence does not count as lifecycle, native-runtime, effect/value, owner-review, or release evidence.

## G9 owner decision evidence

The knowledge-retention index deliberately separates the historical reviewing capture from the later owner decision. Current main indexes both immutable records:

```json
{
  "schema": "llm-agent-knowledge-retention-evidence-index/v1",
  "status": "active",
  "handoff": {
    "path": "reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json",
    "git_blob_sha1": "<historical capture blob>"
  },
  "owner_decision": {
    "path": "reports/runtime-evidence/knowledge-retention/g9-hub-owner-decision-2026-09-26.json",
    "git_blob_sha1": "<real owner-decision blob>"
  }
}
```

The owner-decision document uses `llm-agent-g9-hub-owner-decision/v1`, binds a real reviewer and exact Hub revision, and keeps `automation_generated=false`, `raw_content_stored=false`, `release_authorized=false`. The dated handoff evidence is never rewritten to simulate a later review.

For future reuse of this contract, `continue-reviewing` is valid owner evidence but non-terminal; only `activate`, `archive`, or `reject` satisfies terminal lifecycle completion.
