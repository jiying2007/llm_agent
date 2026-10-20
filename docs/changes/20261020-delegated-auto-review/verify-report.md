# Verification report

## Scope and actors

Implementation: `ai/root/native_evidence_audit`. Independent source reviewer: `ai/root/external_methods`. Release/promotion coordinator: `ai/root`. The independent reviewer remained read-only on the reviewed source tree. Review evidence and local tests cover software contracts; they do not prove real Native authentication, G22 effect measurements, LTA field operation, current Product M5 or release authorization.

## Original review before the filesystem reset

The independent reviewer actually ran 70 focused tests and returned Spec=pass / Quality=pass at `2026-10-20T07:30:28.390771Z`. That review covered the frozen historical base/head/patch/provenance checks, source closure, shared pinned bridge and G22/LTA reviewer boundaries. The original default no-PYTHONPATH type gate then exposed an optional-import defect in the bridge.

After the importlib and API shape increment, the independent reviewer read both changed files, reran the focused suite and recorded **72 tests PASS** at `2026-10-20T07:34:48.744294Z`. Its source hashes were unchanged before/after that execution. It explicitly did **not** independently run the implementer's default no-PYTHONPATH mypy command. The implementer actually ran that command successfully for 9 source files, Ruff, the full original LTA shell suite and `git diff --check` before the reset. Full G22 against a formal new pin had not run.

| Original final file | SHA-256 |
| --- | --- |
| `tools/control_plane/adk_interface.py` | `4d97e3e48f2633a2dccf3ffeeaef2a3061b24bb16e34b5b7b6e1fc1d1dabb8cb` |
| `tools/control_plane/qualification_followup.py` | `13fa1ef9adc60732edbaeaa97e9ffaefa81d87a1e62458233873aee182c29d5c` |
| `tools/control_plane/effect_readiness.py` | `e62a4d50e3c2e38c5a9ece505a5fb092e1fcbd8d4232fcf32fa3d80cd816f742` |
| `tools/control_plane/longitudinal_operation.py` | `19f717ebb717d08987f02a9a1e1464fe62cd5c31b237d5b5db24dcdb13fca31c` |
| `tests/delegated_review_fixtures.py` | `82bbff1ccbd7294d5df467a7c9683aef5d28e0ff307c12899cfad22263004410` |
| `tests/test_qualification_followup.py` | `108d8d66546b22dd7eb6e72956b9ac61b231f1e70115bdce3ae78b4114c84231` |
| `tests/test_qualification_followup_reviews.py` | `5313352344d1e8a6cc4229dfa4f5f7d2ca0ade876d2e0e40ef44656feef77d0a` |
| `tests/test_qualification_followup_workflow.py` | `a74357b5613b947fa5544ebcb8e9cbb3c65f0193c5a88a358898909fcd13af87` |

The earlier 70-test review had `adk_interface.py` SHA `2942548ad24a22fe2db2d83a21f69653de1bf6c5c92feb2a987d755a7e34d991` and `test_qualification_followup_reviews.py` SHA `084b5d0e3d32b6571093d6ed50c31dc25e9fd303d869e1c8874e406178e9f5ca`; the other six entries were identical. These are historical hashes, not the recovered candidate's approval.

## Initial recovery candidate and independent finding

The filesystem reset was observed at approximately `2026-10-20T11:44:00Z`. Root was cloned from main `2722715dc44b5226d0eaf488aa00734bdade4345`. The original collector and bridge were recovered exactly using the reviewer's retained raw diff, then the final bridge increment. The following other source/test bytes are reconstructed and require fresh independent review. No byte-for-byte recovery claim is made for the seven change documents or four runbooks.

