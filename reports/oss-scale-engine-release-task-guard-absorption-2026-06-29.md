# scale-engine Release And Task Guard Absorption

Date: 2026-06-29
Source: `scale-engine/` local reference repo at `60f3827`
Target: `agent-dev-kit`
Mode: method-only, no external runtime adoption

## Source Summary

Reviewed the already tracked `scale-engine` reference after earlier loop readiness, governance contract, and tool/skill evidence absorption.

Focused source areas:

- `scale-engine/docs/RELEASE_READINESS.md`
- `scale-engine/docs/TASK_GUARD_WORKFLOW_DEMO.md`
- `scale-engine/docs/ACTIVE_SECURITY_VISUAL_GATES.md`
- `scale-engine/docs/ENGINEERING_STANDARDS.md`

## Decisions

| Candidate | Decision | Local Landing |
|---|---|---|
| Completion guard payload | adopt | `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md`; `agent-dev-kit/workflows/adk-delivery-gate/WORKFLOW.md` |
| Release readiness demo + real project smoke | adopt | `agent-dev-kit/workflows/release-hardening/WORKFLOW.md` |
| Active security and visual runtime | reject | Keep as report-only vocabulary only; do not enable probes, browsers, VLM, server startup, or external runtime |
| Engineering standards runtime scanner | reject | Existing ADK gates cover standards through local scripts and review; no `scale standards` runtime import |

## Absorbed Rules

- A completion claim for medium/high risk work is blocked unless a structured guard payload records required checks, command results, evidence paths, verifier and freshness.
- Release readiness must include package or artifact dry-run, demo/fixture closure, one real project or fixture smoke, runtime artifact exclusion and explicit residual risk.
- Third-party release metadata sync and token-bearing operations stay local and explicit; they are not moved into generic CI or ADK defaults.

## Rejected Runtime Surfaces

- `scale` CLI, npm scripts and package install.
- Shield hooks, orchestrator daemon, dashboard, MCP connectors and browser/visual runtime.
- Active red-team probing, VLM review and external token synchronization.

## Validation Plan

- `rtk bash agent-dev-kit/scripts/validate-assets.sh --strict`
- `rtk bash agent-dev-kit/tests/run_all.sh`
- `rtk bash scripts/check-adk-target-evidence.sh .`
- `rtk bash scripts/check-adoption-matrix-structured.sh .`
