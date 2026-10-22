# Design

## Authority

`tools/codex_assets/intake_io.py` remains the single JSON and transactional-output authority. `effect_preregistration_package.py` remains a consumer. Remove the caller's premature input `resolve()` instead of duplicating descriptor validation. Reject malformed Unicode instead of replacing characters and continuing admission.

## Publication

Check lexical symlink components before creating missing output parents. Reject nonregular existing leaves before staging and again before replacement. An optional keyword-only no-overwrite mode publishes a completed sibling stage through atomic create-if-absent semantics; a collision must not enter the committed-output rollback set or remove the competing file. Preserve the current default for existing regular-file replacement and the existing input-alias guard.

These checks assume caller-controlled parent directories. They do not claim complete isolation from arbitrary concurrent directory renames. No new file writer, parser, policy or permission gate is introduced.

The independent Quality review on 2026-10-22 reproduced a further rollback ownership error: a competitor replaces the first published no-overwrite output, then creates the second output before its link operation. The collision must preserve both competing files. Before removing a committed no-overwrite output, compare its non-followed file identity with the still-retained sibling stage; skip deletion if the path is absent or no longer names that object. Keep the normal rollback control that removes this transaction's unchanged first output. This ownership check does not claim an atomic compare-and-unlink primitive or isolation from a replacement after the check; concurrent writers still require caller coordination.

## Consumers and validation

The current G22 workflow writes canonical output to a separate runner-temporary file. Preserve that flow and ordinary explicit regular overwrite, while rejecting canonical-output aliases of the validated input. The contract CI runs pure Root intake tests before ADK initialization: keep JSON/output tests there, and put ADK-dependent G22 CLI tests on the existing preregistration-builder test path. The existing followup regression exercises malformed checker subprocess output and the final structured report.

The coordinator owns this contract. A separate implementer owns production/test changes. Independent Spec and Quality reviewers bind their conclusions to actual file hashes and retained command evidence. Full regression runs on the final integrated source after exact ADK promotion; earlier tests are labeled as targeted checks only.

## Promotion and rollback

Run the established six-path ADK promotion transaction in a clean isolated Root checkout. Integrate its exact generated lock, interface, status and original signed evidence bytes into the Root candidate and check the staged gitlink. No manual certificate, refreshed historical observation or weakened gate is allowed. Rollback is a protected source revert, with old originals and failure records retained.
