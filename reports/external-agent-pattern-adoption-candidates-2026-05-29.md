# External Agent Pattern Adoption Candidates - 2026-05-29

## Scope

This report records method-only adoption candidates from `caveman`, `claude-mem`, `compound-engineering`, and Karpathy-style LLM Wiki patterns for `llm_agent` and `agent-dev-kit`.

The batch does not install, clone, enable, run, or import any external plugin, hook, worker, MCP server, package-manager command, vector service, background process, or runtime configuration. Runtime adoption remains blocked until a separate security and supply-chain review targets a specific versioned asset.

## Sources

| Source ID | Source | Local Evidence | Decision |
|---|---|---|---|
| `mattpocock-caveman-skill` | https://skilld.dev/skills/mattpocock/skills/caveman | `mattpocock-skills/skills/productivity/caveman/SKILL.md` | adopt-method-only |
| `thedotmack-claude-mem` | https://github.com/thedotmack/claude-mem | `dotfiles/home/base/tui/AI/claude.nix` | adopt-method-only |
| `everyinc-compound-engineering` | https://github.com/EveryInc/compound-engineering-plugin | `dotfiles/home/base/tui/AI/skills-catalog.nix` | adopt-method-only |
| `karpathy-llm-wiki-pattern` | https://karpathy-wiki.lol/en | `hermes-agent/skills/research/llm-wiki/SKILL.md` | adopt-method-only |

## Adopted Patterns

### P0: LLM Wiki Compile Model

Absorb the three-layer model:

- raw sources: immutable source material;
- maintained wiki: agent-maintained synthesis pages;
- schema: conventions, naming, frontmatter, links and maintenance rules.

Absorb the recurring loop:

- ingest: add source and update relevant pages;
- query: answer from compiled knowledge and file valuable synthesis after review;
- lint: check stale claims, weak links, orphan pages and unresolved questions.

Landing target: `agent-dev-kit/manifests/external_agent_pattern_contracts.json`.

### P0: Codify After Delivery

Absorb the Plan -> Delegate -> Assess -> Codify loop as a completion-time governance question:

- did this task produce a reusable convention, component, runbook or manifest update;
- should the learning be promoted, deferred or explicitly rejected as one-off noise;
- does promotion have owner review, verification evidence and rollback.

Landing target: `agent-dev-kit/manifests/external_agent_pattern_contracts.json`.

### P1: Progressive Memory Search

Absorb the memory-search pattern:

- search index first;
- timeline context for scoped IDs;
- observation details only after filtering and with a recorded fetch reason.

This preserves token budget and avoids dumping historical observations into active context.

Landing target: `agent-dev-kit/manifests/external_agent_pattern_contracts.json`.

### P2: Low Token Communication Profile

Absorb a terse communication profile for explicit low-token requests and context pressure, with safety exceptions for security warnings, irreversible actions, ambiguous multi-step instructions and precise review findings.

Landing target: `agent-dev-kit/manifests/external_agent_pattern_contracts.json`.

## Rejected Or Deferred

- Do not import full `compound-engineering` skill/agent inventory.
- Do not enable `claude-mem` automatic capture, hooks, worker service, local HTTP port, SQLite/Chroma backend or MCP tools.
- Do not make `caveman` the default response style.
- Do not replace `docs/archive`, `memory-curator`, `knowledge-archive` or ADK memory governance with an external wiki tool.
- Do not treat stars, marketplace presence or social proof as trust evidence.

## Supply Chain Boundary

Any runtime adoption needs a separate review covering:

- source URL and version or commit;
- license;
- install surface and package-manager commands;
- hooks and background processes;
- local ports and MCP tools;
- data retention and redaction;
- deny-path and secret scan;
- rollback and disabled-by-default evidence.

## Validation Targets

```bash
rtk bash agent-dev-kit/scripts/check-external-agent-patterns.sh
rtk bash scripts/check-adk-external-agent-patterns.sh
rtk bash scripts/check-adoption-evidence-integrity.sh
rtk bash agent-dev-kit/scripts/validate-assets.sh --strict
```
