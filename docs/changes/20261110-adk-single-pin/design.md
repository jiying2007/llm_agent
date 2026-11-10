# ADK single-pin upgrade — integration design

- **Source authority**: Git index 160000 entry for agent-dev-kit; verify exact checkout, HEAD tree and raw manifest Git blob. The version string is read from that manifest, never independently declared.
- **Provenance**: ADK main CI signs promotion-evidence.json as a Sigstore bundle. Root fetches the original pair and GitHub Actions run/Release metadata into ephemeral CI storage, verifies certificate identity/issuer and validates all source SHA and release digest fields. These files need not become active Root source files.
- **Compatibility**: Root existing `test_adk_*` and integration gate still protect the v2 transition. A subsequent cutover removes duplicated active lock/interface/provenance files once status_projection, active_contracts, legacy CLI and all dependent tests use the v3 single source.
- **Qualification**: Existing M5 baseline and LTA site pilot are NOT inherited by any new source. The existing ADK interface authority verifier explicitly reports runtime_qualified=false and device_qualified=false.
- **Cost**: Do not install an agent runtime, add scheduled workflows or re-run upstream ADK source regression during Root upgrade. Reuse verified upstream main CI and execute only Root consumer regression.
