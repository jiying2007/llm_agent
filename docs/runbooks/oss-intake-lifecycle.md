# OSS Intake Lifecycle Runbook

> Status: P1 report-only, P2 gated registration, P3 gated removal, and P4 report-only cycle baselines active
> Last updated: 2026-06-16
> Scope: external open source repository discovery, scoring, onboarding, absorption, and removal for `llm_agent`.

## 1. Goal

`llm_agent` should operate as an open source practice radar plus controlled absorption pipeline, not as an ever-growing pile of long-lived reference subrepos.

The target state is:

1. Discover external repositories as candidates before cloning or registering them.
2. Score candidates with mechanical metadata, security signals, and ADK fit.
3. Analyze only shortlisted repositories in an isolated read-only path.
4. Absorb reusable practices into `agent-dev-kit` as small, verified assets.
5. Automatically register high-confidence candidates only after gates pass.
6. Automatically remove low-value subrepos only after evidence, rollback, and reference checks pass.

This runbook defines the end state. It does not imply that the future scripts listed here already exist.

## 2. Lifecycle States

Every external repository or repository-like source must have exactly one lifecycle state.

| State | Meaning | Allowed automatic action |
|---|---|---|
| `discovered` | Found by search, article, report, or user URL. | Record candidate only. |
| `scored` | Metadata and risk scoring completed. | Promote to watch or reject. |
| `quarantined` | Cloned or mirrored into an isolated candidate path. | Read-only analysis only. |
| `analyzed` | Analysis report exists with fit, duplication, risk, and proposed decision. | Produce decision record. |
| `watch` | Worth watching, not worth registering yet. | Refresh metadata only. |
| `onboard-candidate` | Meets automatic registration threshold, pending gates. | Register only if all onboarding gates pass. |
| `active-core` | Core reference source. | Fetch and diff on scheduled cycles. |
| `active-reference` | Lower-frequency reference source. | Fetch only when review window opens. |
| `archive-only` | Value has been absorbed or preserved as a report. | No sync; eligible for removal. |
| `disabled` | Retained in records but no longer synchronized. | No sync; eligible for removal. |
| `removed` | Removed from submodule tracking with rollback record. | No automatic action. |
| `rejected` | Explicitly rejected with reason. | No automatic action. |

State transitions must be monotonic unless a report records why the source has regained value. For example, `archive-only -> active-reference` requires a new analysis report and a passing onboarding gate.

## 3. Sources of Truth

Current governed files remain authoritative until the future manifests exist.

| File | Role |
|---|---|
| `subrepos/registry.csv` | Current subrepo registry and active/disabled status. |
| `subrepos/adoption-matrix.md` | Human-readable adoption decisions. |
| `subrepos/adoption-matrix.jsonl` | Generated low-token structured adoption view. |
| `subrepos/phase-gate.env` | Whether upstream sync is allowed. |
| `subrepos/dirty-baseline.tsv` | Known dirty observe subrepo baseline. |
| `adk.lock` | Locked `agent-dev-kit` version and gitlink. |
| `reports/` | Evidence, candidate analysis, closeout, and rollback records. |

P1-P4 governed manifests are current inputs:

| Manifest | Purpose |
|---|---|
| `manifests/oss_discovery_sources.json` | Search sources, query classes, and freshness windows. |
| `manifests/oss_candidate_scoring_policy.json` | Scoring weights and hard reject rules. |
| `manifests/subrepo_lifecycle.json` | Lifecycle state, owner, review window, and automation eligibility. |
| `manifests/oss_registration_policy.json` | P2 gated registration rules, allowed targets, and materialization modes. |
| `manifests/oss_removal_policy.json` | P3 gated removal rules, protected repositories, allowed targets, and rollback gates. |
| `manifests/oss_continuous_operation.json` | P4 report-only cycle commands, stop conditions, and approval points. |

These manifests are validated by `scripts/check-oss-intake-ledger.sh`, `scripts/check-oss-registration-plan.sh`, `scripts/check-oss-removal-plan.sh`, and `scripts/check-oss-continuous-operation.sh`. P1/P4 are report-only; P2 apply requires explicit `--apply`; P3 currently generates and validates dry-run removal plans only.

## 4. Discovery Sources

Discovery creates candidates only. It must not clone, register, absorb, install, or execute code.

Allowed discovery sources:

1. GitHub repository search using qualifiers such as topic, stars, forks, pushed date, language, license, and `archived:false`.
2. GitHub GraphQL search for structured repository metadata.
3. OpenSSF Scorecard results for security and maintenance signals.
4. User-provided URLs or local paths.
5. Existing local reports, article ledgers, and weekly diff scans.

Default candidate output:

