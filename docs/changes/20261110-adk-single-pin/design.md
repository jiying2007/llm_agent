# ADK single-pin upgrade — integration design

- **Source authority**: Git index 160000 entry for agent-dev-kit; verify exact checkout, HEAD tree and raw manifest Git blob. The version string is read from that manifest, never independently declared.
- **Provenance**: ADK main CI signs promotion-evidence.json as a Sigstore bundle. Root fetches the original pair and GitHub Actions run/Release metadata into ephemeral CI storage, verifies certificate identity/issuer and validates all source SHA and release digest fields. These files need not become active Root source files.
- **Compatibility**: Root existing `test_adk_*` and integration gate still protect the v2 transition. A subsequent cutover removes duplicated active lock/interface/provenance files once status_projection, active_contracts, legacy CLI and all dependent tests use the v3 single source.
- **Qualification**: Existing M5 baseline and LTA site pilot are NOT inherited by any new source. The existing ADK interface authority verifier explicitly reports runtime_qualified=false and device_qualified=false.
- **Cost**: Do not install an agent runtime, add scheduled workflows or re-run upstream ADK source regression during Root upgrade. Reuse verified upstream main CI and execute only Root consumer regression.

## Native immutable-Release proof (phase 2)

The ADK release workflow already publishes an immutable tarball, SHA-256 checksum,
artifact contract and a GitHub-native Sigstore/SLSA attestation. One-off
Root preflight run 42791541718 verified v11.2.2 with the expected Release
digest, signer workflow, source commit e7527342ea8704f967a4369aa5cf8c7a72e6c229
and refs/heads/main. No Codex, Work or physical hardware was used.

On future gitlink changes Root CI now checks the same immutable release
without storing the new attestation in the Root tree. It rejects mutable
or draft Releases, incorrect archive/manifest hashes, ineligible contracts
and wrong signer/source commit. Verification does not confer runtime or
physical-device qualification.

Transition boundary: old signed CI promotion inputs and parallel lock files
remain temporarily as existing consumer fixtures. Retire them only after
status projection, runtime chain, release CLI and dependent tests migrate.

## Consumer inventory and first removal tranche

A read-only GitHub Actions inventory of the current Root code (run 42819326430)
located the parallel ADK lock in core identity, M5 runtime qualification, runtime
chains, recovery, status projection, tests and governance policies. It is not
safe to remove all lock files simply because Git commit identity is sufficient
for source pinning: product credentials and report input hashes have independent
consumers.

This tranche migrates the **active governance deprecated-surface checker**
to the single existing ADK interface authority instead of reading
`manifests/adk_interface.lock.json`. LTA source assertion derives from the
indexed Gitlink and the pinned manifest through `source_pin`, not from a parallel
version string. The active-contract gate dependency and generated current-status
input digest are updated exactly; no device or release authorization changes.

The interface-lock and adk.lock files remain present for M5, source promotion,
status projection and other consumers until a larger contract-wide migration can
replace them without losing fail-closed invariants.
