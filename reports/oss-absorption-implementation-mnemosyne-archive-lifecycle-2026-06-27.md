# OSS Absorption Implementation: Mnemosyne Archive Lifecycle Fixture

Date: 2026-06-27
Status: implemented
Mode: clean-room negative fixture

## Source Mapping

| Source | Prior decision | Implemented as |
|---|---|---|
| `gymaira1990-jpg/Mnemosyne-OS` | `ARCHIVE_ONLY`, selective future `ADAPT` | archive lifecycle promotion negative fixture |

Source reports:

- `reports/oss-analysis-gymaira1990-jpg-Mnemosyne-OS-2026-06-26.md`
- `reports/oss-absorption-plan-gymaira1990-jpg-Mnemosyne-OS-2026-06-26.md`

## Decision

Adopted only as an existing ADK memory/archive governance fixture. No upstream runtime code, API service, database schema, sync model, model config, UI, dependency or source prose was copied.

## Implemented Assets

- `agent-dev-kit/tests/fixtures/memory/archive-lifecycle-promotion-negative.md`
- `agent-dev-kit/templates/memory/memory-candidate.md`
- `agent-dev-kit/docs/runbooks/memory-governance.md`
- `agent-dev-kit/scripts/check-memory-governance.sh`
- `agent-dev-kit/scripts/check-token-budget.sh`

## Behavior Covered

The new negative fixture covers `research -> engineering -> archive` lifecycle promotion. A candidate must not be promoted when any of these gates is missing:

- `raw_evidence`
- `owner_review`
- `rollback_path`

Incomplete promotion candidates must stay at `contradiction_status: missing_evidence` and `promotion_action: blocked`. The gate also rejects `promotion_action: auto_promote_candidate` and `promotion_action: promoted` in the negative fixture.

## Validation

| Command | Result | Notes |
|---|---|---|
| `rtk bash agent-dev-kit/scripts/check-memory-governance.sh` | pass | New fixture is enforced by memory governance. |
| `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json` | pass | `context_governance_assets=10`, `failures=0`. |
| `rtk scripts/check-adoption-matrix-structured.sh .` | pass | Markdown and JSONL adoption matrix are synchronized. |
| `rtk bash scripts/check-adoption-evidence-integrity.sh .` | pass | Evidence paths are present. |
| `rtk git -C agent-dev-kit diff --check` | pass | No whitespace errors in ADK changes. |
| `rtk git diff --check` | pass | No whitespace errors in parent changes. |
| `rtk bash agent-dev-kit/tests/test_memory_governance.sh` | blocked | Fails in strict validation because existing official source `openai-latest-model-gpt-5-5` expired on 2026-06-26. |
| `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` | blocked | Same unrelated OpenAI freshness expiry. |
| `rtk scripts/evidence-bundle.sh . --format json --max-summary-chars 1200` | needs-fix | Reports `unexpected_dirty=1` because this implementation leaves `agent-dev-kit` modified before commit. |
| `rtk scripts/check-all.sh --quick` | needs-fix | 41/44 pass; failures are OpenAI freshness expiry, evidence bundle dirty state, and subrepo state dirty. |

## Boundary

This change strengthens existing promotion governance only. It does not write Knowledge Hub content, enable long-term memory writes, change `~/.codex`, create a new skill, or import Mnemosyne runtime/database/sync behavior.
