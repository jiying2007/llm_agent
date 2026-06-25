# OSS Analysis: hongmaple/scale-engine

> Date: 2026-06-24
> Status: analyzed, report-only
> Source: https://gitee.com/hongmaple/scale-engine
> Local snapshot: `/tmp/scale-engine`

## Source Summary

`scale-engine` is an AI-agent engineering governance CLI. Its public README positions the project as executable workflow gates, evidence files, verification profiles, context budgets, role routing, adapters, dashboard surfaces, and ship/review controls for agent-driven engineering work.

Read status:

| Source | Status | Evidence |
|---|---|---|
| Gitee repository page | read | stars=28, forks=8, commits=235 on page; branch `master`; clone URL visible |
| Shallow clone | read-only local clone | `/tmp/scale-engine` |
| README/package/workflow docs | sampled | `README.md`, `package.json`, `SCALE_POLICY.md`, `docs/AI_ENGINEERING_OS_POSITIONING.md`, `docs/CONTEXT_BUDGET.md`, `docs/workflow/README.md`, `docs/start/workflow-upgrade.md` |
| Runtime configs | sampled | `.scale/verification.json`, `.scale/skills.json`, `.scale/tools.json` |

Repository signals from local snapshot:

| Signal | Observation |
|---|---|
| Language and package | TypeScript ESM package, npm binary `scale`, Node >= 20 |
| Version | `package.json` version `0.51.0`; Gitee page observed earlier rendered README badge `0.48.0`, so page cache and clone differ |
| License | `LICENSE` file is MIT; Gitee sidebar reported unknown license |
| Test surface | `tests/` contains broad CLI/runtime/workflow/context/agent/dashboard tests |
| Install surface | npm/npx oriented; bootstrap/setup commands can involve external capability checks and optional installs, so no install command was executed |

## Local Fit

Relevant local ADK capabilities already cover much of the same space:

| SCALE mechanism | Existing local counterpart | Decision |
|---|---|---|
| Verification profiles and evidence store | `adk-verification-before-completion`, `check-all.sh`, evidence bundle gates | archive-only, no duplicate asset |
| Context budget and progressive loading | `adk-token-context-governance`, `check-token-budget.sh` | archive-only, no duplicate asset |
| Worktree/session/multi-agent coordination | `adk-worktree-governance`, `adk-parallel-agent-governance`, `codex-parallel-collab` | archive-only |
| Setup/upgrade check-plan-apply | `~/codex` source-to-live chain and apply dry-run gates | archive-only |
| Provider-neutral manual URL intake | current OSS intake was GitHub-biased | adopt small improvement |
| Every unscored/manual candidate has visible next action | manual URL candidates could remain discovered without a scoped review queue | adopt small improvement |
| Hook/shield/orchestrator runtime | external command and hook surface, requires deeper security review | reject for now |

## Duplicate And Conflict Check

Commands used for local comparison:

```bash
rtk rg -n "context budget|context-budget|budget|verification profile|evidence store|evidence-required|Gitee|github.com/<repo>|url must match|source .*gitee|allowed_source|user-provided-url|generic|provider" scripts manifests docs agent-dev-kit -S
```

Findings:

- `agent-dev-kit` already has token-context governance, verification-before-completion, worktree governance, planning recovery, runtime policy gates, and security/supply-chain runbooks.
- Root `scripts/discover-oss-repos.sh` and `scripts/check-oss-intake-ledger.sh` had a narrower provider model: manual candidates were accepted as `owner/name`, but ledger URL validation was hardcoded to GitHub.
- Root `scripts/generate-oss-intake-approval-queue.sh` queued explicit GitHub metadata candidates, but manual URL candidates did not get a scoped L1 review item explaining metadata enrichment and blocked actions.
- `manifests/oss_discovery_sources.json` already had `user-provided-url`, so the smallest fix is to honor that source for supported manual URLs rather than introduce a new parallel intake system.

## Security And Supply-Chain Notes

No third-party install, npm script, hook, MCP server, browser automation, dashboard server, or external bootstrap command was executed.

Risk observations:

| Risk | Impact | Handling |
|---|---|---|
| npm/npx install surface | Would execute external package code if adopted directly | not executed; report-only |
| Hook/shield commands | Could intercept local tool usage | not adopted |
| Optional browser/Playwright and dashboard dependencies | Larger dependency and runtime surface | not adopted |
| Gitee page license mismatch | Sidebar unknown but LICENSE is MIT | record as metadata discrepancy |

## Analysis Result

The repository is useful as a reference for executable governance, but most of its core ideas are already represented locally. The practical gaps found during this intake are provider-neutral OSS candidate handling and explicit review-state visibility for manual external URLs. The adopted changes are limited to report-only Gitee/manual URL support and scoped L1 candidate-review queue generation, with tests and docs.

Initial analysis did not register a governed reference source, update `adoption-matrix.md`, import ADK core assets, run npm install, or execute source-to-live apply. After the user selected continuous tracking, `scale-engine` was promoted separately as a root-local reference clone with registry, lifecycle, adoption, and security evidence.
