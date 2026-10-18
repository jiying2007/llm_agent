# Consumer chain: reuse canonical field event-hash verification

The Root consumer-chain gate previously validated the field event log's JSON shape and referenced SHA-256 files but did not recompute each event's canonical event hash, verify the previous-hash link, monotonically increasing sequence or event timestamps. As a result, a modified event could retain a syntactically valid `event_hash` without the consumer-chain gate identifying the tampered chain.

Instead of adding a second hash-chain algorithm, `consumer_chain._pilot_binding` now calls the existing `longitudinal_operation._read_events` parser and validator on the canonical repository-local event path. This reuses existing bounded streaming and verifies the entire hash chain, time ordering, event ID uniqueness, evidence paths and each referenced evidence file's hash. It *only* selects the existing independent pilot-start reference: it does not mark LTA-04 field observations, real G21/G22 runs or Product M5 as qualified.

The existing mandatory `test_consumer_chain.sh` fixture now explicitly verifies payload tampering and broken previous-hash chain failure, as well as duplicate evidence references **with a recomputed event hash** so the duplicate check is exercised after hash validity. No real event records are edited.
