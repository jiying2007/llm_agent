# OSS Security Review: gymaira1990-jpg/Mnemosyne-OS

> Status: report-only, blocked for execution
> Date: 2026-06-26
> Source: `scratch/oss-intake/Mnemosyne-OS`

## Review Boundary

- Cloned for local read-only review.
- Did not install dependencies.
- Did not start FastAPI, PostgreSQL, AGE, reranker, systemd, cron, or sync processes.
- Did not execute upstream Python scripts.
- Did not copy upstream source code into ADK runtime assets.

## Findings

| Severity | Finding | Evidence |
|---|---|---|
| Medium | README and docs claim MIT, but no standalone license file was found in the local clone. | `README.md`; no `LICENSE*` found by file listing. |
| Medium | Runtime requires external API keys and cloud/local services. | `src/config.py`, `src/backends.py`, `src/core/embedding.py`, `src/core/llm.py` |
| Medium | System operation examples mention systemd and cron-like background tasks. | `README.md`, `docs/WHITEPAPER.md` |
| Medium | Local-to-cloud sync changes trust, durability, and deletion semantics. | `sync/local_cache.py`, `sync/memory_gateway.py`, `sync/sync_push.py` |
| Low/Medium | Hash-purification design is promising but not a complete deletion/compliance policy by itself. | `src/security/purifier.py` |

## Security Decision

Decision: `ARCHIVE_ONLY` for architecture reference; no execution or integration.

Any future live integration must first define:

- transport and auth boundary;
- credential source and redaction policy;
- namespace isolation;
- backup and rollback behavior;
- audit log retention;
- deletion and purge semantics;
- deny-path and allowed tool list if exposed through MCP or API.
