# Source-to-live 隔离预演与远端交付证据

- 日期：2026-07-24
- 归档状态：Knowledge Hub candidate（未自动写入 Hub）
- 范围：
  - 在临时 worktree 中把 `agent-dev-kit` 的 `adk-production-field-readiness` 映射为 Codex vendor Skill。
  - 基于原 `~/codex` 当前 dirty 快照执行 build、doctor、plan 和 apply dry-run。
  - 先推送 `agent-dev-kit` 的 15 个 ahead commits，再推送 `llm_agent` 的 3 个 ahead commits。
- 明确非目标：
  - 不执行对 `~/.codex` 的实际 apply。
  - 不修改、提交或清理原 `~/codex` 的既有 dirty。
  - 不执行 merge、rebase、force push、tag、Release 或 PR。

## 结论

1. 隔离 source-to-live 预演在授权边界内通过：
   - build、`doctor --scope all`、Skill 门禁、Python 单测和 5 个 profile smoke 均通过。
   - 最终计划为 `copy=5`、`keep=439`、`overwrite=1`、`delete=8`、`mkdir=270`、`skip=0`。
   - `apply.sh --dry-run` 返回 0；`~/.codex` 未写入，新 Field Skill 仍不存在于 live。
2. 当时的 `check.sh` 最终返回 1，唯一原因是禁止实际 apply 后的预期 source/live 差异：
   - `control/state/managed-files.json` 1 个 diff。
   - `adk-production-field-readiness/1.0.0` 5 个新文件在 live 缺失。
   - 在此之前的 build、doctor、governance、106 个 Python tests 和全部 profile smoke 均通过。
   - 后续已为 `check.sh` 增加显式 `--pre-apply` 模式；它在不放宽默认 post-apply 门禁的前提下，为此类预演提供零退出验证路径。修复证据见 `reports/codex-check-pre-apply-remediation-2026-07-24.md`。
3. 两仓远端交付完成：
   - `agent-dev-kit`：`origin/main` 从 `0d25f3da7ac1f141a5172d62cfc7b6f4bfbd93b1` 快进到 `54a4d7fcc1c41de59cec7a9d72a99f4cd3cc9e78`。
   - `llm_agent`：`origin/main` 从 `18b2ab37ae21ef586d3280f604b6033b861ffd2a` 快进到 `8a4a3ee696289abb9a805f66ba24995442700132`。

## 隔离与冲突处理

- 临时 worktree：`/tmp/codex-adk-source-to-live.ZlzOly/worktree`。
- 首次从 clean HEAD 预演时，`doctor --scope all` 发现 live 中有 4 个 unmanaged Skill；核验后确认这些 Skill 来自原 `~/codex` 的既有 40 项 dirty，而非本次导入。
- 对原 dirty 与本次 Field Skill 路径做无重叠核验后，仅在临时 worktree 覆盖原 dirty 快照，再继续预演。
- 原 `~/codex` 未出现 `adk-production-field-readiness`；原 dirty 清单保持不变。
- `~/.codex` 未出现 `adk-production-field-readiness`，证明 dry-run 没有越界写 live。

## 最终 apply 计划

完整机器可读计划：

- `reports/codex-apply-plan-preview-2026-07-24.json`

非 keep/mkdir 动作：

- overwrite：`control/state/managed-files.json`
- copy：
  - `vendor/skills/adk-production-field-readiness/1.0.0/LICENSE`
  - `vendor/skills/adk-production-field-readiness/1.0.0/README.md`
  - `vendor/skills/adk-production-field-readiness/1.0.0/SKILL.md`
  - `vendor/skills/adk-production-field-readiness/1.0.0/agents/openai.yaml`
  - `vendor/skills/adk-production-field-readiness/1.0.0/references/pilot-measurement-evidence.md`
