# Root evidence-path and longitudinal consumer typing ratchet

## Scope

Extend the *existing* Root strict-mypy `pyproject.toml` file list to three high-risk owned modules: evidence path resolution, LTA-04 append-only field verification and the ADK → Codex → Digital Worker consumer chain. No new type checker, compatible API, trust registry or proof authority is added.

## Risk and preservation
- Retain Root Python >=3.11 and ADK Python >=3.8 unchanged.
- A typing PASS is source static evidence only; it cannot qualify field events, human Owner decisions, native G21 or effect G22.
- Fail closed on missing dependencies or type errors; do not silence errors with blanket ignores.

## Verification
- Existing `llm-agent-ci` contract job installs the pinned quality extra and runs `python -m mypy --config-file pyproject.toml`.
- `tests/test_ci_incremental_gate_dag.sh` now locks the three additional high-risk paths and the canonical invocation.
- Protected PR CI and fresh-main independent checks are required; any diagnosed type defects must be fixed on the same PR, not suppressed.

## Rollback
Revert via protected PR only with a documented justification and equal-or-better static coverage; never infer runtime qualification from type-checking.

## CI-discovered dependent-source typing repair
The first hosted PR mypy run found two existing `no-untyped-def`/`no-any-return` defects in the imported `tools.codex_assets.intake_io._regular_input` context manager. Its return type is now explicitly `Iterator[BinaryIO]` rather than being untyped. This fixes both at their common source without any `type: ignore`, runtime behavior change or duplicate reader. Keep the same intake security regression and rerun the hosted matrix.

## Cross-PR deep-integration regression discovered
A full integration-deep job exposed a syntax error in an existing LTA shell-embedded Python test that had escaped the selective/fast PR path. This PR fixes the stray `.lower()` continuation and permanently calls the LTA contract test from the always-run `ci-incremental-dag` profile, so future document-state assertions cannot pass PR CI without executing.

The always-run LTA test then exposed an obsolete assertion that searched for a retired exact phrase `second-human approval` in prose. The equivalent positive governance requirement is now asserted directly as `zero mandatory human approvals`, matching the machine solo-maintainer policy. No approval is synthesized, and all other LTA negative checks remain.
