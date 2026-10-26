# Current product projection input boundaries

## Requirement
Keep the existing authoritative status projection and historical product qualification isolation. Fail closed on malformed, duplicated, non-finite, deeply nested or oversized JSON in the product scorecard and M5 policy. Reject duplicate lock keys and duplicate status fields so conflicting claims cannot silently overwrite one another. Do not elevate product release qualification.

## Ownership
The existing `tools.codex_assets.intake_io.read_json` is the canonical reader; no new parser, rule configuration or parallel state projection is allowed.
