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
| Full G22 suite against formal new ADK pin | Pending | Candidate unit tests are not formal pin integration |
| Protected Root CI / fresh-main readback | Pending | Delivery coordinator records actual outcomes |

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

The original LTA shell suite had already passed against the unchanged reconstructed LTA source; the new bridge behavior is additionally exercised by the real-Git delegated LTA fixtures. Full G22 against the formal new pin and protected Root/fresh-main delivery remain pending until actually executed.

The Root AGENTS final Execution Policy command was actually attempted through RTK with the current thread ID and returned exit 1: `tools.codex_assets` has no `__main__` in the restored Root checkout. The prescribed knowledge-provider executable was also unavailable. These environment/governance entry points are reported as unavailable to the coordinator; no successful gate or provider archive is claimed.

The commands used the session's actual RTK proxy and qualification virtual environment. The command structure below uses descriptive path placeholders; replace them with the actual checkout and environment paths before execution:

```bash
rtk proxy env PYTHONPATH=<adk-candidate>/src:<root-checkout> \
  <qualification-venv>/bin/python -m unittest discover -s tests -p 'test_qualification_followup*.py' -v
rtk proxy env -u PYTHONPATH <qualification-venv>/bin/python -m mypy --config-file pyproject.toml
rtk proxy env PATH=<qualification-venv>/bin:/usr/bin:/bin \
  bash tests/test_longitudinal_operation_certifier.sh
```

No original test output was recreated as if it had just run. The reconstructed source is a new review candidate wherever hashes differ. The canonical G22 index is empty, real LTA summary evidence is missing, and authenticated Native runtime qualification is not established by any of the tests above.
