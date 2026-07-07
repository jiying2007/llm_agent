# OpenAI Codex Practice Hardening - 2026-07-07

## Scope

This report records the 2026-07-07 landing of incremental official OpenAI/Codex practices into `agent-dev-kit` governance assets.

Sources were read through the refreshed Codex manual cache:

| Source ID | Official URL | Retrieved | Decision |
|---|---|---:|---|
| `openai-codex-record-and-replay` | https://developers.openai.com/codex/record-and-replay | 2026-07-07 | adopt as replayable evidence bundle governance |
| `openai-codex-appshots` | https://developers.openai.com/codex/appshots | 2026-07-07 | adopt as UI/App evidence boundary |
| `openai-codex-noninteractive` | https://developers.openai.com/codex/noninteractive | 2026-07-07 | adopt as runner smoke evidence governance |
| `openai-codex-best-practices` | https://developers.openai.com/codex/learn/best-practices | 2026-07-07 | extend existing goal/done-when eval fixtures |
| `openai-codex-app-automations` | https://developers.openai.com/codex/app/automations | 2026-07-07 | extend existing automation risk fixtures |
| `openai-codex-app-worktrees` | https://developers.openai.com/codex/app/worktrees | 2026-07-07 | extend existing worktree risk fixtures |
| `openai-codex-subagents-runtime` | https://developers.openai.com/codex/subagents | 2026-07-07 | extend existing context hygiene gate |

## Decisions

| Practice | Decision | Landing |
|---|---|---|
| Record & Replay demonstrated workflow promotion | adopt | `manifests/trace_eval_contracts.json` adds `replayable-run-evidence-bundle-v1` |
| Goal / Context / Constraints / Done-when task framing | adopt | `manifests/eval_suites.json` adds `completion-eval-goal-done-when-negative-fixtures` |
| Automation and worktree unattended-risk handling | adopt | `manifests/automation_worktree_contracts.json` adds risk fixtures and gates |
| Appshots UI evidence boundary | adopt | `manifests/external_agent_pattern_contracts.json` adds Appshots capture fields |
| Subagent summary-first context hygiene | adopt | `manifests/subagent_contracts.json` adds `context_noise_budget` |
| Programmatic runner smoke evidence | adopt | `manifests/adk_runner_contracts.json` adds `adk-runner-smoke-contract-v1` |
| Computer Use, browser runtime, hosted tools, generated skills | reject for this landing | No runtime, connector, Computer Use, browser automation, hosted tool or external write behavior was enabled |
| Model recommendation changes | reject for this landing | Existing model-selection freshness gates remain unchanged |

## Changed Assets

- `agent-dev-kit/manifests/official_docs_freshness_gates.json`
- `agent-dev-kit/manifests/trace_eval_contracts.json`
- `agent-dev-kit/manifests/eval_suites.json`
- `agent-dev-kit/manifests/automation_worktree_contracts.json`
- `agent-dev-kit/manifests/subagent_contracts.json`
- `agent-dev-kit/manifests/adk_runner_contracts.json`
- `agent-dev-kit/manifests/external_agent_pattern_contracts.json`
- `agent-dev-kit/scripts/check-openai-developers-governance.sh`
- `agent-dev-kit/scripts/check-external-agent-patterns.sh`
- `agent-dev-kit/docs/reference/openai-developers-reference.md`
- `agent-dev-kit/docs/reference-adoption-matrix.md`
- `subrepos/adoption-matrix.md`
- `subrepos/adoption-matrix.jsonl`

## Verification Plan

Required checks:

- `rtk bash agent-dev-kit/scripts/check-openai-developers-governance.sh --summary-json`
- `rtk bash agent-dev-kit/scripts/check-external-agent-patterns.sh`
- `rtk bash agent-dev-kit/tests/test_openai_developers_governance.sh`
- `rtk scripts/check-all.sh --quick`

## Phase Gate Review

- `phase=fallback-sunset` remains active.
- `allow_upstream_sync=yes` remains unchanged.
- `next_review_by` is moved from 2026-07-06 to 2026-07-14 because the review window expired on 2026-07-07 and this landing revalidated the OpenAI/Codex governance direction.
- `last_live_refresh` is updated from 2026-06-28 to 2026-07-07 after source-to-live validation and apply completed.

Source-to-live evidence:

- `rtk bash ~/codex/scripts/build.sh`
  - `[DONE] build profile=team-collab output=/home/leiwenjun/codex/build/codex-home managed=749`
- `rtk bash ~/codex/scripts/doctor.sh --scope all`
  - `scope=repo/build/live`, `PROFILE=team-collab`, `errors=0 warnings=0`
- `rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json`
  - `summary={'copy': 0, 'keep': 481, 'overwrite': 0, 'delete': 0, 'mkdir': 270, 'skip': 0}`
- `rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run`
  - `summary={'copy': 0, 'keep': 481, 'overwrite': 0, 'delete': 0, 'mkdir': 270, 'skip': 0} dry_run=1`
- `rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json`
  - `summary={'copy': 0, 'keep': 481, 'overwrite': 0, 'delete': 0, 'mkdir': 270, 'skip': 0} dry_run=0`
- `rtk bash ~/codex/scripts/check-routing-precedence.sh`
  - `default_profile=team-collab superpowers_skills=13 active_superpowers_in_default=0`
- `rtk bash ~/codex/scripts/check.sh`
  - `[DONE] check`, `status=ok changed=0 stale=0 unmanaged=0`

## Boundaries

- This landing does not rewrite ADK lifecycle or routing.
- This landing does not make OpenAI runtime, SDK, Computer Use, Appshots, browser automation, hosted tools or external MCP a default dependency.
- This landing does not enable unattended automations, writes, commits, pushes, publishes or external notifications.
- This landing keeps official model recommendations behind existing freshness gates.
