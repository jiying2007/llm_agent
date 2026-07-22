# mattpocock/skills 参考子仓与 phase gate 治理复核（2026-07-22）

## Summary

- 目标：将 `mattpocock/skills` 从 `disabled/watch` 受控重新激活为 `llm_agent` 直接参考 submodule，并纳入长期 fetch/diff/report 治理。
- 非目标：不安装上游 skills，不启用 Claude plugin/hook/runtime，不修改 ADK 或 `~/.codex`，不替现有 dirty-baseline owner 续期。
- 结论：reference registration 本身通过；`allow_upstream_sync=yes` 保持不变，`next_review_by` 从已过期的 `2026-07-20` 更新为 `2026-08-22`；`last_live_refresh=2026-07-14` 保持不变。

## Baseline

- 父仓基线：`18b2ab37ae21ef586d3280f604b6033b861ffd2a`，隔离分支 `codex/mattpocock-reference-20260722`。
- `agent-dev-kit`：`9a8f735928976cf2efac81dd167911664bf6c490`，隔离验证 worktree clean。
- 原工作区既有 dirty：`OpenSpec`、`superpowers`、`vibeflow` 及 `.cache/`、`hermes/`、`hermes_data/`；本轮未回退、清理或提交这些内容。
- reference dirty baseline：三条 status fingerprint 未报告漂移，但 `expires_on=2026-07-20` 已过期；owner 仍为 `adk-maintainer`。
- phase 原状态：`phase=fallback-sunset`、`allow_upstream_sync=yes`、`last_live_refresh=2026-07-14`、`next_review_by=2026-07-20`。

## Evidence Index

| 命令/证据 | exit | 摘要 | 层级 |
|---|---:|---|---|
| `scripts/practice-intake.sh collect --provider github ... --allow-network` | 0 | v1 candidate `epc-43e82b2e69e37e419c3f`，metadata-only，review-required | intake |
| reviewed local source static inspection | 0 | HEAD `ed37663...`、MIT、167 entries、无 nested submodule、无凭证模式命中 | source/security |
| `tests/test_reference_repository_registration.sh` | 0 | 新登记、safe reactivation、alias、rollback、HTTPS origin 和 matrix table 投影通过 | registration |
| `scripts/check-reference-repository-registration.sh ... --plan ...json` | 0 | applied v1 plan、artifact hashes、local-submodule snapshot 通过 | registration |
| `scripts/check-authorized-subrepos.sh .` | 0 | `.gitmodules`、active registry 与 lifecycle allowlist 一致 | authorization |
| `scripts/check-subrepo-state.sh .` | 0 | 隔离环境 active subrepos `clean=8/8` | subrepo-state |
| `scripts/sync-subrepos.sh . status` | 0 | `mattpocock-skills enabled=yes/status=active/main/ed37663/dirty=0` | sync-routing |
| `scripts/check-practice-intake.sh .` | 0 | intake、registration、removal 和 legacy-free 门禁通过 | governance |
| `scripts/check-phase-gate.sh .` | 0 | phase gate 当前日期有效 | phase |
| `scripts/check-all.sh --quick` | 1 | 53 项中 52 项通过；唯一失败为三条既有 dirty baseline 过期 | aggregate |

## Decisions

1. `mattpocock-skills` registry 原位切换为 `P1/fetch/main/enabled=yes/active/adopt-first/A`，不新增 `skills` 别名，不产生重复行。
2. lifecycle 原位从 `watch` 切换为 `active-reference`，月度复核，`automation_eligible=false`，保留历史 evidence。
3. adoption matrix 使用 `adopt/done`；`llm_agent` 只在 evidence 严格匹配 applied reference onboarding plan 时作为合法 reference production target。
4. 保持 `allow_upstream_sync=yes`；本轮未做 live apply，因此禁止更新 `last_live_refresh`。
5. `next_review_by=2026-08-22`，与 active-reference 月度 review window 对齐。

## Residual Risk

- `OpenSpec`、`superpowers`、`vibeflow` 的 dirty baseline 已过期，必须由对应 owner 复核并生成新的 dirty-triage evidence；本轮不静默续期。
- 上游包含写 HOME、`rm -rf`、`npx`、plugin/hook 等可执行建议；submodule 仅作为不可信研究输入，禁止运行。
- 本轮没有执行 fetch-all、pull、上游 installer、ADK absorption 或 Codex source-to-live。
- quick aggregate 的唯一失败不影响 `mattpocock-skills` registration 真实性，但在 dirty baseline owner 复核前，根仓总门禁仍不能声明全绿。
