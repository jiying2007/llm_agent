# Owner-delegated automated review

## Status and authority

- Change ID: `20261020-delegated-auto-review`.
- Root delivery contract: this proposal, [requirements](requirements.md), [design](design.md), [tasks](tasks.md), and the existing protected delivery process.
- Sole delegated review policy: the pinned ADK `.adk/review-policy.json`, with validation through `agent_dev_kit.review_evidence.validate_review`.
- Owner: `leiwenjun`; implementation: `ai/root/native_evidence_audit`; independent reviewer: `ai/root/external_methods`; delivery coordinator: `ai/root`.
- Source implementation is restored and locally verified. Final component release, Root pin promotion and protected fresh-main integration remain separate delivery work.

The user explicitly authorized autonomous progress and independent automated review, without another human approval step, at `2026-10-20T06:43:29Z`. The ADK policy binds the retained authorization text by SHA-256 `1594e628184cb0e4ad6c669bf5ce39dcb1f333d03d0798bebb080856e703cda5`. Root consumes this one policy; this change does not create a second approval system.

## Problem and intended result

The existing follow-up collector permanently reported historical source reviews as requiring human approval, even when independent Spec and Quality evidence could be checked. Harness review dates were not sufficient proof of a current source review. G22 and LTA summary reviewers were also constrained to human identities. These requirements prevented the explicitly authorized automated review from having a valid, honest consumption path.

This change accepts an identified, independent AI reviewer where the owner has delegated the review scope. The review must actually run, bind its exact source and evidence bytes, retain limitations, and return separate passing Spec and Quality verdicts. The consumer validates those facts; it does not invent a verdict. In the three historical changes, consumers also freeze the original Git base, head and complete patch digest, and require the existing canonical lifecycle.

G22 continues to require genuine pre-registered experiments, signature replay, complete current-asset measurements and individual asset decisions. LTA continues to require actual independent field evidence, registered human field actors, a complete observation window, an end-window observation and a consistent event lineage. Delegation changes the summary reviewer only. Native runtime authentication, provider execution, Product M5 and release authorization remain their own facts.

## Scope and delivery

The Root implementation is confined to the existing ADK interface bridge, qualification collector, G22 consumer, LTA consumer, related tests and runbooks. ADK owns the review schema, validator, policy and lifecycle producer. Root owns its index/schema migration and exact component promotion through the existing contracts.

Root #236 is conditional in the present research/control workspace. The collector retains its actual diagnostic output with `assessment=not-assessed`; the required-scope aggregate excludes it without turning the diagnostic into a product certifier.

The October 20 workspace reset required restoration from Root main `2722715dc44b5226d0eaf488aa00734bdade4345`. The collector and interface bridge were recovered byte-for-byte from the independently retained patch. Some other source/test bytes and these documents were reconstructed from the retained contract and must be assessed as a new candidate. [Verification](verify-report.md) separates historical results from actual recovery validation and records the exact identities.

The fresh independent review then found `ROOT-DELEGATED-AUTHORITY-001`: a worktree policy could differ from its pinned Git commit while its receipt hashes were recomputed. The bridge was further hardened to compare parent gitlink, ADK HEAD and policy/authorization/validator HEAD/index/worktree blobs. This post-recovery increment has new source hashes and additional real temporary Git tests; the initial recovery's passing tests were not represented as closing the newly found defect.

## Acceptance and remaining limits

See the [checklist](checklist.md) and [negative findings](negative-results.md). No real G22, LTA or authenticated Native qualification is claimed by these source tests. The canonical G22 index remains empty. Missing real measurements, authentic field material or provider evidence remains a valid blocked state; no fixture is promoted into those canonical records.
