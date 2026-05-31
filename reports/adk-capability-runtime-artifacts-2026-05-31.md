# ADK Capability Runtime Artifacts Pilot - 2026-05-31

## Goal

继续 `llm_agent / agent-dev-kit` 运行态能力真实 artifact pilot。

- `llm_agent` baseline: `e478cb4`
- `agent-dev-kit` baseline: `6b234e4`
- scope: Codify / Knowledge Compile / Progressive Memory Search / Low Token Profile
- non-goal: 不新增 fixture，不吸收新外部项目，不直接 apply 到 `~/.codex`
- decision question: 当前真实 artifact 证据是否足够支持推广到 `~/codex -> ~/.codex`

## Raw Sources

| Source | Role | Notes |
|---|---|---|
| `reports/adk-capability-runtime-pilot-2026-05-30.md` | primary raw source | 上一轮 runtime pilot 报告，明确指出仍缺真实任务 artifact。 |
| `git show --stat --oneline e478cb4` | root delivery source | 记录根仓提交 `chore(adk): 记录运行态能力试跑优化`，包含 `adk.lock`、gitlink 和 pilot report。 |
| `git -C agent-dev-kit show --stat --oneline 6b234e4` | ADK delivery source | 记录实例门禁提交 `test(capability): 增加运行态能力实例门禁`。 |
| `agent-dev-kit/templates/memory/knowledge-compile-note.md` | schema source | Knowledge Compile note 字段模板。 |
| `agent-dev-kit/templates/context/memory-search-result.md` | schema source | Progressive Memory Search 字段模板。 |
| `agent-dev-kit/templates/context/low-token-profile.md` | schema source | Low Token Profile 字段模板。 |
| `agent-dev-kit/templates/governance/codify-decision.md` | schema source | Codify Decision 字段模板。 |

## Artifact 1: Knowledge Compile Note

---
id: adk-runtime-artifact-pilot-2026-05-31
created_at: 2026-05-31
last_verified: 2026-05-31
next_review_by: 2026-06-07
status: candidate
risk: low-medium
---

# Knowledge Compile Note

## raw_source_path

- `reports/adk-capability-runtime-pilot-2026-05-30.md`
- `git show --stat --oneline e478cb4`
- `git -C agent-dev-kit show --stat --oneline 6b234e4`
- command outputs listed in `Evidence Index`

## wiki_page_path

- `reports/adk-capability-runtime-artifacts-2026-05-31.md`

## schema_path

- `agent-dev-kit/templates/memory/knowledge-compile-note.md`
- `agent-dev-kit/templates/context/memory-search-result.md`
- `agent-dev-kit/templates/context/low-token-profile.md`
- `agent-dev-kit/templates/governance/codify-decision.md`

## source_url_or_local_path

- local workspace: `/home/leiwenjun/bin/llm_agent`

## summary

上一轮提交已经把四项运行态能力从纯契约推进到最小实例门禁：Codify true/false 分支、Knowledge Compile filled note、Progressive Memory Search 三层披露、Low Token 安全例外示例都已有检查脚本覆盖。本轮真实 pilot 不再增加合成 fixture，而是用上轮报告、真实提交和本轮命令输出生成一条可审查 artifact。

结论是：这些能力已经适合作为 `agent-dev-kit` 内部运行态能力继续保留；但只凭一次真实小任务 artifact，还不足以推广到 `~/codex -> ~/.codex` live 链路。当前更合适的决策是 `promotion_candidate=false`，继续收集至少一次不同任务类型的真实 artifact 后再评估 live apply。

## cross_references

- `reports/adk-capability-uplift-implementation-2026-05-29.md`
- `reports/adk-capability-runtime-pilot-2026-05-30.md`
- `agent-dev-kit/tests/fixtures/knowledge-compile/example-note.md`
- `agent-dev-kit/tests/fixtures/context/memory-search-result-example.md`
- `agent-dev-kit/tests/fixtures/context/low-token-safety-exceptions.md`
- `agent-dev-kit/tests/fixtures/codify-decision/promotion_candidate_true.md`
- `agent-dev-kit/tests/fixtures/codify-decision/promotion_candidate_false.md`

## stale_claims

- claim: `check-all --quick` previously passed 32/32.
  status: rechecked-2026-05-31
  review_by: Codex
  raw_fallback: rerun `rtk bash scripts/check-all.sh --quick` before commit or live promotion decision
- claim: source-to-live apply is safe.
  status: not-supported
  review_by: live promotion owner
  raw_fallback: run `~/codex` build/doctor/plan/apply dry-run only after promotion evidence supports it

## raw_fallback

- condition: promotion, rollback, or contested delivery decision
  path_or_url: `reports/adk-capability-runtime-pilot-2026-05-30.md`
  required_for: recover exact prior decision and risk wording
