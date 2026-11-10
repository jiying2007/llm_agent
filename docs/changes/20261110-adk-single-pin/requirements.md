# Root ADK upgrade simplification — requirements

1. The indexed ADK Git submodule commit is the only authoritative version pin. Version, tree, and manifest Git blob are derived from the pinned commit on every check; no second lock may silently authorize different source.
2. Runtime interface checks are independent of immutable source identity and can fail closed on missing or retired API surfaces.
3. For a changed upstream commit, trust must derive from immutable, successful ADK main CI, the released tag and a Sigstore-signed provenance bundle bound to the exact pin and immutable release asset digest.
4. Authentic old signatures are verified by their signature, certificate and trusted provenance, rather than rejected solely because an arbitrary 30-day timer elapsed. Future-dated evidence remains invalid.
5. Publish and source upgrade are not device-write permission. Native model effect, product field and owner authorization remain separate gates.
6. No paid model trials, Codex/Work quota, private repositories or periodic polling tasks.
7. Old six-path promotion remains operational until all consumers are migrated and acceptance tests can prove the new lane; never remove the old checks before an equivalent protected CI gate is in place.
