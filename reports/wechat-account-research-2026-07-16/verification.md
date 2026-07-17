# Verification Record

## Scope summary

Verified artifacts:

- `README.md`: collection method, ranked article list, exclusion evidence and limits.
- `catalog.jsonl`: 20 metadata-only records.
- `evidence-summary.json`: query, verification and curation counts.
- `hermes_data/scripts/wechat/article_reader/targeted_account_collector.py`: thin orchestrator over the existing Hermes reader chain.
- Collector usage guide and unit tests.

Not in scope:

- Persisting article bodies.
- Modifying `agent-dev-kit`, `~/codex`, `~/.codex` or live `~/.hermes` configuration.
- Solving CAPTCHA, enabling a proxy pool, publishing, committing or pushing.

## Completion claim audit

| Claim | Independent check | Result |
|---|---|---|
| Catalog contains 20 curated records | Parse JSONL and count account/tier groups | Pass: 11 Tencent + 9 Ali; P0/P1/P2 = 13/5/2 |
| 19 records were directly verified by Hermes | Diff catalog account/date/title/hash tuples against the three successful Hermes JSONL runs | Pass: exact match for all 19 |
| No article body is archived | Check every record has `body_persisted=false`; inspect schema and safety scan | Pass |
| Content hashes are usable | Require every non-null SHA-256 to contain 64 hexadecimal characters | Pass |
| Collector filters and deduplicates correctly | Unit tests for normalized title selection, alias/topic filtering and metadata-only base record | Pass: 3/3 |
| Existing `wechat_ops` tests remain healthy | Run the complete package test directory with the package's actual source path | Pass: 7/7 |
| Root governance remains healthy | Run root quick gate and WeChat intake ledger check | Pass: 56/56 quick checks; ledger has 313 healthy entries |

## Evidence index

| Command | Exit | Result summary | Evidence path | Layer | Related artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc '<jq catalog/schema/count/hash assertions>'` | 0 | 20 records; counts and hashes valid; all body flags false | `catalog.jsonl` | Archive | machine-readable catalog |
| `rtk bash -lc '<diff catalog direct-read tuples against Hermes JSONL>'` | 0 | All 19 account/date/title/hash tuples match | `/tmp/wechat-tencent-aliyun-20260716/` (ephemeral run evidence) | Workflow | Hermes verification run |
| `rtk bash -lc 'PYTHONPATH=/tmp/wechat-deps pytest -q packages/wechat_ops/tests/test_targeted_account_collector.py'` | 0 | 3 tests passed | `test_targeted_account_collector.py` | Script | targeted collector |
| `rtk bash -lc 'PYTHONPATH=packages/wechat_ops/src:/tmp/wechat-deps pytest -q packages/wechat_ops/tests'` | 0 | 7 tests passed | `packages/wechat_ops/tests/` | Package | wechat_ops |
| `rtk bash -lc '<py_compile; --help; git diff --check>'` | 0 | Compile, CLI smoke and tracked diff check passed | `targeted_account_collector.py` | Script | targeted collector |
| `rtk bash ~/hermes/bin/workflows/audit-paths.sh` | 0 | No machine-specific home paths in Hermes assets | Hermes path audit output | Repository | hermes_data |
| `rtk scripts/check-all.sh --quick` | 0 | 56/56 root quick checks passed | root gate output | Repository | llm_agent |
| `rtk scripts/check-wechat-intake-ledger.sh .` | 0 | Existing ledger healthy; 313 articles | `reports/wechat-article-intake.jsonl` | Archive governance | existing WeChat ledger |
| `rtk bash ~/codex/scripts/final-ready.sh` | 0 | Final-ready passed; session coach requested immediate handoff because the thread is long | session coach output | Session | final gate |

## Negative and corrected paths

| Observation | Status | Resolution |
|---|---|---|
| Initial Tencent collector run produced 14 `search-unresolved` records because resolving the npm `.bin` symlink placed the wrong directory on `PATH` | Fixed | Collector now keeps the `.bin` path with `Path.absolute()`; a fresh run produced 9 direct reads, 4 out-of-window and 1 account mismatch. The failed run was not used in the catalog. |
| First complete package test used `PYTHONPATH=src`, causing four `ModuleNotFoundError: wechat_ops` failures | Fixed | Corrected to `PYTHONPATH=packages/wechat_ops/src`; all 7 tests passed. |
| First catalog integrity check found one copied SHA-256 with length 50 | Fixed | Replaced it with the original 64-character Hermes evidence hash and reran all JSON/hash checks. |
| Hermes quality audit returned one failure because `~/.hermes` does not exist | Open, non-blocking for this scope | Asset checks passed, but no live Hermes runtime was provisioned or modified. This archive/collector delivery does not claim live runtime readiness. |

## Runtime and compatibility audit

- Breaking change: none. The collector and report directory are additive; no existing CLI or schema was changed.
- Rollback boundary: remove only the new collector, its guide/test and this report directory. Existing dirty files and subrepositories are unrelated and were not cleaned or reverted.
- Permissions: no credentials, authenticated connectors, proxy pool, CAPTCHA bypass, publish operation or external write API was enabled.
- Temporary dependencies: `beautifulsoup4` and the npm `agent-browser` package were installed under `/tmp` for this run.
- Browser runtime side effect: the `agent-browser` installer placed Chromium 151 under `~/.agent-browser/browsers/chrome-151.0.7922.34` despite the package itself being installed under `/tmp`. It was left intact because removing it was not authorized.
- Live runtime: `~/.hermes` is absent; `~/.codex` was not changed.

## Review and final gate

- Self-review findings: two blocker-class implementation/data defects were found and fixed (browser binary path and truncated hash); one command-path error was corrected.
- Open blockers for the requested archive and reusable collector: none.
- Residual items: 8 unresolved search candidates, no qualifying Profile-specific article, and several official-site-only candidates that were not proven to belong to the target WeChat account.
- Final gate: **pass for metadata archive and collector source delivery**; **not a claim that a live Hermes runtime is installed or healthy**.
