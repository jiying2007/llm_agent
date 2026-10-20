# Design

## A single ADK review validator

Root reuses the existing `tools/control_plane/adk_interface.py` for a small `validate_delegated_review` bridge. It dynamically imports `agent_dev_kit.review_evidence` so Root's default typing environment does not require the optional ADK installation. Runtime absence is a hard failure. Before calling the shared API, the bridge compares `validator_fingerprints()` from the actual loaded module with SHA-256 of three regular source files under the explicit `policy_root`:

- `src/agent_dev_kit/review_evidence.py`;
- `src/agent_dev_kit/strict_json.py`;
- `src/agent_dev_kit/readiness_evidence.py`.

Symlinks, missing files and mismatches fail closed. A strict string-keyed dictionary shape guard protects the API boundary without copying its semantic rules. The bridge owns no policy and issues no review verdict.

Recovery review `ROOT-DELEGATED-AUTHORITY-001` identified that worktree equality alone was insufficient. The bridge now uses existing bounded Git execution to require the ADK HEAD selected by the parent Root index gitlink. It obtains literal-path HEAD blob and index records for the policy, its safe authorization reference and the three modules; regular mode, unique stage-zero entries and exact inventory must agree. `git hash-object --no-filters` compares raw worktree bytes with those HEAD blobs, independently of status flags. The authority check runs before and after the unique API call. Existing G22/LTA interface/lock validation remains; this is the same source-integrity boundary for the historical inventory, not a new semantic authority.

The shared API is `validate_review(root, record_path, *, expected_subject, expected_scope, now=None, policy_root=None)`. `root` defines record and repository-relative source locations. `policy_root` points to the one pinned ADK policy and authorization. For Root G22/LTA inputs it is `root / "agent-dev-kit"`; records and original evidence stay in Root. For historical ADK changes, both bases are ADK. Deterministic tests may supply time; production callers use the actual clock.

The ADK record schema `adk-review-evidence/v1` names the subject, scope, author, independent AI reviewer, actual review/completion timestamps, separate Spec/Quality verdicts, findings, policy and validator fingerprints, nonempty source/evidence references and limitations. The validator verifies scope, identity declarations, time and bytes. It does not authenticate a platform account, produce observations, execute a provider, decide whether the actual review was insightful or grant a release.

## Frozen historical source targets

The Root consumer embeds three independently checked original Git targets. Each retained `evidence/original.patch` must match both the review record's `target.original_patch_sha256` and the constant for that subject.

| Subject | Original base | Original head | Original patch SHA-256 | Bytes |
| --- | --- | --- | --- | ---: |
| `20261016-skill-catalog-competition` | `2fe242e9e309e4111c8639e511e53f6a585a1ed7` | `d0c7a9baac8a1942be79a027b1d6feff81079b39` | `ce839fd501c606d94c57c685a38d25b907f076416f6f75f0368ea5dec1d8081d` | 19363 |
| `20261016-effort-evidence-v1` | `d0c7a9baac8a1942be79a027b1d6feff81079b39` | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` | `51c0f3da381bb1559a5039ed8dffa87cac475ab30f9309227aacc76f8591a855` | 37709 |
| `20261016-skill-description-discovery` | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` | `6fa8b40977e83569a775297371759b126406adcd` | `8f2cf5749b057db7b490403b190d6b20c765d2597b4cc17a717d0e17ce293c69` | 32109 |

The original material was generated from those Git commits with `diff.algorithm=myers`, `diff.indentHeuristic=false`, `core.quotePath=true` and options `--binary --full-index --no-renames --no-ext-diff --no-textconv --no-color --src-prefix=a/ --dst-prefix=b/ --unified=3 --inter-hunk-context=0`. Both the coordinator and independent reviewer recomputed the three hashes before the reset. Runtime consumers need no new Git diff execution: they compare the frozen identities and retained bytes.

## Unique lifecycle and archive provenance

