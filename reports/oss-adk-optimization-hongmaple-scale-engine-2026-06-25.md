# scale-engine ADK Optimization Absorption

Date: 2026-06-25
Source: `scale-engine/` local reference repo
Target: `agent-dev-kit`
Mode: method-only, report-only, no external runtime adoption

## Source Summary

This pass reviewed the already-onboarded `scale-engine` reference for ADK optimization candidates after prior loop readiness and progressive governance absorption.

Useful source areas:

- tool orchestration and skill planning evidence shape;
- memory maintenance / contradiction handling ideas;
- dependency audit command safety boundaries;
- code intelligence provider fallback and confidence reporting.

Rejected runtime surfaces:

- orchestrator, hooks, shield, dashboard or TUI runtime;
- SQLite/vector memory backend;
- dependency audit runner that installs or performs network audit by default;
- external code graph provider installation;
- active security or visual probe runtime.

## Adopted Changes

| Candidate | Decision | Local Landing |
|---|---|---|
| Tool / Skill Evidence Plan | adopt | `agent-dev-kit/manifests/tool_skill_evidence_contracts.json`; `scripts/check-adk-tool-skill-evidence-contracts.sh`; `adk-runtime-router`; `adk-verification-before-completion` |
| Memory maintenance report | adopt | `adk-memory-curator`; `templates/memory/memory-candidate.md`; `docs/runbooks/memory-governance.md` |
| Verification command safety | adopt | `docs/runbooks/security-supply-chain.md`; `optional-skills/adk-security-supply-chain`; contract manifest |
| Code intelligence fallback contract | adopt | `adk-token-context-governance`; contract manifest |

## Implementation Notes

- The new contract keeps all capabilities platform-neutral and report-only.
- Tool fallback and skipped skills now require evidence instead of being treated as success.
- Memory promotion now has explicit `promotion_candidates`, `contradictions`, `missing_evidence` and `contradiction_status` fields.
- External verification commands remain data until reviewed; shell metacharacters and network dependency audit remain gated.
- Code intelligence provider output can narrow file discovery but cannot replace source reread for high-risk changes.

## Validation

| Command | Result |
|---|---|
| `rtk agent-dev-kit/scripts/check-tool-skill-evidence-contracts.sh --summary-json` | PASS |
| `rtk scripts/check-adk-tool-skill-evidence-contracts.sh .` | PASS |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS |
| `rtk agent-dev-kit/scripts/check-token-budget.sh --summary-json` | PASS |
| `rtk python3 -m json.tool agent-dev-kit/manifests/tool_skill_evidence_contracts.json` | PASS |

## Remaining Candidates

- Governance ROI vocabulary remains P2 until enough measured runtime data exists.
- Release readiness demo plus real-project smoke can be considered during the next release-hardening pass.
- Provider-backed code intelligence should stay optional until a separate supply-chain review approves an implementation.
