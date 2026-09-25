# Campaign readiness projection requirements

1. Compose existing Root status/pin data and exact ADK worktree state without creating a new authority.
2. Distinguish software readiness from real effect/native evidence and from product release authorization.
3. Report G21/G22 blockers deterministically without reading credentials or raw runtime/task content.
4. Make CI gate only software prerequisites; external evidence absence must remain visible but must not block ordinary development.
5. Verify ADK worktree version/commit against `adk.lock` before declaring software-ready.
6. For native readiness, inspect managed authority count and direct target conformance state; source/static evidence must never become native certification.
7. Public `llm-ctl campaign-readiness` addition advances the Root control-plane package from 0.2.0 to 0.3.0.
