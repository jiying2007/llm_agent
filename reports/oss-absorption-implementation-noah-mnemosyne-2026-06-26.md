# OSS Absorption Implementation: Noah / Mnemosyne

> Status: implemented
> Date: 2026-06-26
> Sources:
> - https://github.com/gymaira1990-jpg/noah-gen3-type2
> - https://github.com/gymaira1990-jpg/Mnemosyne-OS

## Scope

This implementation converts the report-only analysis into small ADK governance improvements. It does not import upstream code, runtime services, MCP tools, database schemas, install commands, or prose.

## Implemented Decisions

| Source idea | Local implementation | Files |
|---|---|---|
| Temporal memory hierarchy and lifecycle gates | Expanded memory backend capability review with `temporal_strata`, `lifecycle_model`, `retrieval_fusion`, `graph_topology`, `offline_sync`, and `purge_semantics`. | `agent-dev-kit/docs/runbooks/memory-governance.md`, `agent-dev-kit/scripts/check-memory-governance.sh` |
| Deterministic filtering and protected memory signals | Added deterministic pre-filter and stable identity key requirements before memory write or compression. | `agent-dev-kit/docs/runbooks/memory-governance.md`, `agent-dev-kit/docs/runbooks/token-context-governance.md` |
| Drawer-style incremental context management | Added incremental compression boundary and explicit whole-context compression avoidance with raw evidence fallback. | `agent-dev-kit/docs/runbooks/token-context-governance.md`, `agent-dev-kit/scripts/check-token-budget.sh` |
| CLI/documentation drift found during full validation | Added missing `harness-loop-engineering` command documentation. | `agent-dev-kit/docs/commands.md` |

## Rejected Or Deferred

| Item | Decision | Reason |
|---|---|---|
| Upstream source code import | rejected | Security and license-file concerns; suspected secrets/default passwords in reference runtime. |
| Mnemosyne runtime/API/database integration | deferred | Requires transport, credential, namespace, deletion, audit, sync, backup, and rollback review. |
| Hash-only deletion as default policy | deferred | Hash-only tombstone is not sufficient as a compliance deletion rule. |
| New memory skill | rejected | Existing ADK memory and context governance assets cover the policy surface. |

## Validation

| Command | Result |
|---|---|
| `rtk bash agent-dev-kit/tests/test_memory_governance.sh` | pass |
| `rtk bash agent-dev-kit/tests/test_token_context_governance.sh` | pass |
| `rtk bash agent-dev-kit/tests/test_docs_cli_alignment.sh` | pass |
| `rtk bash tests/run_all.sh --fail-fast` from `agent-dev-kit` | pass: 42 tests |
| `rtk scripts/check-all.sh --quick` from `llm_agent` | pass: 44 checks |
