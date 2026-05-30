# ADK Capability Runtime Pilot - 2026-05-30

## Scope

本报告记录一次小型运行态试跑，用于验证 2026-05-29 已落地的 ADK 能力入口是否能在真实 Codex/ADK 工作流中被触发、审计和验证。

本轮不继续新增治理契约；只允许小范围修复 pilot 暴露的运行态偏差。3 个子代理均为只读评测，主线程负责整合报告和必要修复。

## Preflight

| Command | Result | Notes |
|---|---|---|
| `rtk bash ~/codex/scripts/final-ready.sh` | pass | 记录到 `/home/leiwenjun/codex/.cache/session-coach-evidence.json`；同时提示当前线程处于 handoff 阶段。 |
| `rtk bash ~/codex/scripts/session-coach.sh --deep` | HOT | `CTX_PRESSURE` high，输入约占 context window 84%；适合收口为报告并新开窄线程继续。 |

## Runtime Commands

| Capability | Command | Result |
|---|---|---|
| Codify after delivery | `rtk bash agent-dev-kit/scripts/devkit.sh codify-governance` | `[PASS] codify governance` |
| Knowledge Compile | `rtk bash agent-dev-kit/scripts/devkit.sh knowledge-compile` | `[PASS] knowledge compile model` |
| Progressive Memory Search + Low Token Profile | `rtk bash agent-dev-kit/scripts/devkit.sh context-experience` | `[PASS] context experience patterns` |
| Low Token Profile budget gate | `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json` | `status=pass`, `failures=0`, `context_governance_assets=8` |

## Pilot Results

| Scenario | Triggered skill / command | Actual behavior | Deviation | Next upgrade decision |
|---|---|---|---|---|
| Codify after delivery pilot | `adk-after-action-review`, `adk-verification-before-completion`, `devkit.sh codify-governance` | AAR and completion gate both require Codify Decision. Template includes `promotion_candidate`, `do_not_promote_reason`, `owner_review`, `rollback_path`, `verification_evidence`, `negative_or_disproved_path`. | Current gate proves field/text presence, not an actual filled Codify Decision artifact. No true/false fixture validates non-empty fields or branch semantics. | Enter next upgrade as semantic fixture + stricter gate, not more contract text. |
| Knowledge compile pilot | `adk-token-context-governance`, `devkit.sh knowledge-compile` | Runbook and template preserve `raw_sources / maintained_wiki / schema`. Query rules prevent treating maintained wiki as primary evidence for high-risk or promotion decisions. | No filled Knowledge Compile note or query trace was found in scoped review. Field names across `raw_source_path`, `raw_sources`, `raw_evidence`, `raw_fallback`, `fallback_condition` need an explicit mapping before deeper automation. | Enter next upgrade as example artifact + instance validation. |
| Progressive memory search pilot | `adk-token-context-governance`, `devkit.sh context-experience` | Runbook defines `search_index -> timeline_context -> observation_details`. Template keeps `redaction_status`, `detail_fetch_reason`, `raw_fallback`, and owner approval boundary. | Current scripts check keywords, not a filled result proving detail fetch only occurs after `detail_fetch_reason`. | Enter next upgrade as filled search result fixture + read-layer validation. |
| Low token profile pilot | `adk-token-context-governance`, `check-token-budget.sh --summary-json` | Runbook preserves commands, paths, source references, risks, verification evidence, blockers, and restores full clarity for safety exceptions. | Runtime trigger test initially failed: `请低 token 汇报，但保留命令路径风险和验证证据` did not match `adk-token-context-governance`. | Fixed in this pilot by adding trigger phrases and trigger matrix cases. Further upgrade should add safety-exception examples. |

## Fix Applied

Runtime pilot exposed one concrete trigger gap. The first fix stayed intentionally narrow:

- `agent-dev-kit/skills/adk-token-context-governance/SKILL.md`
  - Added triggers for `低 token`, `Low Token`, `Low Token Profile`, `知识编译`, `Knowledge Compile`, `渐进记忆检索`, `Progressive Memory Search`.
- `agent-dev-kit/tests/fixtures/skill_trigger_cases.tsv`
  - Added positive routing cases for low-token status reporting, Knowledge Compile, and Progressive Memory Search.

This does not add new governance fields, scripts, manifests, or templates. It only aligns skill trigger routing with already documented runtime capabilities.

The follow-up optimization moved the gates from pure text-presence checks to minimal instance checks:

