# Research operational scope

The ADK/llm_agent workspace is a non-release research and asset-distribution control plane. Source and CI readiness must be distinct from authenticated native runtime conformance, real model-effect campaigns, 30-day independent field operation, and current candidate Product M5 certification.

## Explicit scopes

- Default: `python3 -m tools.control_plane.cli terminal-closure --root . --scope research --require-terminal --summary-json`. Requires software readiness, G9's real owner decision, LTA-01 repository governance and LTA-03 clean-room recovery. G21/G22 remain truthfully reported in `optional_evidence`; LTA-04 is separate field qualification.
- Strict: `python3 -m tools.control_plane.cli terminal-closure --root . --scope qualification --require-terminal --summary-json`. Preserves all original real-evidence gates for G21 and G22 and the existing readiness calculations.
- Field: `python3 -m tools.control_plane.cli longitudinal-operation --root . --summary-json`. Still requires authentic LTA-04 field events and independent review, if that qualification is deliberately requested.

The policy authority for non-release research is `manifests/long_term_asset_qualification.json:research_scope_policy`. Only LTA-01/LTA-03 are operational control prerequisites; the previously frozen field record remains `qualification_pending` and no fake events, zero-incident claims, or approvals may be fabricated.

## Never infer release authorization

A research-scope `terminal_ready=true` does **not** mean G21 native success, G22 measured effects, LTA-04 field certification, Product M5 qualification, or `release_authorized=true`. These validators are retained and fail closed for future opted-in certification. The original evidence index, append-only ledger, signatures, immutable release source identity and trust registries must not be rewritten. No Codex/Work shared budget, paid provider or device writes are required by this scope migration.

The tracking issues ADK #153, Root #154, Root #67 may be closed as **not planned for research scope**, never as completed evidence. Reopen a new qualification task if real deployed products or certified targets are explicitly required.
