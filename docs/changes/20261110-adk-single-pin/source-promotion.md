# ADK source-only promotion (transition stage)

Scope: Root upgrades the already-published ADK source pin. This **does not** certify Software M5, a native runtime or any physical device.

## Operation

1. Fetch the immutable ADK release tag into the existing `agent-dev-kit` submodule, verify the commit identity, and check out that exact commit. Source-only promotion rejects a non-fast-forward or mismatched worktree HEAD.
2. From an isolated clean Root checkout, stage the current submodule pin and generated projections with:

```bash
bash scripts/promote-adk.sh --source-only --apply --updated-at 2026-11-10
git diff --cached --check
git diff --cached --name-status
```

3. The staging transaction changes only `agent-dev-kit` and `reports/current-status.md`, then validates pin consistency and source projection. It does **not** copy new upstream CI promotion-evidence.json or Sigstore bundle into Root.
4. Commit and open a protected PR. On an ADK Gitlink change, the existing Root `integration-deep` workflow checks the *immutable release* archive SHA-256, release contract and native GitHub attestation bound to the exact ADK commit/source-ref and approved signer workflow. CI must be green; source-only staging cannot claim publication.

## Safety and proof boundaries

- Source-only result status is `staged-not-verified`, `release_authorized=false`, `verification_model=immutable-release-ci-required`. This is not a signed receipt.
- The previously stored Software M5 signed qualification evidence remains independent and untouched. A future M5 requalification still requires its own current, valid signed promotion evidence and measured runtime/field qualification.
- Pre-staged unrelated edits, non-descendant ADK commits, mismatched child checkout, a failed pin check or broken status projection must cause rollback. The rollback test asserts all four modified paths and the Git index are restored, without rewriting product evidence.
- During the transition, The old interface lock has been deleted; `adk.lock` is now a Git-ignored, deterministically generated consumer cache from the exact indexed Gitlink. No duplicate lock is committed.