```text
reports/oss-discovery-candidates-YYYY-MM-DD.jsonl
```

Minimum candidate fields:

```json
{
  "repo": "owner/name",
  "url": "https://github.com/owner/name",
  "source": "github-search",
  "topics": [],
  "stars": 0,
  "forks": 0,
  "pushed_at": "YYYY-MM-DD",
  "license": "unknown",
  "archived": false,
  "domain_fit": "workflow-core",
  "score": null,
  "decision": "discovered",
  "reason": "candidate created from search",
  "evidence": []
}
```

## 5. Scoring Model

Score candidates out of 100 before any registration or absorption.

| Dimension | Weight | Examples |
|---|---:|---|
| Relevance | 30 | Fits `workflow-core`, `agent-ecosystem`, `tooling`, `knowledge`, or `runtime-policy`. |
| Maintenance | 20 | Recent commits, releases, issue/PR activity, maintainer continuity. |
| Engineering quality | 15 | Tests, CI, docs, examples, versioning, stable interfaces. |
| Security and supply chain | 15 | License, SECURITY file, dependency posture, OpenSSF Scorecard, safe install surface. |
| Uniqueness | 10 | Provides a mechanism not already covered by ADK assets. |
| Adoption cost inverse | 10 | Low dependency load, small surface, easy to turn into gates, fixtures, or runbooks. |

Thresholds:

| Score | Default decision |
|---:|---|
| `>= 90` | `onboard-candidate` if hard reject rules do not apply. |
| `80-89` | `watch`; do not register automatically. |
| `65-79` | `archive-only` or `watch` only with explicit owner reason. |
| `< 65` | `rejected`. |

## 6. Hard Reject Rules

Reject a candidate before deeper analysis when any rule matches:

1. Repository is archived.
2. No clear license exists.
3. No meaningful maintenance activity for 12 months.
4. Install instructions require unreviewed remote execution, privileged system writes, or long-lived tokens.
5. The candidate duplicates an existing ADK capability without a concrete advantage.
6. The source only contains opinions or popularity claims and cannot become a verifiable gate, fixture, runbook, template, or test.
7. The candidate requires credentials, private services, or hosted infrastructure that cannot be reviewed locally.

Rejected candidates stay in the candidate ledger with the reason. Do not delete the record.

## 7. Automatic Registration Policy

Automatic registration is available as a P2 gated baseline. Default mode is dry-run. Apply mode must be explicit and must pass the registration plan gate.

A candidate may be automatically registered only when all conditions are true:

1. Score is `>= 90`.
2. Hard reject rules all pass.
3. Candidate ledger entry exists.
4. Analysis report exists.
5. Duplicate and conflict checks pass.
6. Security and supply-chain review passes.
7. `subrepos/phase-gate.env` allows upstream intake.
8. The generated onboarding plan lists registry, submodule, adoption-matrix, and rollback changes.

Automatic registration may update only:

1. `subrepos/registry.csv`
2. `.gitmodules`
3. `subrepos/adoption-matrix.md`
4. `subrepos/adoption-matrix.jsonl`
5. `manifests/subrepo_lifecycle.json`
6. `reports/oss-analysis-<repo>-YYYY-MM-DD.md`
7. `reports/oss-onboarding-plan-<repo>-YYYY-MM-DD.{json,md}`

Automatic registration must not change `agent-dev-kit` core assets. Absorption into `agent-dev-kit` is a separate gated phase. P2 `--apply` defaults to `metadata-only`; `local-submodule` materialization requires a local reviewed clone or mirror through `--submodule-source`.

## 8. Automatic Removal Policy

Automatic removal is available as a P3 gated plan baseline. Current scripts generate and validate dry-run removal plans; they do not delete subrepos, edit gitlinks, or rewrite `.gitmodules`.

A subrepo may be automatically removed only when all conditions are true:

1. Lifecycle state is `archive-only` or `disabled`.
2. The repository is not `agent-dev-kit`.
3. The repository is not `active-core`.
4. Value has already been absorbed or explicitly rejected in `subrepos/adoption-matrix.md`.
5. No active evidence row depends on files inside the subrepo.
6. `subrepos/dirty-baseline.tsv` can be updated without hiding unrelated dirty state.
7. Removal plan exists with rollback commands and expected post-removal checks.
8. A pre-removal `scripts/check-all.sh --quick` run passes.

Future removal apply must update:

1. `.gitmodules`
2. gitlink tracking
3. `subrepos/registry.csv`
4. `subrepos/dirty-baseline.tsv`
5. docs or reports that describe active subrepos
6. `reports/subrepo-removal-plan-<repo>-YYYY-MM-DD.md`

