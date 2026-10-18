# ADK portable promotion input hardening

## Scope and risk
The local `tools.control_plane.adk_promotion` preflight previously called unbounded `Path.read_text` plus default `json.loads` on promotion evidence and its Sigstore bundle. Standard JSON parsing silently keeps the last duplicate object key, accepts `NaN` and overflow to Infinity, and follows symlink paths. Protected CI verifies the signed release separately, but the local transaction should reject malformed/untrusted inputs **before staging** the six-path source/evidence update.

## Decision
Reuse `tools.codex_assets.intake_io.read_bytes` and `decode_json`, with the existing 1 MiB Sigstore bundle budget, strict UTF-8, descriptor-bound regular-file checks, parent/leaf symlink rejection, nested duplicate-key rejection, nonfinite and nesting budgets. Preserve the original exact UTF-8 text bytes for the independently verified Sigstore signature. No second registry or verifier, no change to the immutable ADK release, and no change to Python 3.8+ compatibility.

## Verification
The existing always-run `adk-promotion-transaction` gate exercises valid exact-source staging/rollback plus negative duplicate-key, nonfinite, oversized, symlink-leaf/parent and invalid UTF-8 inputs. PR and post-merge fresh-main must both pass; component Release/Product M5/native/G22/LTA-04 authorities are unchanged.

## Rollback
Only by protected PR, maintaining equivalent fail-closed parsing; never remove input-size and duplicate-key protections to recover a green test.
