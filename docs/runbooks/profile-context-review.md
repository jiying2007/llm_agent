# Profile context and target source observability

This Root consumes the exact ADK source pinned by `adk.lock`. Profile footprint and target source probes are software/source evidence only; they do not certify native runtime behavior or product qualification.

Use:

```bash
python -m pip install ./agent-dev-kit
adk profile-footprint --profile core --ratchet --summary-json
adk profile-footprint --profile core --compare embedded-fullstack --summary-json
adk target-source-probe --target claude-code --profile core --summary-json
adk target-source-probe --target opencode --profile core --summary-json
```

Interpretation rules:

- `frontmatter_surface`, `entry_body_surface`, and `deferred_support_surface` are source byte surfaces. None is a claim about a native runtime's initial prompt.
- Token estimates are bytes/4 heuristics, not provider tokenizer or billing measurements.
- The ratchet prevents silent source-surface growth. It is not an effectiveness score.
- `target-source-probe` only validates isolated exported layout, file digests, and source loadability. Native discovery/load/trigger remains a separate runtime evidence layer.
- A context-cost reduction may be considered for adoption only together with repeated-task effect evidence showing the declared quality/safety guardrails remain non-inferior.
- Synthetic Root regressions prove consumer compatibility, not model-task benefit.

The release/product boundary remains authoritative in `reports/current-status.md`; source observability never sets `release_authorized=true`.
