# OSS Score Report

> Status: report-only
> Source ledger: `reports/oss-discovery-candidates-2026-07-11.jsonl`

## Summary

- candidates: 12
- scored: 12
- unscored: 0
- rejected: 2
- watch: 10

## Candidates

| repo | domain_fit | score | decision | hard_rejects | reason |
|---|---|---:|---|---|---|
| obra/superpowers | workflow-core | 89 | watch |  | already active-core locally; continue monthly tracking but no duplicate onboarding |
| addyosmani/agent-skills | agent-ecosystem | 88 | watch |  | active release stream and lifecycle quality gates justify observe-light tracking; ADK already covers the core flow |
| mattpocock/skills | agent-ecosystem | 86 | watch |  | new releases after prior absorption justify sampled watch; no full reinstall or submodule registration yet |
| affaan-m/ECC | workflow-core | 84 | watch |  | active and broad harness; high context and hook/runtime surface keeps it watch-only pending security review |
| jeremylongshore/claude-code-plugins-plus-skills | knowledge | 82 | watch |  | actively released marketplace/catalog source; discovery feed only until CLI/install surface is reviewed |
| ComposioHQ/awesome-claude-skills | knowledge | 80 | watch |  | curated skill list with Apache-2.0 top-level license; discovery feed only, individual skills still require review |
| VoltAgent/awesome-agent-skills | knowledge | 80 | watch |  | already discovery-only locally; current breadth supports continued metadata watch, not runtime adoption |
| alirezarezvani/claude-skills | agent-ecosystem | 80 | watch |  | large cross-platform skill pool remains selective-only; sample by domain and run supply-chain review before adoption |
| hesreallyhim/awesome-claude-code | knowledge | 78 | watch |  | owner-requested navigation source with high activity; watch as discovery feed because license is not SPDX-clear on GitHub summary |
| rohitg00/awesome-claude-code-toolkit | knowledge | 75 | watch |  | owner-requested broad toolkit source; watch only because hooks/MCP/apps increase review cost and current score stays below registration threshold |
| ComposioHQ/composio | tooling | 0 | rejected | private-or-hosted-dependency | requires external service credentials and open-world tool actions; only enter security review for a concrete integration request |
| multica-ai/andrej-karpathy-skills | agent-ecosystem | 0 | rejected | missing-license,duplicate-without-advantage | no clear license in GitHub API and principles are already covered by AGENTS/ADK rules; keep archive-only reference |

## Report-Only Boundary

- This report does not register repositories.
- This report does not update `.gitmodules`, `subrepos/registry.csv`, or `subrepos/adoption-matrix.md`.
- `onboard-candidate` means eligible for later gated onboarding review, not automatic registration.
