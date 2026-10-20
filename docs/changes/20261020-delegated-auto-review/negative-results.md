# Negative findings and retained limits

## Diagnosed defects corrected in source

1. **A matching historical head did not fix the reviewed diff.** An arbitrary base, including the head itself, could describe an empty or different change. The consumer now requires the independently checked original base and head pair for each historical subject.
2. **Commit strings alone did not bind original material.** A review could attach unrelated bytes to the right strings. The shared validator requires a retained nonempty record-relative `evidence/original.patch`; Root checks its SHA against the three original complete Git diffs. This establishes retained byte identity, not external identity authentication.
3. **An archived state alone did not establish lifecycle provenance.** Missing or contradictory `provenance.md` could be treated as complete. Root now checks the existing provenance schema, source/final stages, exact reviewer and review digest, unique metadata and chronology. `archived_by` remains the actual coordinator and can differ from the reviewer.
4. **An installed ADK could validate a receipt using its own old module bytes.** A correct checkout lock did not constrain Python import origin. All three Root consumers now use the shared bridge to compare actual loaded module fingerprints with the explicit pinned source files before invoking the sole API. Missing, symlinked or mismatched sources fail closed.
5. **Candidate PYTHONPATH concealed a default typing failure.** The initial bridge statically imported the optional ADK and returned an unconstrained Any value. The default Root mypy gate exposed import-not-found and no-any-return. A dynamic optional import and a string-keyed dictionary result guard fixed those errors without duplicating review semantics. Runtime dependency absence still fails.
6. **`ROOT-DELEGATED-AUTHORITY-001` — current authority bytes were not bound to the pinned Git commit.** Fresh independent review of the recovered candidate found a major even though its 72 focused tests passed. Matching loaded/worktree validator bytes and an ADK HEAD label still allowed an uncommitted policy/authorization rewrite plus receipt rehashing. The shared bridge now verifies the parent Root index gitlink against ADK HEAD, and policy/authorization/three-module regular HEAD blobs against index and raw worktree bytes before and after the shared API. Seven new real temporary Git negative cases cover dirty/staged/rehashed authority, mismatched ADK HEAD and the historical consumer. The expanded 79-test suite actually passed; independent closure requires the review of this changed byte set.

The final independent review by `ai/root/external_methods` at `2026-10-20T12:20:25.352831Z` marked `ROOT-DELEGATED-AUTHORITY-001` **fixed** and returned separate Spec=pass / Quality=pass for the current source. The reviewer actually reran 79 tests, ending at `12:16:09.271615Z`, with source hashes unchanged before/after and at review completion. Its new review, not the prior 72-test result, closes this finding. The additional read-only LTA/bridge peer review at `12:14:27Z` also passed; that peer did not claim test execution.

## Deterministic negative coverage

The focused fixtures cover wrong historical heads/bases/patches, missing lifecycle, duplicate active/archive locations, missing/duplicated/mismatched archive metadata, archive time before review or in the future, unsafe references, policy/source drift, author/reviewer equality, malformed API results and all three installed-versus-pinned module mismatches.

G22 rejects omitted original experiment/decision documents, mismatched review identity or time, incomplete observed cases, missing per-asset decisions, false claims of human/unautomated review and review before evidence completion. LTA rejects a missing final field observation, synthetic evidence layers, an AI reviewer pretending to be a registered human field operator, digest drift, wrong pilot scope, missing source contracts and a review hold. The original LTA shell suite continues to check the full event and committed-source boundaries.

## Environment recovery

At approximately `2026-10-20T11:44:00Z` the session had a new filesystem and the previous worktrees/RTK/venv were absent. Root main and tooling were restored. An independent reviewer had retained the collector and initial bridge diff, allowing those two final files to match their old reviewed SHA exactly after the final importlib increment. No complete old copy of every other changed file was recovered. Those files and this seven-document package were reconstructed and treated as new source for validation and independent review.

The historical independent results at `07:30:28.390771Z` and `07:34:48.744294Z` remain historical; they are not evidence that recovery succeeded. New tests actually ran on the reconstructed candidate. The [verification report](verify-report.md) records both sets separately. Root's knowledge provider executable was unavailable in the restored environment; that integration was not silently claimed as passed.

The earlier recovery attempt ran `python -m tools.codex_assets` from the Root checkout and exited 1 because that package has no `__main__`. That was the wrong execution directory and is not the prescribed final gate. The later canonical-directory preflight actually found `/root/codex` absent and exited 2; the prescribed knowledge-provider invocation exited 127 because its script was absent. Their original command metadata and output are retained in `evidence/root-canonical-policy-pre-c2-run.json` and `evidence/root-knowledge-provider-context-run.json`. No successful Execution Policy gate, provider archive or source-to-live installation is claimed.

## Formal-pin validation failures and bounded corrections