- `agent-dev-kit/tests/fixtures/codify-decision/`
  - Added `promotion_candidate_true.md` and `promotion_candidate_false.md` fixtures.
  - `check-codify-governance.sh` now checks promotion branch semantics, rollback evidence, and negative/disproved paths.
- `agent-dev-kit/tests/fixtures/knowledge-compile/example-note.md`
  - Added a filled Knowledge Compile note with `raw_source_path`, `wiki_page_path`, `schema_path`, and `raw_fallback`.
  - `check-knowledge-compile-model.sh` now checks the example fixture, not only the template/runbook keywords.
- `agent-dev-kit/tests/fixtures/context/`
  - Added `memory-search-result-example.md` with `search_index -> timeline_context -> observation_details`.
  - Added `low-token-safety-exceptions.md` with four safety exception examples and `full_clarity_required: true`.
  - `check-context-experience-patterns.sh` now checks these fixture anchors.

## Validation After Fix

| Command | Result |
|---|---|
| `rtk bash agent-dev-kit/scripts/devkit.sh match --skill adk-token-context-governance --text '请低 token 汇报，但保留命令路径风险和验证证据'` | `match=true`, trigger `低 token` |
| `rtk bash agent-dev-kit/tests/test_skill_trigger_matrix.sh` | `[PASS] skill trigger matrix` |
| `rtk bash agent-dev-kit/tests/test_token_context_governance.sh` | `[PASS] token context governance` |
| `rtk bash agent-dev-kit/tests/test_capability_uplift.sh` | `[PASS] capability uplift` |
| `rtk bash agent-dev-kit/scripts/validate-assets.sh --strict` | `Validation passed. strict=1 quick=0` |
| `rtk bash scripts/check-adk-codify-governance.sh` | `[PASS] codify governance` |
| `rtk bash scripts/check-adk-knowledge-compile-model.sh` | `[PASS] knowledge compile model` |
| `rtk bash scripts/check-adk-context-experience-patterns.sh` | `[PASS] context experience patterns` |
| `rtk bash agent-dev-kit/scripts/check-codify-governance.sh` | `[PASS] codify governance`; includes Codify true/false fixture checks. |
| `rtk bash agent-dev-kit/scripts/check-knowledge-compile-model.sh` | `[PASS] knowledge compile model`; includes filled note fixture checks. |
| `rtk bash agent-dev-kit/scripts/check-context-experience-patterns.sh` | `[PASS] context experience patterns`; includes memory-search and low-token safety fixtures. |
| `rtk bash scripts/check-subrepo-state.sh` | `[PASS] subrepo state policy ready`; strict `agent-dev-kit` is clean after subrepo commit `6b234e4`. |
| `rtk bash scripts/evidence-bundle.sh . --format json --max-summary-chars 1000` | `status=pass`; `agent_dev_kit_head=6b234e4`, `subrepo_state` reports `unexpected_dirty=0`. |
| `rtk bash scripts/check-all.sh --quick` | 32/32 pass; `check-evidence-bundle.sh` and `check-subrepo-state.sh` are both closed after `adk.lock` and gitlink update. |

## Subagent Findings

| Agent | Scope | Status | Finding |
|---|---|---|---|
| A | Codify + AAR | DONE | Trigger chain exists, but audit depth is still structural. Needs filled Codify Decision fixtures and branch semantic checks. |
| B | Knowledge Compile + Memory Search | NEEDS_CONTEXT | Raw fallback rules exist, but no filled examples in scoped review. Needs example artifact and instance validation. |
| C | Low Token Profile | DONE | Safety exception rules exist, but gates are mostly keyword checks. Needs before/after examples for safety restore behavior. |

## Decision

This pilot supports moving from "contract exists" to "instance proves behavior":

1. Keep current runtime capabilities; do not revert.
2. Treat the low-token trigger fix as a valid small runtime repair.
3. Do not run a blind `~/.codex` apply from this report alone. There is no evidence of pending `~/codex` live-target copy/overwrite/delete work in this pilot.
4. The immediate next upgrade from this report has been completed: minimal filled fixtures and semantic checks now exist for Codify, Knowledge Compile, Memory Search, and Low Token safety exceptions.
5. The next step is commit/apply closeout, not more runtime contract work.

## Risk

Current risk is reduced from medium to low-medium for these four capabilities. The documented behavior is coherent, command entrypoints pass, and the gates now include minimal filled artifacts. Remaining risk is that fixtures are still small synthetic examples; future pilots should collect real task artifacts before claiming broad runtime maturity.