| Recovered file | SHA-256 | Recovery classification |
| --- | --- | --- |
| `tools/control_plane/adk_interface.py` | `4d97e3e48f2633a2dccf3ffeeaef2a3061b24bb16e34b5b7b6e1fc1d1dabb8cb` | Exact original final bytes |
| `tools/control_plane/qualification_followup.py` | `13fa1ef9adc60732edbaeaa97e9ffaefa81d87a1e62458233873aee182c29d5c` | Exact original final bytes |
| `tools/control_plane/effect_readiness.py` | `8c1a8e8598766b2659ba1e3ef7e9a04e1000efc15dc1d22e3eddd11896f3b312` | Reconstructed |
| `tools/control_plane/longitudinal_operation.py` | `c05fa6af4779dd7205418c36ae5bb38fea34e9a77b0a31e0904ee2f8ce6219c7` | Reconstructed |
| `tests/delegated_review_fixtures.py` | `1df158345dec47b48da059a26dd38ae027b3696e60244534fdd00cd38997e88d` | Reconstructed |
| `tests/test_qualification_followup.py` | `e68f5e1feb27a515587c8dd4190c29730e216150a77b0d292bd360d64bb6e5c3` | Retained older patch plus reconstructed final cases |
| `tests/test_qualification_followup_reviews.py` | `e9ad1c8c6b44133fb5e8d6ce052c42e55dc10b4c85d0a77b32cdd9058bab8bbd` | Reconstructed |
| `tests/test_qualification_followup_workflow.py` | `a74357b5613b947fa5544ebcb8e9cbb3c65f0193c5a88a358898909fcd13af87` | Unchanged main bytes |

The implementer actually executed the following in the restored environment. The focused suite, default typing and Ruff completed before the observed clock value `2026-10-20T11:59:48Z`; the LTA shell result was retrieved immediately afterward, before `12:00:00Z`.

| Actual recovery verification | Result | Boundary |
| --- | --- | --- |
| `unittest discover -s tests -p 'test_qualification_followup*.py' -v` | 72 tests PASS, 1.066 seconds | Explicit sibling candidate ADK PYTHONPATH; synthetic fixtures |
| `env -u PYTHONPATH ... python -m mypy --config-file pyproject.toml` | 9 source files PASS | Default Root typing without importing optional ADK |
| Ruff, four modified source files and three test/helper files | PASS | Source style/static checks |
| `bash tests/test_longitudinal_operation_certifier.sh` | PASS | Full original deterministic LTA suite with explicit v2 registered-human fixture mode |
| Independent initial recovery review | 72 tests PASS at `2026-10-20T12:03:07.534666Z`, plus major `ROOT-DELEGATED-AUTHORITY-001` | Passing tests did not close the newly found authority-to-Git defect |
| Full G22 suite against formal new ADK pin | Pending at this recovery checkpoint | The later actual formal-pin run is recorded below |
| Protected Root CI / fresh-main readback | Pending at this recovery checkpoint | Final post-commit outcomes are recorded in PR #265 |

## Authority-to-Git fix and actual expanded verification

The independent reviewer found that loaded/worktree equality did not prove the policy and authorization were committed at the selected ADK pin. This major was accepted and fixed in the same bridge. It now uses bounded Git checks for parent Root gitlink == ADK HEAD, regular policy/authorization/validator HEAD blobs, matching stage-zero index entries and matching raw worktree blobs, both before and after calling the single ADK API. The bridge and fixture/test SHA values therefore intentionally changed after exact restoration.

The implementer actually ran **79 tests PASS in 5.913 seconds**, the default `env -u PYTHONPATH` mypy gate (**9 source files PASS**), Ruff on the same seven files, shell syntax for both migrated integration scripts and `git diff --check`, all completed before the observed time `2026-10-20T12:11:22Z`. These seven additional tests use real isolated Git repositories, not mocks of Git or the bridge: they reject rehashed dirty policy, changed authorization, staged authority, a rehashed validator read from the modified installed-source fixture, an unmatched ADK HEAD, and both dirty-authority/HEAD-mismatch paths in the historical inventory.

