# Implementation and verification

- `status_projection._json_object` delegates to the bounded regular-file `read_json` (1 MiB cap, no links, no duplicate keys, nonfinite rejection, nesting budget). Catch `IntakeError` and report a sanitized invalid-source result.
- `_kv` and `_md_fields` now reject duplicate parsed keys. No mutation or product decision is inferred.
- `tests/test_status_projection.sh` adds malicious source regression independent of current release authorization. The generated status projection input hash is recomputed from the exact new source Git blob and unchanged input blobs.
- Rollback both source/test/docs and generated digest in one protected PR, never alter historical Product M5 source identity or release data.
