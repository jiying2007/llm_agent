# OSS Governance Contracts Absorption: hongmaple/scale-engine

> Date: 2026-06-25
> Source: `https://gitee.com/hongmaple/scale-engine`
> Local path: `scale-engine/`
> Snapshot commit: `60f38279b76030056738cc9eac7bc8b9cc6173c2`
> Status: adapted, report-only, runtime-disabled

## Scope

This report absorbs two low-risk governance ideas from `scale-engine`: progressive governance mode selection and resource lifecycle classification. It keeps both as local contracts and validation evidence, not as upstream runtime execution.

## Source Inventory

| Source | Read status | Absorption use |
|---|---|---|
| `scale-engine/src/governance/ProgressiveGovernance.ts` | direct local read | risk signals, mode escalation, required behaviors |
| `scale-engine/docs/CONTEXT_BUDGET.md` | direct local read | progressive governance framing and ROI boundary |
| `scale-engine/docs/RESOURCE_GOVERNANCE.md` | direct local read | resource types, default Git policy, task artifact boundary |
| `scale-engine/docs/UPGRADE_MANAGEMENT.md` | direct local read | check-plan-apply upgrade boundary and third-party capability review |
| `scale-engine/docs/TOOL_ORCHESTRATION.md` | direct local read | required/recommended tool evidence and fallback recording |

## Absorption Decisions

| Candidate | Decision | Local landing | Boundary |
|---|---|---|---|
| Progressive governance modes | adopt | `minimal`, `standard`, `expanded`, `critical` mode contract with risk signals and required behaviors | no automatic permission changes |
| Resource lifecycle classes | adopt | canonical doc, decision record, contract, reusable script, task artifact, evidence report, generated media, temporary policy | no `.scale/assets.json`, no directory migration |
| Tool evidence fallback table | adapt | required tool/skill evidence must record used, skipped, fallback, and evidence path in future task artifacts | no auto tool execution |
| Upgrade check-plan-apply | archive-only | useful framing for source-to-live and third-party asset updates | no SCALE upgrade runner |
| Governance ROI | archive-only | keep measured/estimated/missing vocabulary for future evidence reports | no ROI scoring until local data exists |

## Progressive Governance Contract

| Mode | Trigger examples | Required behavior |
|---|---|---|
| `minimal` | low-risk docs-only work | run relevant validation only |
| `standard` | normal implementation or verification work | record verification evidence; summarize context budget |
| `expanded` | cross-module, UI/browser/E2E, public API, schema, SDK or breaking behavior | add impact analysis or explain fallback; collect browser/visual evidence when applicable |
| `critical` | auth, permissions, secrets, database, migration, production, release, destructive action | run security review; record rollback/disable strategy; require human review for destructive/data/auth/production changes |

The local mapping is deliberately conservative: a lower requested mode cannot suppress a higher detected risk signal.

## Resource Lifecycle Contract

| Resource type | Default Git policy | Lifecycle | Local interpretation |
|---|---|---|---|
| `canonical-doc` | commit | maintained | project truth that needs owner/review freshness |
| `decision-record` | commit | immutable | decision evidence; append/supersede rather than silently rewrite |
| `contract` | commit | maintained | API/schema/workflow/manifest contract |
| `reusable-script` | commit | maintained | stable script with validation and documented entrypoint |
| `task-artifact` | review | task-scoped | planning, reality check, cleanup, verification notes |
| `evidence-report` | ignore-or-review | generated | raw or generated evidence; promote only curated summaries |
| `generated-media` | review-or-external | generated | screenshots, videos, HTML, graph outputs, binary artifacts |
| `temporary` | ignore | temporary | scratch outputs and local-only probes |

## Concrete Local Assets

| Asset | Purpose |
|---|---|
| `manifests/scale_engine_governance_contracts.json` | Report-only progressive governance and resource lifecycle contract |
| `scripts/check-scale-engine-governance.sh` | Offline validation that the manifest, report, lifecycle and adoption evidence remain linked |
| `subrepos/adoption-matrix.md` | Records the scale-engine governance contract as an adopted, done item |
| `manifests/subrepo_lifecycle.json` | Links this report to the root-local reference evidence chain |

## Runtime Boundaries

- Do not run `scale governance`, `scale assets`, `scale tool`, `scale upgrade`, `npm`, `npx`, hooks, MCP, dashboard or daemon commands from `scale-engine`.
- Do not create `.scale/` runtime state, `.scale/assets.json`, `.scale/resource-policy.json`, or upstream-generated workflow files.
- Do not auto-change sandbox, approval, permissions, tool availability, or third-party dependency policy based on this contract.

## Validation

Minimum validation for this absorption:

```bash
rtk scripts/check-scale-engine-governance.sh .
rtk scripts/check-doc-sync.sh .
rtk scripts/check-adoption-matrix-structured.sh .
rtk scripts/check-all.sh --quick
rtk git diff --check
```