- condition: command result disputed
  path_or_url: rerun the command in `Evidence Index`
  required_for: reproduce runtime status

## change_log

| Date | Change | Source | Reviewer |
|---|---|---|---|
| 2026-05-31 | Created real runtime artifact pilot note from committed reports and command evidence. | local workspace | Codex |

## Artifact 2: Progressive Memory Search Result

- query: 最近能力落地决策是什么，是否已经可以推广到 live Codex 资产链路
- result_ids: runtime-pilot-2026-05-30, runtime-artifacts-2026-05-31, root-e478cb4, adk-6b234e4
- time_window: 2026-05-29..2026-05-31
- project_scope: `llm_agent / agent-dev-kit`
- observation_type: runtime-pilot-report, git-delivery, verification-command
- redaction_status: none
- detail_fetch_reason: live promotion decision requires exact prior decision, commit scope and verification evidence
- raw_fallback: `reports/adk-capability-runtime-pilot-2026-05-30.md`

## Layer

- search_layer: observation_details
- timeline_context: `2026-05-29` capability uplift introduced four runtime capabilities; `2026-05-30` runtime pilot fixed trigger and instance-gate gaps; `2026-05-31` artifact pilot generated a real task evidence bundle and deferred live promotion.
- selected_observation_ids: runtime-pilot-2026-05-30, root-e478cb4, adk-6b234e4
- owner_approval_for_persistent_memory: not-requested

## Progressive Disclosure Trace

| Layer | Returned | Why enough / why expanded |
|---|---|---|
| `search_index` | Candidate: `reports/adk-capability-runtime-pilot-2026-05-30.md`; commits `e478cb4`, `6b234e4`. | Enough to find likely decision source, not enough for promotion judgment. |
| `timeline_context` | Capability uplift -> runtime pilot -> artifact pilot. | Enough to see sequence, not enough to decide live apply. |
| `observation_details` | Prior report says do not blind apply and future pilots should collect real task artifacts; current evidence bundle passes but remains one-task evidence. | Required because promotion is a high-impact state change. |

## Artifact 3: Codify Decision

delivery_goal: decide whether the 2026-05-30/31 ADK runtime capability work should be promoted to `~/codex -> ~/.codex` live chain.

reusable_pattern:
  summary: Real artifact pilot before live promotion is a useful guardrail for ADK runtime capability changes.
  reusable_when: A capability already passes structural gates but still lacks evidence from a real task artifact.
  not_reusable_when: The change is purely local documentation, a low-risk typo, or already has multiple independent live task artifacts.

affected_asset:
  type: report / decision evidence
  path: `reports/adk-capability-runtime-artifacts-2026-05-31.md`
  owner: adk-team

promotion_candidate: false

do_not_promote_reason: This pilot produced one real task artifact and confirmed runtime checks pass, but it did not yet show repeated behavior across multiple real task types. Live apply would change `~/.codex` behavior, so the evidence threshold should remain higher than one narrow pilot.

owner_review:
  required: true
  reviewer: adk-team
  status: pending
  reviewed_at:

rollback_path:
  asset: `~/codex -> ~/.codex` live assets
  steps:
    - Do not run live apply from this report.
    - If a later promotion applies these assets and behavior regresses, restore from `~/codex` apply backup or previous declarative asset revision.
    - Re-run `rtk bash ~/codex/scripts/doctor.sh --scope all` and `rtk bash scripts/evidence-bundle.sh . --format json --max-summary-chars 1200`.
  verification_after_rollback: global Codex health and evidence bundle both pass.

verification_evidence:
  commands:
    - command: `rtk bash agent-dev-kit/scripts/devkit.sh codify-governance`
      exit_code: 0
      result_summary: `[PASS] codify governance`
      evidence_path: this report / command transcript
    - command: `rtk bash agent-dev-kit/scripts/devkit.sh knowledge-compile`
      exit_code: 0
      result_summary: `[PASS] knowledge compile model`
      evidence_path: this report / command transcript
    - command: `rtk bash agent-dev-kit/scripts/devkit.sh context-experience`
      exit_code: 0
      result_summary: `[PASS] context experience patterns`
      evidence_path: this report / command transcript
    - command: `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json`
      exit_code: 0
      result_summary: `status=pass`, `failures=0`, `context_governance_assets=8`
      evidence_path: this report / command transcript
    - command: `rtk bash scripts/evidence-bundle.sh . --format json --max-summary-chars 1200`
      exit_code: 0
      result_summary: `status=pass`, `root_head=e478cb4`, `agent_dev_kit_head=6b234e4`
      evidence_path: this report / command transcript
  artifacts:
    - `reports/adk-capability-runtime-artifacts-2026-05-31.md`
  negative_or_disproved_path: Prior report explicitly says not to blind apply to `~/.codex`; this report preserves that constraint because evidence is still one narrow real task artifact.