Removal apply remains blocked until a separate reviewed implementation exists. Any future apply must be rolled back if a post-removal gate fails and cannot be fixed within the same change.

## 9. Absorption Policy

Absorption converts external practice into local ADK assets. It is not content copying.

Default decisions:

| Situation | Decision |
|---|---|
| Existing ADK asset covers the idea | `MERGE` into the existing asset. |
| Idea is useful but not ready for assets | `ARCHIVE_ONLY`. |
| Idea is high value and verifiable | `ADOPT`. |
| Idea is duplicate or unsafe | `REJECT`. |
| Source is promising but immature | `WATCH`. |

Rules:

1. Prefer enhancing existing `agent-dev-kit` skills, workflows, manifests, fixtures, tests, or docs.
2. Add a new asset only when reuse would make the existing asset unclear or overloaded.
3. Do not copy third-party prose into core docs.
4. Do not copy third-party code into `agent-dev-kit` without a separate security and license review.
5. Do not execute third-party install commands during discovery or analysis.
6. Treat `scripts/auto-absorb.sh` as legacy/report-only inspiration. It is not the target-state write path.

## 10. Required Artifacts

Each stage must leave an auditable artifact.

| Stage | Artifact |
|---|---|
| Discovery | `reports/oss-discovery-candidates-YYYY-MM-DD.jsonl` |
| Scoring | `reports/oss-score-report-YYYY-MM-DD.md` |
| Analysis | `reports/oss-analysis-<repo>-YYYY-MM-DD.md` |
| Absorption decision | `reports/oss-absorption-plan-<repo>-YYYY-MM-DD.md` |
| Registration | adoption matrix row plus registry update evidence |
| Removal | `reports/subrepo-removal-plan-<repo>-YYYY-MM-DD.md` |
| Verification | command list with exit codes and result summaries |

## 11. P1 Report-Only Commands

Current P1 commands are offline and report-only:

```bash
rtk scripts/check-oss-intake-ledger.sh .
rtk scripts/check-oss-intake-ledger.sh . --summary-json
rtk scripts/check-oss-intake-ledger.sh . --no-fixtures --fixture reports/oss-discovery-candidates-2026-06-16.jsonl
rtk scripts/score-oss-candidates.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --out reports/oss-score-report-2026-06-16.md
rtk tests/test_oss_intake_ledger.sh
```

Current P1 artifacts:

| Artifact | Role |
|---|---|
| `fixtures/oss-intake/pass/*.jsonl` | Positive candidate ledger examples. |
| `fixtures/oss-intake/fail/*.jsonl` | Negative candidate ledger examples. |
| `reports/oss-discovery-candidates-2026-06-16.jsonl` | Example report-only candidate ledger. |
| `reports/oss-score-report-2026-06-16.md` | Example generated score report. |

`score-oss-candidates.sh` generates a Markdown summary from local scored JSONL records. It does not calculate remote scores, fetch metadata, or promote candidates. `onboard-candidate` means eligible for a later gated onboarding review, not automatic registration.

## 12. P2 Gated Registration Commands

Current P2 commands are offline and gated:

```bash
rtk scripts/check-oss-registration-plan.sh .
rtk scripts/onboard-oss-candidate.sh . --ledger reports/oss-discovery-candidates-2026-06-16.jsonl --repo example/runtime-policy-gates --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md
rtk tests/test_oss_registration_plan.sh
```

Current P2 artifacts:

| Artifact | Role |
|---|---|
| `fixtures/oss-intake/registration/pass/*.json` | Positive registration plan examples. |
| `fixtures/oss-intake/registration/fail/*.json` | Negative registration plan examples. |
| `reports/oss-onboarding-plan-example-runtime-policy-gates-2026-06-16.{json,md}` | Example dry-run onboarding plan. |

`onboard-oss-candidate.sh` writes a dry-run plan by default. `--apply` is intentionally separate from scoring and analysis. Metadata-only apply updates governance files; local submodule materialization requires `--materialization local-submodule --submodule-source <local-path>`.

## 13. P3 Gated Removal Commands

Current P3 commands are offline and gated:

```bash
rtk scripts/check-oss-removal-plan.sh .
rtk scripts/plan-oss-subrepo-removal.sh . --repo codex
rtk tests/test_oss_removal_plan.sh
```

Current P3 artifacts:

| Artifact | Role |
|---|---|
| `fixtures/oss-intake/removal/pass/*.json` | Positive removal plan examples. |
| `fixtures/oss-intake/removal/fail/*.json` | Negative removal plan examples. |
| `reports/subrepo-removal-plan-codex-2026-06-16.{json,md}` | Example dry-run removal plan. |