| Candidate after `ROOT-DELEGATED-AUTHORITY-001` fix | SHA-256 |
| --- | --- |
| `tools/control_plane/adk_interface.py` | `b888aa5e6e0eaec705a20c3bee3f0c32f5f00f90838965a111ceb0d163ec0202` |
| `tools/control_plane/qualification_followup.py` | `13fa1ef9adc60732edbaeaa97e9ffaefa81d87a1e62458233873aee182c29d5c` |
| `tools/control_plane/effect_readiness.py` | `8c1a8e8598766b2659ba1e3ef7e9a04e1000efc15dc1d22e3eddd11896f3b312` |
| `tools/control_plane/longitudinal_operation.py` | `c05fa6af4779dd7205418c36ae5bb38fea34e9a77b0a31e0904ee2f8ce6219c7` |
| `tests/delegated_review_fixtures.py` | `ce62d37d906d562cd5e92e24413f8abebbd782430412aa14f1ae54535ae816a8` |
| `tests/test_qualification_followup.py` | `9f55cb5554aa23ca310e4354ddfb83bf8d8a1098107d6e6b6a45cefd8cf74077` |
| `tests/test_qualification_followup_reviews.py` | `cc3f284479fb11165dc523af9dd3f9c385aba13d6ec8737b5a6000559d0e7843` |
| `tests/test_qualification_followup_workflow.py` | `a74357b5613b947fa5544ebcb8e9cbb3c65f0193c5a88a358898909fcd13af87` |

## Final independent review of the recovered source

`ai/root/external_methods` completed its actual review at **`2026-10-20T12:20:25.352831Z`**, returned separate **Spec=pass / Quality=pass**, and marked `ROOT-DELEGATED-AUTHORITY-001` **fixed**. It read the new Git helper/bridge, real Git fixtures and seven negative cases, both recovered consumer changes, the G22 shell migration, all seven change documents and the four runbooks. No unresolved source blocker remained in that scope.

The reviewer independently executed the focused suite from **`2026-10-20T12:15:59.379217Z`** through **`2026-10-20T12:16:09.271615Z`**: **79 tests PASS**, reported duration **9.647 seconds**, exit **0**. It compared nine source/test SHA values before and after the run and again at review completion; all were unchanged. The eight core entries match the final table above; the original LTA shell migration has SHA `c724572d1639e7189ea62ee8d5cfd04f838761323bc83fc8f31ea3834be4185e`. The independently read G22 shell migration has SHA `deb7fe948f0a17ab457bc8c8fad5d19a24cce1e651bdf083dd470c3ea576f8ef`.

The additional read-only peer `ai/root/external_methods/recovered_lta_peer` completed its focused LTA/bridge source review at `2026-10-20T12:14:27Z` with Spec/Quality pass. It did not execute tests. The main independent reviewer explicitly did not independently run the implementer's default mypy command and did not run formal-pin G22 integration; those results are not attributed to it.

The original LTA shell suite had already passed against the unchanged reconstructed LTA source; the new bridge behavior is additionally exercised by the real-Git delegated LTA fixtures. At this source-review checkpoint, formal-pin G22 and protected Root/fresh-main delivery had not yet run. The later G22 result is recorded below.

The earlier `python -m tools.codex_assets` attempt returned exit 1 from the Root checkout, which was the wrong directory for the prescribed final gate. The later canonical-directory preflight returned exit 2 because `/root/codex` was absent, and the actual knowledge-provider invocation returned 127 because its script was absent. Original command metadata is retained below. No successful canonical policy gate or provider archive is claimed.

The commands used the session's actual RTK proxy and qualification virtual environment. The command structure below uses descriptive path placeholders; replace them with the actual checkout and environment paths before execution:

```bash
rtk proxy env PYTHONPATH=<adk-candidate>/src:<root-checkout> \
  <qualification-venv>/bin/python -m unittest discover -s tests -p 'test_qualification_followup*.py' -v
rtk proxy env -u PYTHONPATH <qualification-venv>/bin/python -m mypy --config-file pyproject.toml
rtk proxy env PATH=<qualification-venv>/bin:/usr/bin:/bin \
  bash tests/test_longitudinal_operation_certifier.sh
```

No original test output was recreated as if it had just run. The reconstructed source is a new review candidate wherever hashes differ. The canonical G22 index is empty, real LTA summary evidence is missing, and authenticated Native runtime qualification is not established by any of the tests above.

## Formal ADK release and exact Root promotion