`_change_location` permits one active `docs/changes/<id>` or one `docs/changes/archive/YYYYMMDD-<id>`, bounded to 4096 archive entries. Active/archive duplication, unsafe ancestry or a non-directory package is invalid.

Active consumption requires `stage: review-passed`. Archived consumption requires `stage: archived` and the existing `adk-change-provenance/v1` metadata with unique fields. The consumer checks change ID, canonical authority, `source_stage=review-passed`, `final_stage=archived`, `review_verdict=pass`, reviewer identity and exact review record SHA. The archive timestamp must be canonical UTC, at or after the review and no later than the current time. `archived_by` preserves the actual lifecycle operator. It may differ from `reviewer_id`; the state owner is not a semantic-review identity.

## Scope-aware, source-bound collection

The report schema advances to `llm-agent-qualification-followup/v2`. Each item includes `required_in_current_scope`. Root #236 keeps its actual canonical diagnostic result but is projected as conditional, `assessment=not-assessed`, and outside the present required research/control scope. `qualification_all_ready` retains the all-six meaning. `required_qualification_ready` requires a complete consistent scan and all required items. Neither flag grants a release.

The bounded input snapshot includes the policy authorization, three modules, all historical review materials, seven Harness pointers and all their declared inputs. It also follows Root's G22 index `review_evidence_path` and LTA summary `review.evidence_path`, retaining the correct repository base for each record. Safe canonical paths, count/byte budgets and strict JSON parsing apply. Before/after drift invalidates the scan. Harness #205 remains a direct canonical gate evaluation at the current date; the collector does not rewrite dates or issue review evidence.

## G22 schema v6

The empty canonical index and decision schema advance to `llm-agent-effect-value-evidence-index/v6` and `llm-agent-effect-owner-review/v6`. The index adds `review_evidence_path` and `review_evidence_sha256`. The decision identifies `reviewer_role=owner-delegated-ai` and `automation_generated=true`.

A separate record with scope `effect-value-review` and campaign subject binds all nine documents: campaign, comparison, authority contract, authority registry, receipt set, measurement, pre-registration package, pre-registration signature bundle and decision. Root cross-checks the validated reviewer/time, index digest and completed-evidence timestamp. The decision does not hash the review record, avoiding a circular dependency. Existing signed replay, experiment provenance, exact current asset coverage, per-asset decisions and complete observed-case checks stay in place. Old v5 content receives no implicit approval migration.

## LTA summary schema v2

`llm-agent-longitudinal-operation-evidence/v2` requires explicit `review.mode`. `registered-human` preserves the original registered reviewer contract. `owner-delegated-ai` uses `reviewer_id`, standard `owner-delegated-ai-review-v1`, decision/time and `evidence_path` for a record of scope `longitudinal-review`, subject `lta-04/<pilot_id>`.

The record binds the summary plus the pilot ledger and LTA manifest. The summary already binds event-log SHA, count and chain head, while events bind original evidence files. Only the record path appears in the summary to avoid circular hashes. All original full-window, end-observation, field-layer, registered human event-actor, risk and late-recorded-event rules remain. Delegated completion cannot precede actual completed field material. Real terminal mode additionally validates the exact pinned interface and committed HEAD bytes for the record and its entire referenced source/evidence closure. `--as-of` stays explicitly simulated.

## Validation and recovery

The [verification report](verify-report.md) records original reviewed hashes and recovery candidate hashes separately. The original collector and bridge were restored exactly. Reconstructed consumer/tests and seven documents are reviewed anew. Source tests do not satisfy the formal release/pin, full G22 integration or current-source protected main gates; those remain tracked [tasks](tasks.md).

After exact restoration, the bridge received the authority-to-Git fix above, so its final SHA intentionally differs from the original reviewed version. The test policy helper creates actual isolated Root and ADK repositories and a real gitlink. Additional negative cases keep HEAD fixed while changing/re-hashing policy, authorization or validator bytes, stage an authority change, or check out an ADK commit different from the Root pin; the historical inventory exercises the same rejection path. These temporary Git fixtures do not mutate the canonical authorization or real field evidence.
