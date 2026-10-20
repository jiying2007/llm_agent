# Acceptance checklist

## Source and contract

- [x] User authorization is explicit; the ADK policy remains the single delegated review authority.
- [x] Records honestly identify an independent AI reviewer separate from the author and lifecycle operator.
- [x] Root checks loaded validator bytes against the explicit pinned three-module source set before calling the shared API.
- [x] The bridge checks parent gitlink, ADK HEAD and policy/authorization/validator HEAD/index/raw worktree identities; rehashed dirty and staged authority fails.
- [x] Missing optional ADK fails at runtime while default Root typing runs without it.
- [x] All three historical base/head/complete-patch identities are fixed and validated.
- [x] Active/archive duplication, unsafe paths, missing/contradictory/duplicate provenance and invalid archive chronology fail closed.
- [x] Scope-aware aggregation keeps Product M5 conditional and retains real canonical diagnostic output.
- [x] Source snapshots include review pointers, policy authorization and complete declared inputs with correct Root/ADK bases.
- [x] G22 requires all nine bound documents, genuine signature replay and full current-asset decisions.
- [x] LTA delegates only summary review; registered human field actors and actual full/end-window observations remain required.
- [x] Negative tests reject missing inputs, changed identity/scope, altered digests, policy drift and old installed validators.
- [x] Recovery records distinguish exact restored files, reconstructed files and historical test evidence.

## Validation and delivery

- [x] Actual recovered focused suite initially passed 72 tests; after the independently found authority-to-Git defect was fixed, the expanded suite actually passed 79 tests.
- [x] Actual recovered default `env -u PYTHONPATH` mypy: 9 files passed.
- [x] Actual recovered Ruff on four source files and three test/helper files passed.
- [x] Actual recovered full original LTA shell certifier suite passed after explicit v2 migration.
- [x] Independent review of this recovered byte set is complete: Spec/Quality pass at `2026-10-20T12:20:25.352831Z`, with an actual independent 79-test pass and unchanged source hashes.
- [x] Formal ADK `v8.0.36` release and exact six-file Root pin promotion are complete; original promotion evidence and Sigstore bundle were verified without bypassing trust checks.
- [x] Full G22 fixture integration passes against that formal pin; actual run ended at `2026-10-20T13:52:07.255248Z`.
- [x] Independent six-file promotion Spec/Quality review passed at `2026-10-20T13:53:07.527685Z`.
- [x] ADK clean-commit release build matches the formal tar byte-for-byte; the actual 8.0.35 to 8.0.36 install/upgrade/rollback rehearsal restores all 39 assets, receipt bytes and modes.
- [x] All 79 original Root regression scripts actually pass. The separate capture exit 3 and synthetic canary residue are preserved, with exact tracked-source comparison and subsequent restoration.
- [x] Actual working-tree aggregate results are retained honestly: 47 PASS / 5 FAIL, exit 1, before/after source snapshot unchanged.
- [x] Docker parity unavailable, canonical Hub unavailable, expired reference reviews and historical Product M5 source mismatch are recorded separately; none is relabeled PASS.
- [ ] Final documentation/evidence review, required final-head protected Root CI and fresh-main readback are verified.
- [ ] Tracker closure matches the corresponding actual canonical result.

The last two boxes are the pre-delivery snapshot. Their actual post-commit outcome belongs in the final body of [Root PR #265](https://github.com/jiying2007/llm_agent/pull/265), together with the deferred `--release-clean` result. Earlier C2 CI is candidate evidence and is not substituted for the final head or main.

## External facts

These checks do not assert real Native authentication, runtime measurements, a complete real LTA summary or current Product M5. Two test-generated canary receipts are retained only in this change's evidence directory for failure diagnosis; they are not installed into a canonical campaign location or counted as field/runtime evidence. Empty or missing canonical evidence remains blocked and is not replaced by generated PASS records.