[ADK PR #217](https://github.com/jiying2007/agent-dev-kit/pull/217) merged through protection at `2026-10-20T12:42:40Z`. Its main commit is `42ae95d146ceb441ff91ea33dbbed581c33de305`, tree `4a034da631afbfb4b6b4d3a48310789ae85dcdbe`, manifest blob `da1a8ca2f764b6b98d79870eefa6f3fc35cfd3f8`. The exact-main [CI run 39424392443](https://github.com/jiying2007/agent-dev-kit/actions/runs/39424392443) passed, including the actual supported Python 3.8/3.11/3.12 contract/full-regression matrix. [Release workflow 39425097867](https://github.com/jiying2007/agent-dev-kit/actions/runs/39425097867) published immutable [v8.0.36](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.36) at `12:51:18Z`.

| Original artifact identity | SHA-256 |
| --- | --- |
| Promotion artifact ZIP, id 12265521136, 8,095 bytes | `d5b347a0222271c249d396f36a770eaf314e7a4e33fd138bb4bb376006bb8b1f` |
| Original promotion evidence, 1,648 bytes | `5c96e9c5e9aaa0fabf09372365852707a02399526c248ad2aeb2893443817488` |
| Original Sigstore bundle, 10,345 bytes | `ad41d2a91b2eaac851c9f044f48b2dc4c255fda54014a1be30fc1c77c1639a7b` |
| Release artifact ZIP, id 12266160054, 2,163,775 bytes | `66e216f7d7b5ee88436e832af4e90e8f619e6d10f17481f2dd903e077f3790d7` |
| Formal `agent-dev-kit-8.0.36.tar.gz`, 2,162,428 bytes | `8b0ca59998370a4fb0f67dd0f6f259ffd82eb4d0dc6b777c5f6f7478f06d0c2d` |
| Original release contract, 592 bytes | `9108e02e795344291e4505ce51d7baa35f025ad173d53b269de72ea8adec6dc4` |

The original archive bytes, member sets, CRCs, release contract and source identities were checked before use. Normal-mode Sigstore verification of the copied Root originals actually passed from `12:57:50.493165Z` to `12:57:51.270549Z`, exit 0; [raw log](evidence/root-promotion-signature.log) and [run metadata](evidence/root-promotion-signature-run.json) retain that execution. Independent reviewer `ai/root/external_methods` separately ran the canonical normal-mode verification from `13:49:31.986917Z` to `13:49:32.573042Z`, exit 0 / Verified OK, and returned Spec=pass / Quality=pass for the six-file promotion at `13:53:07.527685Z`. Neither verification disabled trust checks or substituted an unsigned result for the Sigstore bundle.

Root source C1 is `5170d970e3a69ba8d8938e968fb82bee1ff37a7d`, tree `d01282d4ef2c2c5b1c534042f5c10ef5c7ca7613`. The canonical promotion staged exactly six paths: the ADK gitlink, `adk.lock`, the interface lock, generated current status, original promotion evidence and original attestation. Remote promotion C2 is `ee47d8597aabe1ab7530905c8076dcebe13aa1cc`, tree `92e835c84609cbb3ab82cc0b6ee227e7470e5e7a`. During local validation the deliberately frozen worktree remained C1 plus those six staged paths, with ADK clean at the formal main commit.

The unmodified [promotion receipt](evidence/root-adk-8.0.36-promotion.json) has schema `llm-agent-adk-promotion/v4`, status `applied-not-verified`, `staged_transaction_complete=true` and `release_authorized=false`. Its embedded `receipt_sha256` is `387cadd2ce16905e8cbce844dff53cf4eca084eaaf38d7df77849000d0d79153`; the original file's SHA-256 is separately `e1935a8dbef64c5b3acd7e91bd42ee4083639c18122f733669d4df9d66883dcf`. Later verification does not mutate that historical transaction receipt.

## Actual formal-pin verification

The L4 validation plan identified working-tree checks and clean-commit checks separately. These are actual outcomes; Docker parity, aggregate status and source-capture status are not inferred from another successful command.

| Actual execution, 2026-10-20 UTC | Result | Retained evidence |
| --- | --- | --- |
| ADK final full, 12:27:28.871366–12:34:12.414280 | 101/101 scripts PASS; reviewed source tree equals formal main tree | [log](evidence/adk-final-regression.log), [per-script timing](evidence/adk-final-regression-timing.json) |
| ADK exact-main quick, 12:44:39.369171–12:47:33.463203 | 59/59 scripts PASS at ADK 42ae95d | [log](evidence/adk-main-quick.log), [run](evidence/adk-main-quick-run.json) |
| Original formal-pin G22, 13:44:01.322771–13:52:07.255248 | Canonical/capture exit 0; 485.933 seconds; source unchanged | [log](evidence/g22.log), [run](evidence/g22-run.json) |
| Root first full, 13:52:30.120319–13:52:50.150669 | 17 PASS / 1 FAIL / 61 unrun; PID namespace mismatch; exit 1 | [log](evidence/root-full.log), [run](evidence/root-full-run.json), [timing](evidence/root-tests-timing.json) |
| Original checker in actual host process view, 13:57:17.182185–13:57:19.321959 | PASS, exit 0; no source change | [log](evidence/check-all-contract-host.log), [run](evidence/check-all-contract-host-run.json) |
| Root second full, 13:57:45.646402–14:09:04.791854 | 53 PASS / 1 FAIL / 25 unrun; root DAC override; command 1 / capture 3 | [log](evidence/root-full-host.log), [run](evidence/root-full-host-run.json), [timing](evidence/root-tests-host-timing.json) |
| Original registration test with capabilities removed, 14:22:45.759155–14:22:52.139965 | PASS, exit 0; actual readonly negative fixture | [log](evidence/reference-registration-host-nocaps.log), [run](evidence/reference-registration-host-nocaps-run.json) |
| Root third full, 14:24:23.507792–14:37:16.119656 | **79/79 scripts PASS; command exit 0 / capture exit 3**, 772.612 seconds | [log](evidence/root-full-host-nocaps.log), [run](evidence/root-full-host-nocaps-run.json), [timing](evidence/root-tests-host-nocaps-timing.json) |
| Aggregate `--quick --working-tree`, 14:40:00.413087–14:40:51.381544 | **47 PASS / 5 FAIL; command/capture exit 1**, 50.968 seconds; source unchanged | [raw log, base64](evidence/check-all-host-nocaps.log.base64), [run](evidence/check-all-host-nocaps-run.json), [52 original results](evidence/check-all-results.json) |

The 79 full-regression **shell scripts** are distinct from the earlier 79 focused **Python tests**. G22/LTA fixtures exercise software contracts and do not create genuine effect/field qualification.

The host executions used the real `/proc` process view and, after diagnosing the root permission mismatch, `setpriv --bounding-set=-all --no-new-privs`. The first failure, original bash trace and bounded scratch diagnostic remain retained. The diagnostic copy changed only its scratch root/cleanup handling; it is not reported as an unchanged canonical pass. No production guard, test assertion, Git source, HOME or runtime policy was changed to make an execution pass.

The third run's original capture remains `source_unchanged=false`. Direct comparison found all **2,387 tracked entries** (806 Root + 1,581 ADK), index modes/stages/blobs, raw content and HEAD/tree fields unchanged; the sole delta was a generated untracked canary receipt. Both host-run canaries are preserved explicitly as synthetic diagnostic fixtures. Exact cleanup restored the original complete snapshot at `14:39:39.237065Z`; the later aggregate before/after snapshots are identical to that original. See [source identity summary](evidence/source-identity-summary.json), [original snapshot](evidence/g22-before.json) and [actual restoration record](evidence/root-full-host-nocaps-restoration.json). Their complete-snapshot identity is `24a936111d3d6cbd2965b4e0149c3c57e8a22d9c32925d7f7ad43d918cfadc09`. Cleanup does not retroactively convert either capture failure into success.

## Release build, rehearsal and unavailable local integrations

On clean ADK 42ae95d, the canonical release build actually passed from `13:47:38.662638Z` to `13:47:43.397796Z`. It declared `git-clean-commit`, dirty=false and release-eligible=true. The reconstructed tar SHA is exactly `8b0ca59998370a4fb0f67dd0f6f259ffd82eb4d0dc6b777c5f6f7478f06d0c2d`, matching the formal original. The 1,442-file source-distribution SHA is `09759d2ddb581f9d2d69a4ec08be8cd90d35e5d3a86dfdcb34155ca21462cf5f`.

The original 8.0.35 to 8.0.36 rehearsal actually passed from `13:47:43.782593Z` to `13:47:47.037584Z`: install 39, upgrade 39, rollback removes 39/restores 39, with original receipt bytes and asset permission modes restored. Original previous tar SHA is `db3af64feab4bc52a48980b264141736a0dab7294f4da30103e92d19017574b6`. The [rehearsal report](evidence/root-l4-adk-release-rehearsal-report.json) file SHA is `81d2fd47d412ea785e712f73e6d9401adea49ca6b193e74b1620f8f4887678f7`, distinct from its embedded report digest. [Validation metadata](evidence/root-l4-adk-release-validation.json), [build log](evidence/root-l4-adk-release-build.log) and [rehearsal log](evidence/root-l4-adk-release-rehearsal.log) preserve those actual results.

The separate `bash agent-dev-kit/scripts/run-local-ci-parity.sh --python all --mode full` actually ran from `13:43:22.978326Z` to `13:43:22.993640Z` and returned 2: Docker is required and absent. Its [log](evidence/root-l4-local-ci-parity.log) and [run metadata](evidence/root-l4-local-ci-parity-run.json) are preserved. No local Docker receipt or local L4 all-pass claim is issued. The canonical `/root/codex` policy/provider failures are independently retained in [policy preflight](evidence/root-canonical-policy-pre-c2-run.json) and [provider invocation](evidence/root-knowledge-provider-context-run.json).

The aggregate's three Hub/runtime absence failures, original-main reference dirty-triage failure and historical M5 mismatch remain explicit in [negative results](negative-results.md). The reference baseline reproduction and byte comparisons are retained as [raw output](evidence/reference-dirty-triage-baseline.log), [actual run](evidence/reference-dirty-triage-baseline-run.json) and [identity inspection](evidence/reference-dirty-triage-baseline-identity.json). The [M5 read-only source/artifact inspection](evidence/root-m5-readiness-inspection-20261020.json), actually repeated from `14:57:44.672240Z` to `14:57:44.995202Z`, records all 12 unchanged original-main files, exact old/current identities and the five downstream stale declarations. It does not claim a new original-main certifier or runtime execution. M5's failed check is not converted into a current product qualification by the successful source/promotion checks.

## Candidate qualification and final delivery boundary

The original candidate collector command `python3 -m tools.control_plane.cli qualification-followup --root . --summary-json` actually ran from `13:43:43.188078Z` to `13:43:44.608152Z`, exit 0. The report generated at `13:43:43.274036Z` has input digest `08152aa57fb8cf44b8e831ae490352a007c461531cada3fd56f2abf2a2be715f`, `scan_status=complete`, `source_consistent=true`, no errors, `provider_execution_performed=false` and `report_only=true`. ADK #201/#205 are ready; Native #153, Root G22 #154 and LTA #67 are blocked. Product M5 #236 is conditional, not assessed and not required in the current scope. Required/all-ready and release authorization are false. The original [collector output](evidence/root-candidate-qualification.log), file SHA `189fce9a0278e61ca3bdcba7e77d8a3322d908b239f832db2d908dfe5f451e5f`, and [run metadata](evidence/root-candidate-qualification-run.json) are retained without replacing candidate identity by future main identity.

Remote C2 [CI 39440579326](https://github.com/jiying2007/llm_agent/actions/runs/39440579326) actually completed successfully, including all six required checks and promotion-required integration-deep. C2 [qualification run 39440579166](https://github.com/jiying2007/llm_agent/actions/runs/39440579166) also passed; its original ZIP/report were independently checked and again report only #201/#205 ready. The C2 software-M5 CI job actually printed `HISTORICAL_NOT_AUTHORIZED`, `release_authorized=false` and `source-current-evidence-historical`. These are early candidate results, not the final documentation commit or a fresh-main report.

This retained evidence describes the frozen implementation/promotion checkpoint. Adding the evidence and documentation changes Root's input snapshot; its earlier digest must not be reused as a current supported-full/local-Docker receipt. The final independent documentation/evidence review, final-head required checks, protected squash merge, deferred clean-commit `scripts/check-all.sh --quick --release-clean`, main CI and original fresh-main qualification report are recorded with their actual identities in the final [PR #265](https://github.com/jiying2007/llm_agent/pull/265) body. Only a fresh-main canonical ready result closes ADK #201/#205. No final result or closure is prefilled in this pre-delivery document.
