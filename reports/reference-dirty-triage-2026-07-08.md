# Reference Subrepo Dirty Triage

- generated_at: 2026-07-08T20:40:01+08:00
- date: 2026-07-08
- mode: report-only
- status: pass

## Boundary

This report reads reference subrepo status only. It does not clean, reset, commit, push, sync, absorb, or modify live runtime assets.

## Summary

| Repo | Branch | Head | Decision | Count | Expires | Owner |
|---|---|---|---|---:|---|---|
| OpenSpec | main | 3c7a05c | known-dirty-review | 655 | 2026-07-10 | adk-maintainer |
| superpowers | main | 6efe32c | known-dirty-review | 115 | 2026-07-10 | adk-maintainer |
| vibeflow | main | 0df764e | known-dirty-review | 216 | 2026-07-10 | adk-maintainer |

## Samples

### OpenSpec

- baseline_ref: observe-baseline
- fingerprint_matches: true
- reason: reference-repo-local-state
- sample_status:
  - ` M .actrc`
  - ` M .changeset/README.md`
  - ` M .changeset/config.json`
  - ` M .coderabbit.yaml`
  - ` M .devcontainer/README.md`
  - ` M .devcontainer/devcontainer.json`
  - ` M .github/CODEOWNERS`
  - ` M .github/workflows/README.md`

### superpowers

- baseline_ref: observe-baseline
- fingerprint_matches: true
- reason: reference-repo-local-state
- sample_status:
  - ` M .claude-plugin/marketplace.json`
  - ` M .claude-plugin/plugin.json`
  - ` M .codex-plugin/plugin.json`
  - ` M .codex/INSTALL.md`
  - ` M .cursor-plugin/plugin.json`
  - ` M .gitattributes`
  - ` M .github/FUNDING.yml`
  - ` M .github/ISSUE_TEMPLATE/bug_report.md`

### vibeflow

- baseline_ref: observe-baseline
- fingerprint_matches: true
- reason: reference-repo-local-state
- sample_status:
  - ` M .claude-plugin/marketplace.json`
  - ` M .claude-plugin/plugin.json`
  - ` M .claude/commands/vibeflow-dashboard.md`
  - ` M .claude/commands/vibeflow-design.md`
  - ` M .claude/commands/vibeflow-increment.md`
  - ` M .claude/commands/vibeflow-init.md`
  - ` M .claude/commands/vibeflow-learn.md`
  - ` M .claude/commands/vibeflow-plan.md`