- delete：
  - `vendor/skills/multi-search-engine/0.1.0/agents`
  - `vendor/skills/embedded-log-triage/0.1.0/agents`
  - `vendor/skills/embedded-core-dump-triage/0.1.0/agents`
  - `vendor/skills/chronicle-workflow-miner/1.0.0/agents`
  - `vendor/skills/multi-search-engine/0.1.0`
  - `vendor/skills/embedded-log-triage/0.1.0`
  - `vendor/skills/embedded-core-dump-triage/0.1.0`
  - `vendor/skills/chronicle-workflow-miner/1.0.0`

## Evidence Index

| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `scripts/doctor.sh --scope all`（clean HEAD 临时 worktree） | 1 | 发现 4 个来自原 Codex dirty 的 live unmanaged Skill，阻止直接继续 | 本报告“隔离与冲突处理” | Workflow | negative-path |
| `git diff --binary HEAD \| git apply --check -`（原 Codex dirty 到临时 worktree） | 0 | dirty 快照可无冲突覆盖；本次 Field Skill 路径无重叠 | 本报告“隔离与冲突处理” | Workflow | isolation-overlay |
| `scripts/build.sh` | 0 | token-lean build 完成，managed=713 | 本报告“结论” | Workflow | Codex build |
| `scripts/doctor.sh --scope all`（dirty 快照覆盖后） | 0 | repo/build/live 均为 0 errors、0 warnings | 本报告“结论” | Workflow | Codex doctor |
| `scripts/check-skills.sh` | 0 | skills=64，0 errors、0 warnings | 本报告“结论” | Skill | Skill manifest |
| `scripts/check.sh` | 1 | 核心门禁和全部 smoke 通过；仅预期 live diff/missing 导致非零 | 本报告“结论” | Workflow | no-live-apply boundary |
| `scripts/plan.sh --target ~/.codex --prune-stale` | 0 | copy=5、keep=439、overwrite=1、delete=8、mkdir=270 | `reports/codex-apply-plan-preview-2026-07-24.json` | Workflow | apply plan |
| `scripts/apply.sh --plan ... --dry-run` | 0 | dry_run=1，未写入 live | `reports/codex-apply-plan-preview-2026-07-24.json` | Workflow | dry-run |
| `git ls-remote origin refs/heads/main`（ADK，push 前） | 0 | 远端等于本地 tracking SHA `0d25f3d...` | 本报告“结论” | Repository | fast-forward preflight |
| `git push origin main:main`（ADK） | 0 | 非 force 快进 push 完成 | 本报告“结论” | Repository | 15 commits |
| `git ls-remote origin refs/heads/main`（ADK，push 后） | 0 | 远端精确等于 `54a4d7f...` | 本报告“结论” | Repository | remote verification |
| `git ls-remote origin refs/heads/main`（根仓，push 前） | 0 | 远端等于本地 tracking SHA `18b2ab3...` | 本报告“结论” | Repository | fast-forward preflight |
| `git push origin main:main`（根仓） | 0 | 非 force 快进 push 完成 | 本报告“结论” | Repository | 3 commits |
| `git ls-remote origin refs/heads/main`（根仓，push 后） | 0 | 远端精确等于 `8a4a3ee...` | 本报告“结论” | Repository | remote verification |
| `/home/leiwenjun/codex/scripts/final-ready.sh` | 0 | final-ready pass；session coach 风险来自原 Codex 长线程、ahead=1 和 40 项既有 dirty | 本报告“风险与后续边界” | Workflow | final gate |

## 风险与后续边界

- 当前 live 仍是旧基线；根仓全面检查中的 current-status 单项不会因本次 dry-run 自动转绿。
- `check.sh --pre-apply` 通过不改变上述 live 事实，只修复预演阶段的完成度表达。
- 8 个 prune 动作已审查但尚未执行；未来若授权实际 apply，应重新基于当时 live 生成计划并再次人工核对。
- 本次只完成 source-to-live 的隔离预演和远端源码交付，不构成 live 发布、M5 现实 pilot 证明或 Release 放行。
- 本报告作为可归档 candidate 保留；未经额外授权，不自动写入 Knowledge Hub。
- 回退：
  - live 无变更，无需 live 回退。
  - 远端已快进，不自动回退；如需撤销，应另行授权并采用可审查的 revert 提交，禁止改写历史。
