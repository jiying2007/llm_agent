# Long-term runbook: eliminate stale qualification claims

## Scope
Fix an active recovery/continuity runbook that still labeled LTA-01 as blocked after the actual main ruleset and LTA-01 machine authority had been verified PASS.

## Contract
- `manifests/long_term_asset_qualification.json` owns the current LTA-01..04 classification; the runbook only explains procedure.
- Keep issue #50 as historical proof, not an open blocker.
- Preserve the owner-lessening solo-maintainer controls, exact-source recovery requirements, and current independent LTA-04 blockage.
- Do not change current Product M5 authorization, event ledger, ADK release or authentic human Owner evidence.

## Regression
The existing `tests/test_long_term_asset_qualification.sh` must reject reintroduction of stale LTA-01 blocker prose and require correct LTA-02/LTA-04 boundaries. PR CI and fresh-main are separate gates.

## Rollback
Revert through protected review if the runbook changes, but do not restore a historical hard-coded blocked claim after the machine contract has moved to PASS.

## Further current-versus-historical drift repairs
- Label the former Software M5 version explicitly as historical and defer current authorization to status projection.
- Keep the optional two-human team handoff pilot separate from single-human M5 and LTA-04 acceptance.
- Distinguish historical G9 reviewing capture from the later indexed real Owner decision.
- Preserve immutable historical evidence; validate updated documentation with existing regression tests.
