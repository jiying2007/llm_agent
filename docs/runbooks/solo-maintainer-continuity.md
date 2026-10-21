# Solo Maintainer Continuity Runbook

This runbook defines the continuity controls for `llm_agent` when the repository is intentionally maintained by one person. Solo maintenance is a supported operating model; it does not waive automated governance, evidence, rollback, recovery, or runtime-portability requirements.

## 1. Operating model

- Human approval count may be zero because there is only one maintainer.
- Mainline changes still go through a pull request and required automated checks.
- Required checks, signed promotion evidence, exact source identity, and fail-closed contracts are the independent verification boundary.
- CODEOWNERS may contain one owner. Ownership and recovery instructions must remain explicit and machine-checkable.
- Missing external/admin/runtime evidence is `blocked`, never `pass`.

## 2. Authoritative recovery inputs

A clean recovery must use only tracked or externally authoritative inputs:

1. the exact `llm_agent` Git commit;
2. `manifests/adk_interface.lock.json` and `manifests/gitlinks.json`;
3. the immutable `agent-dev-kit` release/source identity referenced by the lock;
4. tracked manifests, workflows, tests, and runbooks;
5. GitHub-hosted release/provenance evidence where the contract explicitly requires it.

Untracked local files, shell history, cached working trees, manually remembered settings, and an existing `~/.codex` installation are not valid recovery dependencies.

## 3. Clean-room recovery drill

Run the drill from a clean environment or disposable workspace.

1. Clone `llm_agent` from the authoritative repository and checkout the exact candidate commit.
2. Reconstruct managed source dependencies from tracked locks/pins; do not copy an existing local dependency tree.
3. Validate the root/ADK identity and the recovery-relevant immutable ADK release surface.
4. Keep full root regression, signed ADK promotion evidence, and ADK release governance independently fail-closed; recovery evidence must not reclassify those gates.
5. Materialize/install only through tracked control-plane entry points.
6. Verify the reconstructed component identity against the expected exact source/release identity.
7. Exercise rollback/restore using the tracked transactional install receipt and backup mechanism.
8. Re-run receipt and managed-asset digest checks after rollback/recovery and prove the final isolated target returns to its pre-install managed state.
9. Emit a machine-readable run receipt and persist the qualifying main-run facts under `reports/long-term-assets/`, including source commit, ADK release/source identity, workflow/artifact identity, rollback transition, result, environment facts, and evidence boundary.

The drill is not complete until a fresh receipt exists on merged `main`, the run succeeds, and durable repository evidence records the run-bound facts. A PR-head run or written runbook alone is not recovery evidence.

The current LTA-03 qualification evidence is `reports/long-term-assets/solo-maintainer-recovery-2026-09-15.json`. It is bound to the successful fresh-main recovery run and explicitly records `runtime_invoked=false`; therefore it cannot satisfy LTA-02 multi-runtime portability.

## 4. Release continuity

`llm_agent` is an operational control-plane workspace and is identified by exact Git commit rather than its own component release. `agent-dev-kit` is the versioned component and must preserve immutable release identity and signed provenance.

For an ADK release or promotion:

- use the release contract and exact-head evidence;
- do not infer release state from a version string alone;
- preserve rollback information and artifact digest/provenance;
- after publishing an immutable release, allow `main` to advance only under source-identity checks; a later main commit is not the same artifact merely because the manifest source version is unchanged.

## 5. GitHub administration continuity

Native repository settings are a live control, not documentation-only state. The current machine authority is `manifests/long_term_asset_qualification.json` (`LTA-01`), checked against GitHub's actual main ruleset. **Never use this historical runbook as an independent pass/blocked status authority.**

The LTA-01 ruleset and retirement of generic merged-PR custom deletion were completed through reviewed governance work (historical tracker issue #50). The current policy requires pull-request-mediated main changes, required status checks with strict/up-to-date enforcement, non-fast-forward/deletion protection, no unconditional bypass actors, and zero mandatory human approvals under solo maintenance. Ordinary merged-PR branch removal is native GitHub behavior; custom Branch GC is restricted to registered exact-SHA exceptional retirement proofs.

After any ruleset, checkout, workflow, permission or branch-GC change, re-read the authoritative LTA contract and verify live ruleset settings through the existing `native-governance` checker. The relevant claim must be bound to the exact verification result. A missing API permission, changed ruleset or unverifiable check remains blocked; a prior PASS is not sufficient for a new claim.

The separate LTA-02 periodic R2 qualification is delegated to Digital Worker and is **nonblocking observation** in Root. LTA-03 recovery drill is already separately qualified; a historical receipt proves its own source only, and fresh recovery must be rerun when appropriate. LTA-04 continues to require authentic 30-day field outcomes and verifiable summary review. Neither successful CI nor an immutable ADK Release grants current-source Product M5 authorization.

## 6. Account/workstation loss response

If the primary workstation is lost or corrupted:

1. recover repository access using the account provider's supported recovery path;
2. use a fresh workstation and clone from the authoritative remote;
3. do not restore trust from an old working-directory snapshot alone;
4. repeat the clean-room recovery drill;
5. rotate any credentials whose confidentiality may be uncertain using provider-native controls;
6. regenerate runtime/live state from tracked source and verify identity before resuming privileged changes.

Secrets themselves must never be stored in this repository or in recovery receipts.

## 7. Terminal qualification rule

Long-term asset qualification is separate from Product M5. `manifests/long_term_asset_qualification.json` is the canonical machine authority for current LTA-01..04 dispositions. LTA-01 governance and LTA-03 recovery have historical PASS evidence (subject to current-source/live drift checks), LTA-02 is delegated nonblocking R2 observation, and LTA-04 remains independently blocked on real field outcomes and a verifiable summary review in either registered-human or policy-authorized owner-delegated-ai mode. Product M5 remains a separate conditional current-source release gate; none of these statuses may be inferred from this prose alone.
