# WeChat Article Absorption Batch

- Batch ID: `wechat-p0-005`
- Date: `2026-05-23`
- Operator: Codex
- Source ledger: `reports/wechat-article-intake.jsonl`
- Decision overlay: `reports/wechat-article-decisions.tsv`
- Scope: fifth queued P0 candidates from `reports/wechat-absorb-next-batch.md`
- Mode: apply

## Batch Goals

- Absorb durable memory, MCP connector, prompt-layering, Skill-factory and harness-engineering boundaries.
- Do not copy tutorial code, installation commands, external repositories, MCP server implementation snippets, model/API claims or platform-specific hook semantics into ADK core.
- Keep private API/database examples, Rust/Python server code, Hermes Skill Factory project claims and popular MCP server lists report-only until security and supply-chain review.

## Candidates

| id | source | candidate | decision | target | risk | evidence |
|---|---|---|---|---|---|---|
| wechat-0103 | Agent memory system article | governance-rule-or-script | MERGE | `memory-governance.md` | medium | Memory implementation boundary, namespace separation and semantic retrieval-as-candidate guidance absorbed. |
| wechat-0104 | popular MCP server overview | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | medium | MCP capability selection by lifecycle category and risk absorbed; server list remains reference-only. |
| wechat-0110 | private API/database MCP article | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Thin connector, read-only-first and credential boundary absorbed. |
| wechat-0111 | Claude Code Skills guide | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md` | medium | Skill coverage audit and usage metrics as iteration evidence absorbed. |
| wechat-0112 | System Prompt and few-shot strategy | skill-or-workflow-enhancement | MERGE | `prompt-evolution-delivery.md` | medium | Prompt layering contract and schema/few-shot boundaries absorbed. |
| wechat-0114 | Rust remote MCP server guide | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | medium | Remote transport, endpoint and handshake compatibility gate absorbed; Rust code rejected. |
| wechat-0117 | Harness Engineering article | skill-or-workflow-enhancement | MERGE | `planning-execution-loop.md` | medium | Harness layers mapped to ADK goal/context/tool/execution/eval/handoff assets. |
| wechat-0118 | dedicated MCP connector tutorial | skill-or-workflow-enhancement | MERGE | `mcp-governance.md`, `security-supply-chain.md` | medium | Connector-as-translation-layer and schema-description discipline absorbed. |
| wechat-0119 | Hermes Skill Factory article | skill-or-workflow-enhancement | MERGE | `skill-curation-delivery.md` | high | Observe-propose-confirm-generate-validate boundary absorbed; project/install claims remain report-only. |
| wechat-0122 | MCP pitfalls article | skill-or-workflow-enhancement | MERGE | `mcp-governance.md` | medium | Transport smoke, structured config edits and capability mismatch triage absorbed. |

## Full-Repository Comparison

### Duplicate Check

- Existing similar skills: `adk-planning-execution-loop`, `adk-skill-composition-governance`, `adk-security-supply-chain`, `adk-runtime-router`, `mcp-builder`.
- Existing similar docs: `memory-governance.md`, `mcp-governance.md`, `skill-curation-delivery.md`, `prompt-evolution-delivery.md`, `planning-execution-loop.md`, `security-supply-chain.md`.
- Existing similar scripts: `check-memory-governance.sh`, `check-token-budget.sh`, `validate-assets.sh`, `check-skill-routing-conflicts.sh`, `check-wechat-intake-ledger.sh`.
- Result: no new Skill, MCP server, memory tool, connector implementation, prompt library or Skill Factory asset is justified; accepted material is merged into existing governance.

### Conflict Check

- Routing or trigger conflicts: none introduced; no `manifest.yaml`, profile, MCP server declaration or Skill metadata changes.
- Workflow conflicts: no change to `propose -> apply -> verify -> review -> archive`.
- Policy conflicts: external MCP servers, memory/vector tooling, Hermes Skill Factory, Rust/Python connector code and installation paths remain `report-only-until-security-review`.
- Result: pass.

### Redundancy Check

- Merge opportunities: memory implementation boundary, MCP connector selection, prompt layering, Skill factory governance and harness layers all map to existing runbooks.
- Stale or leftover assets: no new script, Skill, MCP manifest, generated connector, dependency file or platform config added.
- Result: no parallel memory framework, no MCP marketplace mirror, no duplicate prompt-engineering guide and no auto-generated Skill registry.

### Architecture Boundary

- Fits `agent-dev-kit` embedded full-stack boundary: partial. Accepted only as ADK runtime governance, connector boundary, planning harness, prompt validation and Skill curation discipline.
- Affects manifest or routing: no.
- Affects `llm_agent` governance scripts: no new script behavior; decisions overlay continues to drive ledger.
- Result: controlled merge.

## Implementation

- Files changed:
  - `reports/wechat-article-decisions.tsv`
  - `reports/wechat-article-intake.jsonl`
  - `reports/wechat-absorb-next-batch.md`
  - `reports/wechat-absorb-batch-2026-05-23-p0-005.md`
  - `agent-dev-kit/docs/runbooks/memory-governance.md`
  - `agent-dev-kit/docs/runbooks/mcp-governance.md`
  - `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`
  - `agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md`
  - `agent-dev-kit/docs/runbooks/planning-execution-loop.md`
- Files intentionally left unchanged:
  - `agent-dev-kit/manifest.yaml`
  - `subrepos/adoption-matrix.md`
  - `wechat-articles/**`
  - `~/.codex/**`
- Rejected/reference-only items and reasons:
  - Tutorial code, dependencies, install commands, external project names and platform-specific APIs were not imported.
  - Popular MCP server lists are candidate discovery only, not adoption evidence.
- External code candidates:
  - Hermes Skill Factory, Rust/Python MCP server examples, memory/vector store snippets and dedicated connector demos remain report-only.

## Verification

| Command | Result | Notes |
|---|---|---|
| `rtk scripts/check-wechat-intake-ledger.sh .` | PASS | `articles=313`; fifth-batch decisions regenerated into ledger. |
| `rtk agent-dev-kit/scripts/check-memory-governance.sh` | PASS | Memory governance regression passed. |
| `rtk agent-dev-kit/scripts/check-token-budget.sh` | PASS | ADK docs remain within token budget. |
| `rtk agent-dev-kit/scripts/validate-assets.sh --strict` | PASS | ADK strict asset validation passed. |
| `rtk agent-dev-kit/tests/run_all.sh` | PASS | 37/37 tests passed. |
| `rtk scripts/check-doc-sync.sh .` | PASS | Root docs and governance sync passed. |
| `rtk scripts/check-skill-routing-conflicts.sh .` | PASS | No routing conflicts introduced. |
| `rtk bash -lc "git diff --check"` | PASS | No whitespace errors. |
| `rtk scripts/evidence-bundle.sh . --format markdown --max-summary-chars 2000` | NEEDS-FIX | Evidence bundle points to `subrepo_state` fail: `unexpected_dirty=1`, `agent-dev-kit` dirty. |
| `rtk scripts/check-all.sh --quick` | NEEDS-FIX | 26/28 passed; failures are `check-evidence-bundle.sh` and `check-subrepo-state.sh` because `agent-dev-kit` remains dirty as strict subrepo until committed. |

## Residual Risk

- Several articles cite fast-moving MCP transports, memory frameworks, external repositories and platform-specific hook behavior. None were installed, cloned, promoted or added to manifest.
- This batch is method-only. Runtime adoption still requires `agent-dev-kit -> ~/codex -> ~/.codex` handoff evidence.
