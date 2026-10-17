# Control-plane safety module type-check ratchet

The Root CI contract job now installs the predeclared pinned `quality` extra and runs strict mypy against its canonical `pyproject.toml` file list. That list adds `process_budget.py` (bounded subprocess I/O) and `receipts.py` (atomic evidence persistence) beside the previously covered CLI and gate-impact modules.

This is real CI-enforced static typing; it does not establish live runtime performance, signed native G21 conformance, Agent Value G22 results, 30-day field evidence or Product M5 re-certification. The existing model remains one control-plane quality authority, not a new duplicate linter configuration.

The first actual PR mypy run identified an unchecked JSON root in `impact._load_manifest`. This update adds a real object-type guard and a null-root negative regression instead of suppressing the type error.
