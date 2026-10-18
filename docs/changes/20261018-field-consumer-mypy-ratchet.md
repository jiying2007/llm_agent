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
