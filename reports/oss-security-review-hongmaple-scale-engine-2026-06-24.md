# OSS Security Review: hongmaple/scale-engine

> Date: 2026-06-24
> Status: pass-for-reference-tracking
> Scope: keep `scale-engine` as an `active-reference` root-local reference for ongoing fetch/diff analysis
> Source: https://gitee.com/hongmaple/scale-engine.git
> Pinned commit at intake: `60f38279b76030056738cc9eac7bc8b9cc6173c2`

## Decision

`scale-engine` is approved as a root-local reference clone only.

Allowed:

- `git fetch` / `sync-subrepos.sh` tracking.
- Read-only analysis, diff scanning, and report-only absorption planning.
- Selective method extraction into existing ADK/root governance assets after duplicate, conflict, and validation checks.

Not allowed by this review:

- Running `npm`, `npx`, `scale`, dashboard servers, setup/bootstrap, hooks, MCP servers, or orchestrator daemons from this submodule.
- Copying `.scale/`, `.claude/`, generated hooks, CLI adapters, or role skills into `agent-dev-kit` or `~/.codex`.
- Enabling external services, provider tokens, release sync, browser automation, or local background processes.

## Evidence

| Item | Result |
|---|---|
| Source + version | Gitee submodule, commit `60f38279b76030056738cc9eac7bc8b9cc6173c2`, branch `master` |
| License | `LICENSE` present; local analysis records MIT |
| Executable file scan | `find scale-engine -type f -perm -111` returned no executable files with current checkout permissions |
| Secret scan | Keyword scan found token/secret references in docs, tests, examples, env placeholders and MCP config templates; no real credential was accepted into runtime config |
| Install surface | README/package docs include `npm`, `npx`, setup, smoke, dashboard and release-sync commands; none were executed |
| Runtime surface | Contains hook/shield/orchestrator/MCP/provider concepts; all remain report-only |
| SBOM/CVE scan | Not executed for this reference-only intake; required before any runtime/profile/core enablement |
| Signature verification | Not available; submodule commit pin and upstream URL recorded instead |
| Rollback | Remove `scale-engine` root-local reference registration, registry row, lifecycle row, adoption row and reports from the root commit |

## Risk Summary

| Risk | Level | Handling |
|---|---|---|
| Hook and shield generation can write runtime config | High | Reference-only; do not run `scale shield` or copy hooks |
| Orchestrator can create worktrees and dispatch agents | High | Reference-only; no daemon execution |
| npm/npx setup can execute package code | Medium | No install or bootstrap during intake |
| MCP/provider/token templates require credentials | Medium | No credential configuration; placeholders stay inside submodule |
| Large governance surface may duplicate ADK concepts | Medium | Use observe-first and selective extraction only |

## Tool-Call Policy

| Operation | Policy |
|---|---|
| Read files under `scale-engine/` | allow |
| `git fetch` for submodule tracking | allow through existing subrepo sync |
| Execute package scripts, CLI, hooks, MCP, dashboard, setup, bootstrap | deny until separate review |
| Copy code or config into ADK/root runtime | deny until a specific versioned asset passes duplicate/conflict/security gates |
| Store credentials or tokens | deny |

## Final Decision

Approved for `active-reference` tracking with `observe-first` intake policy.

The repo is useful as a continuing upstream signal for governance runtime patterns, especially gates, evidence, context budgeting, candidate queues, and dashboard capability visibility. Runtime enablement remains explicitly out of scope.