decision:
  status: observe
  next_action: collect one more real artifact from a different small task before live promotion.
  next_review_by: 2026-06-07

## Artifact 4: Low Token Profile Record

## Compressed Status Example

- trigger: user asked to continue from a CTX_PRESSURE/HOT handoff with a narrow goal
- active_scope: status_update_only
- technical_terms_preserved: `llm_agent`, `agent-dev-kit`, `Codify`, `Knowledge Compile`, `Progressive Memory Search`, `Low Token Profile`, `~/codex -> ~/.codex`, `promotion_candidate`
- safety_exception: none
- restore_condition: approval, irreversible apply, security warning, review finding precision, or ambiguous multi-step instruction
- user_override: not requested

Compressed status:

> Baseline matches: root `e478cb4`, ADK `6b234e4`. Runtime checks pass. I am writing one real artifact report and will not run live apply unless the report supports promotion.

## Full Clarity Restore Examples

| Scenario | safety_exception | full_clarity_required | Restored detail |
|---|---|---|---|
| live apply decision | irreversible action confirmation | true | Must state exact commands, affected paths, dry-run requirement, rollback path and approval boundary before `rtk bash ~/codex/scripts/apply.sh --plan ...`. |
| promotion decision | multi-step ambiguity | true | Must distinguish `agent-dev-kit` internal keep/observe from `~/codex -> ~/.codex` live promotion. |
| security / credentials | security warning | true | Must state secret boundary and avoid broad external writes. No such issue found in this pilot. |
| review finding | review finding precision | true | Must cite file and line if a bug is claimed. This report makes no code-review bug finding. |

## Evidence Index

| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk git rev-parse --short HEAD` | 0 | `e478cb4` | command transcript | Repository | Raw Sources |
| `rtk git -C agent-dev-kit rev-parse --short HEAD` | 0 | `6b234e4` | command transcript | Repository | Raw Sources |
| `rtk git -C agent-dev-kit status --short` | 0 | clean output | command transcript | Repository | Raw Sources |
| `rtk git show --stat --oneline --decorate e478cb4` | 0 | root commit updates `adk.lock`, gitlink and runtime pilot report | command transcript | Repository | Raw Sources |
| `rtk git -C agent-dev-kit show --stat --oneline --decorate 6b234e4` | 0 | ADK commit adds runtime instance gates and fixtures | command transcript | Repository | Raw Sources |
| `rtk bash agent-dev-kit/scripts/devkit.sh codify-governance` | 0 | `[PASS] codify governance` | command transcript | Workflow | Codify Decision |
| `rtk bash agent-dev-kit/scripts/devkit.sh knowledge-compile` | 0 | `[PASS] knowledge compile model` | command transcript | Workflow | Knowledge Compile Note |
| `rtk bash agent-dev-kit/scripts/devkit.sh context-experience` | 0 | `[PASS] context experience patterns` | command transcript | Workflow | Progressive Memory Search / Low Token Profile |
| `rtk bash agent-dev-kit/scripts/check-token-budget.sh --summary-json` | 0 | `status=pass`, `failures=0`, `context_governance_assets=8` | command transcript | Workflow | Low Token Profile |
| `rtk bash scripts/evidence-bundle.sh . --format json --max-summary-chars 1200` | 0 | `status=pass`, live health and pilot readiness checks pass | command transcript | Project | Completion Gate |
| `rtk bash scripts/check-all.sh --quick` | 0 | 32/32 PASS | command transcript | Project | Completion Gate |
| `rtk rg -n "Do not run a blind\|fixtures are still small synthetic\|future pilots should collect real task artifacts" reports/adk-capability-runtime-pilot-2026-05-30.md` | 0 | negative promotion evidence found in prior report | command transcript | Governance | Codify Decision |

## Promotion Decision

| Target | Decision | Reason |
|---|---|---|
| Keep ADK runtime capability work in `agent-dev-kit` | yes | Runtime commands and evidence bundle pass; no regression found in this scoped pilot. |
| Promote now to `~/codex -> ~/.codex` | no | Evidence is now a real task artifact, but still only one narrow task. Prior risk was explicitly "fixtures are still small synthetic examples"; this report reduces that risk but does not prove broad live behavior. |
| Run `~/codex` source-to-live apply now | no | The report does not support irreversible live promotion. Dry-run can be considered only after owner review or one additional real artifact from a different task type. |

## Next Gate

Before live promotion, collect one more small real artifact from a different category, for example a code-review closeout or branch-closeout artifact. If that also supports the behavior, then run:

```bash
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
```

Only if dry-run shows reasonable copy/overwrite and owner review accepts the evidence should real apply be considered.
