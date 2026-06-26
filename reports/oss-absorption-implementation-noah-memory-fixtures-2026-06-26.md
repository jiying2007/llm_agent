# OSS Absorption Implementation: Noah / Mnemosyne Memory Fixtures

Date: 2026-06-26
Status: implemented
Mode: clean-room fixture

## Source Mapping

| Source | Prior decision | Implemented as |
|---|---|---|
| `gymaira1990-jpg/noah-gen3-type2` | `ARCHIVE_ONLY`, selective future `ADAPT` | protected key collision negative fixture |
| `gymaira1990-jpg/Mnemosyne-OS` | `ARCHIVE_ONLY`, selective future `ADAPT` | memory governance field and conflict-review gate |

Source reports:

- `reports/oss-analysis-gymaira1990-jpg-noah-gen3-type2-2026-06-26.md`
- `reports/oss-absorption-plan-gymaira1990-jpg-noah-gen3-type2-2026-06-26.md`
- `reports/oss-absorption-plan-gymaira1990-jpg-Mnemosyne-OS-2026-06-26.md`

## Decision

Adopted as an existing ADK memory/context governance fixture. No upstream runtime code, MCP server, database, UI, model registry, install command or source content was copied.

## Implemented Assets

- `agent-dev-kit/templates/memory/memory-candidate.md`
- `agent-dev-kit/tests/fixtures/context/protected-key-collision-negative.md`
- `agent-dev-kit/docs/runbooks/memory-governance.md`
- `agent-dev-kit/scripts/check-memory-governance.sh`
- `agent-dev-kit/scripts/check-token-budget.sh`

## Behavior Covered

The new negative fixture covers collision handling for protected memory entries:

- `correction`
- `decision`
- `progress`
- `execution-log`

Each collision must keep a `stable_identity_key`, preserve `raw_evidence`, set `duplicate_key_status: collision`, enter `contradiction_status: conflict_review`, and avoid `promotion_action: auto_promote_candidate` or `promotion_action: promoted`.

## Validation

- `rtk bash agent-dev-kit/scripts/check-memory-governance.sh`: pass
- `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json`: pass
- `rtk bash agent-dev-kit/scripts/devkit.sh token-budget --summary-json`: pass
- `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict`: pass
- `rtk git -C agent-dev-kit diff --check`: pass

## Boundary

This change extends existing governance fixtures only. It does not create a new skill, enable long-term memory writes, import external runtime code, install dependencies, or change `~/.codex`.