The first complete Root regression attempt stopped at script 18 with 17 PASS / 1 FAIL. The sandbox PID namespace and mounted `/proc` described different process identities, so the same-run guard rejected its integration fixture. The original checker, run-all script and identity helper bytes are unchanged from main `2722715dc44b5226d0eaf488aa00734bdade4345`. Running the original checker in the actual host process view passed; the scratch diagnostic copy is retained only as diagnosis and is not canonical PASS evidence.

The second complete attempt stopped at script 54 with 53 PASS / 1 FAIL. The host process had root DAC override, making a chmod-555 negative fixture writable. A real permission probe and the original registration test passed after removing process capabilities with `setpriv --bounding-set=-all --no-new-privs`. No test assertion, source guard, HOME, runtime configuration or permission policy was changed. The third original full suite then passed all 79 scripts.

Both host full runs separately left one untracked, test-generated Native canary. The capture honestly returned exit 3 and `source_unchanged=false`; all 806 Root and 1,581 ADK tracked entries, modes, index stages/blobs and HEAD/tree identities remained equal. Each exact receipt was preserved before its exact deletion. The final cleanup restored snapshot `24a936111d3d6cbd2965b4e0149c3c57e8a22d9c32925d7f7ad43d918cfadc09` at `2026-10-20T14:39:39.237065Z`. The original cleanup errno was not observed; filesystem synchronization and residue observations do not prove a source-code cleanup defect. Neither original capture is rewritten after cleanup.

## Aggregate failures that remain visible

The canonical `scripts/check-all.sh --quick --working-tree` ran from `2026-10-20T14:40:00.413087Z` to `14:40:51.381544Z`, returning exit 1 with **47 PASS / 5 FAIL**. The complete before/after source snapshot was identical. Its original output is retained losslessly as `evidence/check-all-host-nocaps.log.base64`; original per-check results are in `evidence/check-all-results.json`.

| Failed check | Actual cause and boundary |
| --- | --- |
| `check-global-codex-health.sh`, exit 2 | `/root/codex/scripts/doctor.sh` is absent. |
| `check-global-codex-target-policy.sh`, exit 1 | The canonical `/root/codex` declaration repository is absent. |
| `check-runtime-health.sh`, exit 2 | The runtime adapter depends on the same absent doctor script. |
| `check-reference-dirty-triage.sh`, exit 1 | OpenSpec, superpowers and vibeflow dirty reviews expired on 2026-10-14; all three current worktrees are absent. |
| `check-software-m5-readiness.sh`, exit 1 | Historical policy expects ADK 5.0.0-rc.2 while current promotion is 8.0.36; its five scorecard claims are stale downstream of that identity rejection. |

The reference failure was reproduced using original main-272 checker bytes from stdin with byte-identical dependencies and all seven triage JSON inputs, at `14:49:41.991634Z` to `14:49:42.085919Z`, exit 1. This is a bounded checker reproduction, not a claim to have rerun a complete old checkout. Read-only diagnosis separates `review-record-expired-or-future` from `repository-unavailable`. Immutable upstream pins can support later clean-source inspection but cannot recreate or approve the old 655/115/216 dirty changes. Neither a new clean clone nor a changed expiry date supplies those missing bytes.

Read-only inspection of original main-272 Git blobs also shows the M5 policy already expected 5.0.0-rc.2 while that main's promotion was 8.0.35. Twelve M5 code/evidence files are unchanged. The current version error occurs before signature/runtime/field/qualification validation; it does not show a broken current promotion signature. The five historical `software_m5` claims are `readiness_status=m5-ready`, `eligibility_status=release-qualified`, `certification_status=pass`, `certified=true` and `blocking_gates=[]`; the current assessor computes `not-ready`, `blocked`, `blocked`, `false` and `[evidence_integrity]`. Merely changing those declarations would not establish qualification. Current runtime, pilot and qualification evidence remain bound to older ADK sources, and no paid provider or fabricated current field execution is started to replace them.

The independent L4 Docker parity command actually returned exit 2 because Docker is unavailable. A successful remote CI run, a host regression or Sigstore verification is not a local Docker parity receipt. The clean-commit Root `--release-clean` check remains deferred to the final clean commit and is recorded in the final PR body, not prefilled here.

## Delivery and genuine qualification limits

ADK immutable 8.0.36 release, exact Root promotion, original artifact verification, release build/rehearsal and formal-pin G22 integration have now actually completed. Final documentation review, final-head protected Root CI and fresh-main qualification are the delivery steps that follow this evidence snapshot; [PR #265](https://github.com/jiying2007/llm_agent/pull/265) records their eventual actual outcomes.

The candidate collector actually completed with source consistency and no errors, reporting ADK #201/#205 ready. Closure still requires its fresh-main readback. The canonical effect index is empty, the real LTA summary has not been supplied, and source fixtures do not prove Native provider authentication. Product M5 is conditional outside the current research/control-workspace qualification scope, with `release_authorized=false`. No actual runtime/field event, owner impersonation or generated human verdict is added by this source change.
