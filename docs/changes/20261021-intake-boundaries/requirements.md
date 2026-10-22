# Intake input and output boundaries

## Goal

Repair independently reproduced failures at the existing Root intake boundary. The baseline is Root `ae99e12f187bcab6b67a6e7dc7cb65cbc8c64a97`. The work concerns strict JSON transport, safe output publication and G22 consumers of those existing authorities.

## Acceptance

1. JSON bytes must be UTF-8. Every string value and object key must contain Unicode scalar values that can be UTF-8 encoded. Invalid encoding and isolated surrogates raise sanitized `IntakeError`; valid Chinese, emoji and paired escapes remain accepted.
2. Invalid checker JSON is represented by a structured `invalid-checker-json` result with its original exit and output hashes. Final qualification output remains serializable, contains other check results, and grants no qualification or release authority.
3. Transactional destinations must be absent or regular files. Directory, FIFO, symlink and special-node rejection preserves every original destination. Invalid second outputs cannot partially update the first. Destination type is checked before publication as well as during preflight.
4. Explicit no-overwrite publication must preserve an existing destination even if it appears after preflight. If a published output has already been replaced before rollback examines it, cleanup must preserve that competing object and remove only an output whose identity still matches this transaction's stage. Existing callers retain ordinary regular-file replacement by default and existing rollback behavior.
5. G22 source/package inputs retain their lexical path for the existing descriptor and symlink guards. G22 outputs reuse the common writer, reject unsafe components and input aliases, and preserve default no-overwrite plus explicit regular-file `--overwrite` behavior.

## Scope

No provider, real Native campaign, field observation or new qualification is produced. Existing true evidence gaps remain blocked or conditional. A separately reviewed ADK 8.0.38 component fix will be promoted only after its protected main CI and immutable release are independently verified.
