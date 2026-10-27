# Design and rollback

Reuse `tools.codex_assets.intake_io.read_bytes` for `adk.lock` (64 KiB), current-status reading and regeneration (256 KiB). Decode captured bytes as strict UTF-8. Map unsafe, oversized, or undecodable input to a sanitized RuntimeError. Keep the lock and Markdown field grammar, prior duplicate-key behavior, generated status and all Product M5 qualification rules unchanged.

Because the status projection source is itself a projection digest input, update the generated status hash from exact new source Git blob `9d7257537f1d5d5492d0d8f79542642ea5410393` and all four unchanged source blobs. Test normal input, size, encoding, FIFO, symlinked file and symlinked parent paths.

Rollback source, test, docs and generated digest together through protected PR; no direct main edits or signed release reinterpretation.
