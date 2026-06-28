# ADK Chronicle Workflow Scope Review

- Date: 2026-06-28
- Scope: Chronicle-mined repeated workflows considered for ADK skill promotion
- Goal: keep `agent-dev-kit` platform-neutral and prevent project or local Codex workflow drift

## Decision Summary

| Candidate | Decision | Target | Reason |
|---|---|---|---|
| Offline core dump triage | keep in ADK | `agent-dev-kit/skills/adk-offline-core-dump-triage` | Generic embedded Linux diagnostic workflow with stable inputs: core, binary, symbols, GDB and logs. |
| Embedded storage layout migration | keep in ADK | `agent-dev-kit/skills/adk-embedded-storage-layout-migration` | Generic embedded release and field-upgrade workflow covering filesystem, partition, OTA and boot-log evidence. |
| Nested repo delivery closeout | migrate out of ADK | `~/codex` local skill or project runbook | Mostly local repo-operation policy: root/subrepo closeout, gitlink, `adk.lock`, and user-specific commit/push preference. |
| App repo documentation handoff | migrate out of ADK | project-level `AGENTS.md`/`.codex/skills` or `~/codex` local skill | Mostly local/project collaboration style: Chinese docs, app-specific handoff, temporary-file boundaries and Codex workspace conventions. |

## ADK Promotion Rule

Promote to ADK only when the workflow is:

1. reusable across multiple projects or vendors;
2. expressible without product names, private paths, private protocols or one-off incidents;
3. useful outside the local Codex runtime;
4. verifiable by ADK-owned manifest, routing and test gates.

Keep outside ADK when the workflow is:

1. user preference or local machine behavior;
2. project IP, product-specific command, private directory or internal release route;
3. useful mainly as a Codex runtime shortcut;
4. better represented as project `AGENTS.md`, project `.codex/skills`, Knowledge Hub archive or `~/codex` local skill.

## Migration Notes

- `nested-repo-delivery-closeout` should become a local Codex skill or runbook because it encodes local delivery habits: subrepo first, parent gitlink/lock second, and push behavior by user intent.
- `app-repo-doc-handoff` should stay project-local or Codex-local because target apps, handoff language, temporary materials and docs layout are project collaboration concerns.
- Project evidence such as PCR02 paths, MCU repo names, app names, NAS paths, core filenames and customer partition names belongs in Knowledge Hub or project repos, not ADK.

## Validation Targets

- `agent-dev-kit/scripts/devkit.sh validate --quick`
- `scripts/check-skill-metadata.sh`
- `scripts/check-skill-routing-conflicts.sh`
- `agent-dev-kit/tests/run_all.sh`
