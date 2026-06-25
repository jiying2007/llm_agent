# OSS Absorption Plan: hongmaple/scale-engine

> Date: 2026-06-24
> Status: partial-adopt, active-reference, report-only runtime
> Source: https://gitee.com/hongmaple/scale-engine
> Analysis: `reports/oss-analysis-hongmaple-scale-engine-2026-06-24.md`
> Security review: `reports/oss-security-review-hongmaple-scale-engine-2026-06-24.md`
> Deep assessment: `reports/oss-deep-assessment-hongmaple-scale-engine-2026-06-25.md`
> Candidate ledger: `reports/oss-discovery-candidates-2026-06-24.jsonl`
> Score report: `reports/oss-score-report-2026-06-24.md`

## Decision Table

| Candidate idea | Decision | Reason | Local change |
|---|---|---|---|
| Treat external governance repos as executable gates and evidence rather than prompt text | archive-only | ADK and root gates already follow this principle | none |
| Copy `.scale/` governance packs or role skills into ADK | reject | Duplicates local skill/workflow governance and would add drift | none |
| Adopt SCALE hook/shield/orchestrator runtime | reject | External hooks and autonomous orchestration need separate security and runtime review | none |
| Adopt context budget compiler concepts | archive-only | `adk-token-context-governance` and local token-budget gates already exist | none |
| Add provider-neutral manual URL handling for OSS intake | adopt | Current `user-provided-url` source was constrained by GitHub URL assumptions | update discovery, ledger validation, docs, fixtures, tests |
| Ensure every manual external URL has an explicit next review step | adopt | SCALE's useful practice is making skipped/unscored states visible with evidence and next action | queue manual URL candidates into scoped L1 `candidate-review` |
| Track `scale-engine` as a reference upstream | adopt | User selected it for continuous tracking; value is high enough as governance runtime signal | keep Gitee repo as root-local reference and add governance registry/lifecycle/adoption records |
| Add runtime-evidence-style metadata for root-local references | adapt | SCALE's Runtime Evidence principle maps well to local root-level reference repos that are not represented by `.gitmodules` | require source URL, provider, branch, commit, retrieved date, runtime boundaries, and linked reports in `subrepo_lifecycle.json` |
| Require deep assessment for root-local references | adapt | Deep, long-lived reference sources should not stay active on discovery/security reports alone | link `reports/oss-deep-assessment-*.md` and validate it from `check-oss-intake-ledger.sh` |
| Adopt harness/loop readiness evidence model | adapt | DiagnosticLoop and AgentLoopReadiness are useful as local report-only evidence contracts, while upstream autonomous runtime remains out of scope | add `manifests/loop_readiness_contracts.json`, `scripts/check-loop-readiness.sh`, and `reports/oss-loop-readiness-hongmaple-scale-engine-2026-06-25.md` |
| Adopt progressive governance and resource lifecycle contracts | adapt | The risk-mode and resource-policy ideas strengthen local checks without requiring `.scale/` runtime state | add `manifests/scale_engine_governance_contracts.json`, `scripts/check-scale-engine-governance.sh`, and `reports/oss-governance-contracts-hongmaple-scale-engine-2026-06-25.md` |

## Implemented Improvement Set

Files changed:

| File | Purpose |
|---|---|
| `scripts/discover-oss-repos.sh` | Accept `--repo https://gitee.com/owner/repo`, preserve Gitee URL, scan local sources for GitHub/Gitee URLs |
| `scripts/check-oss-intake-ledger.sh` | Validate ledger URLs from `github.com` or `gitee.com` for the same `owner/name` repo key |
| `fixtures/oss-intake/pass/gitee-discovered.jsonl` | Positive Gitee ledger fixture |
| `fixtures/oss-intake/discovery-source.md` | Local source fixture with a Gitee URL |
| `tests/test_oss_discovery.sh` | End-to-end coverage for manual Gitee URL and source-file Gitee URL |
| `scripts/generate-oss-intake-approval-queue.sh` | Queue explicit manual URL ledgers as scoped L1 metadata-review items instead of silently leaving them unreviewed |
| `tests/test_oss_approval_queue.sh` | Covers Gitee manual URL candidate review queue generation |
| `docs/runbooks/oss-intake-lifecycle.md` | Clarify GitHub/Gitee manual URL boundary |
| `scripts/README.md` | Document manual Gitee URL discovery |
| `docs/llm-agent-maintenance-guide.md` | Update minimal validation guidance |
| `reports/oss-discovery-candidates-2026-06-24.jsonl` | Report-only candidate record for `hongmaple/scale-engine` |
| `reports/oss-score-report-2026-06-24.md` | Report-only scoring summary, unscored because manual Gitee metadata is not enriched |
| `reports/oss-intake-approval-queue-hongmaple-scale-engine-2026-06-24.json` / `.md` | Scoped L1 review queue for `hongmaple/scale-engine` metadata enrichment |
| `reports/oss-deep-assessment-hongmaple-scale-engine-2026-06-25.md` | Deep architecture/runtime assessment and absorption decision matrix |
| `reports/oss-governance-contracts-hongmaple-scale-engine-2026-06-25.md` | Progressive governance and resource lifecycle mapping |
| `reports/oss-loop-readiness-hongmaple-scale-engine-2026-06-25.md` | Harness/loop readiness mapping for DiagnosticLoop, AgentLoopReadiness and failure replay fields |
| `manifests/loop_readiness_contracts.json` | Report-only loop readiness contract derived from scale-engine harness/loop ideas |
| `manifests/scale_engine_governance_contracts.json` | Report-only governance mode and resource lifecycle contract derived from scale-engine |
| `scripts/check-loop-readiness.sh` | Offline validation that the loop readiness contract, report, lifecycle and adoption evidence remain linked |
| `scripts/check-scale-engine-governance.sh` | Offline validation that progressive governance and resource lifecycle evidence remain linked |
| `scale-engine/` | Root-local reference clone of Gitee upstream at intake commit |
| `subrepos/registry.csv` | Registers `scale-engine` as `workflow-core/P1/fetch/master/observe-first` |
| `manifests/subrepo_lifecycle.json` | Marks `scale-engine` as `active-reference` with monthly review |
| `scripts/check-oss-intake-ledger.sh` | Validates root-local reference source metadata, runtime boundaries, evidence reports, and local HEAD commit |
| `subrepos/adoption-matrix.md` | Records observe/done decision and evidence |
| `AGENTS.md` | Adds `scale-engine` to the reference subrepo inventory |
| `docs/runbooks/oss-intake-lifecycle.md` | Documents the `root-local-reference` evidence contract |

## Boundaries

- Kept `scale-engine` as a root-local Gitee reference clone for continuous fetch/diff/review.
- Registered `scale-engine` in the governed reference inventory, lifecycle manifest, and adoption matrix.
- Added source metadata and runtime boundaries to the lifecycle entry so the root-local reference remains auditable without a `.gitmodules` entry.
- Did not execute `npm`, `npx`, `scale`, hooks, setup, bootstrap, dashboard server, MCP connectors, orchestrators, or tests from `scale-engine`.
- Did not copy external prose, code, `.scale/`, `.claude/`, hooks, CLI adapters, role skills, or MCP configuration into ADK assets.
- Did not change `agent-dev-kit` core skills, manifests, profiles, or source-to-live assets; the loop readiness contract is held in `llm_agent` first as report-only governance.

## Verification Plan

Minimum validation for this change:

```bash
rtk tests/test_oss_discovery.sh
rtk scripts/check-oss-intake-ledger.sh . --summary-json
rtk scripts/check-oss-intake-fixtures.sh .
rtk scripts/check-doc-sync.sh .
```

Broader check if preparing commit:

```bash
rtk scripts/check-all.sh --quick
```

## Follow-Up

Potential future work, not part of this absorption:

| Item | Condition |
|---|---|
| Gitee metadata enrichment | Only if multiple Gitee URLs recur and a read-only API contract is reviewed |
| Provider field in candidate schema | Only if ledger consumers need to distinguish mirrors from canonical sources |
| Security review of SCALE hook/orchestrator ideas | Only if a concrete local runtime connector proposal exists |
