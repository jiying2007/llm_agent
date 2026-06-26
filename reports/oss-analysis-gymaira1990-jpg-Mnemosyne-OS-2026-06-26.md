# OSS Analysis: gymaira1990-jpg/Mnemosyne-OS

> Status: analyzed, report-only
> Date: 2026-06-26
> Source URL: https://github.com/gymaira1990-jpg/Mnemosyne-OS
> Local quarantine path: `scratch/oss-intake/Mnemosyne-OS`
> Local commit: `165d9fcba194c12ed863a8908029cd16972d562c`
> Read status: cloned for read-only analysis; no dependencies installed; no code executed

## Source Summary

`Mnemosyne-OS` is a long-term memory system for AI agents. It combines temporal memory hierarchy, knowledge lifecycle gates, hybrid retrieval, graph search, local/offline buffering, and API integrations.

Observed local scale: 35 files.

Key modules:

- `README.md` and `docs/WHITEPAPER.md`: product and architecture overview.
- `src/main.py`: FastAPI service and memory/search endpoints.
- `src/tmt/`: time memory tree consolidation and recall.
- `src/security/`: audit and hash-purification routines.
- `sync/`: local SQLite cache and push gateway.
- `scripts/archive_session.py`: session archive helper.

## Reusable Claims

| Claim | Local applicability | Evidence strength | Notes |
|---|---|---|---|
| Long-term memory should be organized as temporal strata rather than flat snippets. | Medium | Medium | ADK already separates resident and retrievable memory; temporal hierarchy may help future retrieval reports. |
| Knowledge should pass lifecycle gates from raw/research to engineering to archive. | High | Medium | Aligns with current archive and memory-governance direction. |
| Retrieval should combine semantic, keyword, time, reliability, and heat signals. | Medium | Medium | Useful as a backend capability checklist, not as a mandated implementation. |
| Deletion can preserve graph topology by replacing content with irreversible hashes. | Medium | Low/Medium | Interesting privacy pattern, but needs legal/security review before adoption. |
| Offline local cache with later cloud sync improves continuity but changes trust boundaries. | Medium | Medium | Relevant only after explicit backend and credential boundary review. |

## Risks

- No standalone `LICENSE` file was found in the clone, although README badges/text claim MIT.
- The runtime depends on PostgreSQL, pgvector, Apache AGE, FastAPI, asyncpg, external embedding/LLM providers, and optional local reranker service.
- Some docs include systemd/cron and cloud deployment assumptions; none are suitable for automatic execution.
- The checked-in `src/config.py` appears to contain redacted or malformed `os.get...` expressions in the local clone, so runnable quality was not assumed.
- It is a product/runtime system, while current llm_agent absorption should favor method-level governance assets and tests.

## Fit Assessment

| Dimension | Assessment |
|---|---|
| Domain fit | Knowledge and memory-governance reference. |
| Maintenance | Recent commit observed on 2026-06-25 from local clone metadata. |
| Engineering quality | Good architectural documentation; runnable code quality not verified. |
| Security / supply chain | Report-only only; runtime requires separate MCP/server/backend review. |
| Uniqueness | Medium: temporal memory tree, lifecycle halls, hybrid retrieval scoring, hash-purification pattern. |

## Decision

Decision: `ARCHIVE_ONLY` with selective future `ADAPT` candidates.

Rationale:

- The strongest value is architecture vocabulary and checklist ideas, not source code.
- Existing ADK memory governance already covers write admission, source evidence, scope isolation, and promotion review.
- Direct runtime adoption is blocked until backend capability, credential, sync, and deletion semantics are reviewed.

## Candidate Follow-ups

1. Extend future memory backend capability review with temporal hierarchy, hybrid retrieval signals, graph topology handling, offline sync, and purge semantics.
2. Add archive lifecycle examples that distinguish research, engineering evidence, and durable archive facts.
3. Consider hash-purification only as a security-review research note, not as default deletion behavior.