`plan-oss-subrepo-removal.sh` writes a dry-run plan for repositories already in `archive-only` or `disabled` lifecycle state. `--apply` is intentionally blocked in this baseline.

## 14. P4 Continuous Operation Commands

Current P4 commands are offline and report-only:

```bash
rtk scripts/check-oss-continuous-operation.sh .
rtk scripts/run-oss-intake-cycle.sh .
rtk tests/test_oss_continuous_operation.sh
```

Current P4 artifacts:

| Artifact | Role |
|---|---|
| `fixtures/oss-intake/continuous/pass/*.json` | Positive cycle report examples. |
| `fixtures/oss-intake/continuous/fail/*.json` | Negative cycle report examples. |
| `reports/oss-intake-cycle-2026-06-16.{json,md}` | Example report-only cycle output. |

`run-oss-intake-cycle.sh` only runs local ledger, registration, and removal gates, then writes cycle reports. It must not fetch network data, register candidates, remove subrepos, absorb into ADK, or apply to `~/codex`/`~/.codex`. Fixture tests stay in `check-oss-intake-fixtures.sh` to avoid recursive cycle execution.

## 15. Future Script Interfaces

These are target-state interfaces. Do not reference them as currently available commands until implemented.

```text
scripts/discover-oss-repos.sh --dry-run
scripts/analyze-oss-repo.sh
scripts/decide-oss-intake.sh
scripts/prune-subrepo-candidates.sh
```

Expected behavior:

| Future command | Behavior |
|---|---|
| `discover-oss-repos.sh --dry-run` | Generate candidate JSONL only. |
| `analyze-oss-repo.sh` | Produce a local analysis report without modifying ADK assets. |
| `decide-oss-intake.sh` | Emit `WATCH`, `ARCHIVE_ONLY`, `MERGE`, `ADOPT`, `ONBOARD_SUBREPO`, or `REJECT`. |
| `prune-subrepo-candidates.sh` | Generate removal candidates or removal plans. |

## 16. Gates

Current commands for existing workflows:

```bash
rtk scripts/check-oss-intake-ledger.sh .
rtk scripts/check-oss-registration-plan.sh .
rtk scripts/check-oss-removal-plan.sh .
rtk scripts/check-oss-continuous-operation.sh .
rtk scripts/check-oss-intake-fixtures.sh .
rtk scripts/check-phase-gate.sh .
rtk scripts/check-subrepo-state.sh .
rtk scripts/check-authorized-subrepos.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-adoption-matrix-status.sh .
rtk scripts/check-adoption-matrix-structured.sh .
rtk tests/test_oss_intake_ledger.sh
rtk tests/test_oss_registration_plan.sh
rtk tests/test_oss_removal_plan.sh
rtk tests/test_oss_continuous_operation.sh
rtk scripts/check-all.sh --quick
```

When a change touches `agent-dev-kit`, also run:

```bash
rtk bash -lc "cd agent-dev-kit && rtk bash tests/run_all.sh --fail-fast"
rtk scripts/check-adk-lock.sh .
rtk scripts/check-evidence-bundle.sh .
rtk scripts/check-all.sh --quick
```

When a future source-to-live change is requested, do not apply directly. First run the `~/codex` dry-run chain and record evidence:

```bash
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
```

## 17. Phase Plan

### P0: Document and repair governance entrypoints

1. Land this runbook.
2. Update documentation links to point new repository intake to this lifecycle.
3. Fix any phase-gate parse issues before enabling automated status checks.
4. Mark legacy direct-write absorption paths as non-target-state.

### P1: Candidate ledger and scoring

Status: implemented as an offline report-only baseline on 2026-06-16.

1. Add discovery source policy.
2. Add candidate JSONL validation.
3. Implement score report generation.
4. Keep all actions report-only.

### P2: Automatic registration

Status: implemented as an offline gated registration baseline on 2026-06-16.

1. Implement gated `onboard-candidate` promotion.
2. Require analysis, duplicate check, security review, and rollback plan.
3. Automatically update registry and adoption matrix only after gates pass.
4. Keep `agent-dev-kit` absorption separate.

### P3: Automatic removal

Status: implemented as an offline gated removal plan baseline on 2026-06-16.

1. Generate subrepo removal candidates from lifecycle state, grade, priority, and evidence usage.
2. Require removal plan and rollback path.
3. Keep apply blocked until a separately reviewed implementation exists.
4. Require rollback if future post-removal checks fail.

### P4: Continuous operation

Status: implemented as an offline report-only cycle baseline on 2026-06-16.

1. Run discovery and pruning on a scheduled report-only cadence.
2. Promote only high-confidence candidates.
3. Keep active subrepos small and valuable.
4. Prefer durable ADK assets over permanent reference repositories.
