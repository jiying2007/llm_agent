# Active 子仓同步与选择性吸收报告

## 执行摘要

- 日期：2026-07-06
- 模式：active 参考仓同步到最新 + report-first selective absorption
- 同步范围：`enabled=yes`、`status=active` 且作为参考来源的子仓；`agent-dev-kit` 是应用/落地仓，不计入参考仓同步范围；disabled 子仓未同步、未扫描。
- 已快进到 upstream 最新：`oh-my-codex`、`planning-with-files`、`scale-engine`。
- 未强制同步：`OpenSpec` 与 `superpowers` 同时存在本地 dirty 变更和 upstream behind，不能在不处理本地改动的情况下安全快进；`vibeflow` 已在 upstream 最新但仍有本地 dirty 变更。
- 未执行：任何 merge、commit、push、子仓重置、stash、disabled 子仓恢复。
- 关键阻塞：`agent-dev-kit` 仍是 strict dirty；`OpenSpec/superpowers/vibeflow` 为 known-dirty；`check-subrepo-state` 在提交前预期失败。

## Active 子仓状态

| Repo | Branch | Upstream delta after sync | Dirty | Decision |
|---|---:|---:|---:|---|
| OpenSpec | main | behind 46 | known-dirty 655 | observe; sync blocked by dirty tree |
| oh-my-codex | main | 0 | clean | adapt |
| planning-with-files | master | 0 | clean | adapt |
| superpowers | main | behind 190 | known-dirty 115 | already-adapted; sync blocked by dirty tree |
| vibeflow | main | 0 | known-dirty 216 | observe |
| scale-engine | master | 0 | clean | adapt |

Excluded from reference sync: `agent-dev-kit` is the application and absorption landing repository, not a reference source repository.

## 决策

| Source | Candidate | Decision | Landing |
|---|---|---|---|
| oh-my-codex | block `.omx/tmp` planning artifact execution transports; block same-command handoff artifact script execution; tighten typed subagent provenance | adapt | `agent-dev-kit/templates/security/tool-call-policy.md`; `adk-parallel-agent-governance` |
| planning-with-files | `PLANNING_DISABLED=1` per-invocation opt-out across hook entrypoints; plan-execute approval gate for platform hooks | adapt | `agent-dev-kit/manifests/hooks_runtime_audits.json` |
| scale-engine | reuse-first review checks; require standards/architecture evidence; harden ship disclosure | adapt | `adk-verification-before-completion` |
| superpowers | Codex hook/package cleanup and v6.1 packaging hardening | already-adapted | covered by `reports/superpowers-v6-absorption-2026-07-06.md` and plugin/hook manifests |
| OpenSpec | stores/context, canonical resolution, validation/archive changes, docs overhaul | observe | too broad for dirty local tree; needs separate OpenSpec-focused intake |
| vibeflow | no upstream delta after fetch | observe | no new upstream absorption this cycle |

## Implemented Changes

- Fixed `scripts/sync-subrepos.sh` so active subrepos with `.git` as a file, such as `scale-engine`, are recognized by `git -C ... rev-parse` instead of being skipped.
- Fixed `scripts/sync-subrepos.sh` default scope so `adk-core` landing repositories such as `agent-dev-kit` are excluded from reference sync unless `SYNC_INCLUDE_ADK_CORE=1` is explicitly set.
- Updated root `AGENTS.md` routing text to distinguish reference repository sync from `agent-dev-kit` application/landing maintenance.
- Added data-only handoff artifact execution denial to `agent-dev-kit/templates/security/tool-call-policy.md`.
- Added hook opt-out and plan-execute gate policy to `agent-dev-kit/manifests/hooks_runtime_audits.json`.
- Extended `agent-dev-kit/skills/adk-parallel-agent-governance/SKILL.md` with data-only handoff artifact policy and provenance requirements.
- Extended `agent-dev-kit/skills/adk-verification-before-completion/SKILL.md` with standards/architecture evidence and ship disclosure gates.

## Evidence

- Initial fetch: `rtk scripts/sync-subrepos.sh . fetch` passed for ordinary active subrepos; `rtk git -C scale-engine fetch --all --prune` passed for `.git` file submodule.
- Reference fast-forward sync: `rtk git -C oh-my-codex pull --ff-only`; `rtk git -C planning-with-files pull --ff-only`; `rtk git -C scale-engine pull --ff-only`.
- Post-sync status: `oh-my-codex`, `planning-with-files`, and `scale-engine` report no upstream delta; `OpenSpec` remains behind 46 with dirty tree; `superpowers` remains behind 190 with dirty tree; `vibeflow` has no upstream delta but remains dirty.
- Scan: `rtk scripts/diff-scan.sh . 30 reports/active-subrepo-diff-scan-2026-07-06.md`.
- Source commits inspected:
  - `oh-my-codex`: `64254a34`, `81313523`, `ea377c60`
  - `planning-with-files`: `ee89266`
  - `scale-engine`: `1f98fa1`, `be5519e`, `952798e`
