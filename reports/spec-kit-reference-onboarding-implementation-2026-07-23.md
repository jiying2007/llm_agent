# github/spec-kit 长期跟踪落地记录

## 状态

- 决策：`ADOPT / target=reference-repository`
- 目标定位：`P1 / observe-first / active-reference`
- 当前状态：`approved / dry-run-passed / apply-blocked`
- 正式登记：未完成
- 阻塞门禁：`apply_workspace_gate`
- 阻塞原因：根工作区进入本任务前及当前存在用户/既有未提交变更；禁止通过 stash、清理、回退或混合提交绕过。

## Source 与版权边界

- source：`https://github.com/github/spec-kit`
- retrieved_at：`2026-07-23`
- stable tag：`v0.13.4`
- reviewed commit：`ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`
- reviewed tree：`b27f6e7260f477ee70d7ad1854a63b04689e98b4`
- license：MIT
- candidate：`epc-2ab9c988520526e1e0e0`
- 只保存 metadata、分析、决策和本地治理计划；未复制上游正文、模板、catalog 内容或二进制。
- 未安装/执行 `specify-cli`、workflow、extension、preset、bundle、hook 或 Git automation。

## 已落地产物

1. `reports/external-practice-candidates-spec-kit-2026-07-23.jsonl`
2. `reports/external-practice-evidence-spec-kit-2026-07-23.json`
3. `reports/external-practice-decisions-spec-kit-2026-07-23.jsonl`
4. `reports/reference-analysis-spec-kit-2026-07-23.md`
5. `reports/reference-duplicate-review-spec-kit-2026-07-23.md`
6. `reports/reference-security-review-spec-kit-2026-07-23.md`
7. `reports/reference-repository-onboarding-spec-kit-2026-07-23.json`
8. `reports/reference-repository-onboarding-spec-kit-2026-07-23.md`

## Dry-run 结果

onboarding dry-run 的 13 项 gate 全部通过：

- candidate contract
- owner decision
- repository metadata
- source risk
- analysis report
- duplicate check
- security review
- phase gate
- registry conflict
- target path
- local-submodule materialization
- dry-run workspace
- rollback plan

计划固定：

- registry repo：`spec-kit`
- group：`workflow-core`
- priority：`P1`
- sync mode：`fetch`
- branch：`main`
- enabled/status：`yes / active`
- intake policy：`observe-first`
- grade：`A`
- materialization：`local-submodule`
- source HEAD：`ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`

`check-reference-repository-registration.sh` 对本计划及 fixtures 检查通过，`checked=3`。

## 正式 Apply 负结果

| Command | Exit Code | Result |
|---|---:|---|
| `rtk scripts/onboard-reference-repository.sh . ... --materialization local-submodule` | 0 | dry-run 计划生成 |
| `rtk scripts/check-reference-repository-registration.sh . --plan reports/reference-repository-onboarding-spec-kit-2026-07-23.json` | 0 | registration plan/fixtures 通过 |
| 同一 onboarding 命令增加 `--apply` | 2 | `[FAIL] reference onboarding gates failed: apply_workspace_gate` |

apply 在事务写入前失败；没有创建 `spec-kit/` gitlink，没有修改 `.gitmodules`、`subrepos/registry.csv`、adoption matrix 或 lifecycle。

## 恢复条件

1. 用户自行收口当前根仓和既有 dirty subrepo 状态，使 `rtk git status --short` 为空。
2. 重新创建只读 `v0.13.4` source snapshot，并核验：
   - origin 精确等于 `https://github.com/github/spec-kit`
   - HEAD 精确等于 `ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`
   - source clean
3. 复核 candidate 未超过 `expires_at=2026-10-21`；过期则重新 intake 和 owner decision。
4. 确认五个 evidence artifact 的 SHA-256 与 dry-run plan 一致。
5. 重新执行带 `--apply --materialization local-submodule` 的 onboarding 命令。
6. apply 后运行 registration、practice intake、adoption matrix、subrepo state 和 quick aggregate 检查。

## 长期跟踪边界

- `active-reference` 只允许 fetch/diff/analyze。
- 每周检查 release/tag/security metadata，每月语义 diff，每 90 天复核。
- 只跟踪 integration 生命周期、managed-file/rollback、catalog/preset/extension/bundle 治理、workflow fail-closed、brownfield/spec 演化和 Codex target 变化。
- 不自动吸收，不执行 upstream code，不提供本机 token，不修改 `agent-dev-kit` 或 `~/.codex`。

## Gate Result

`needs-fix`：治理决策与可复现 dry-run 已落地；正式长期跟踪登记仍需干净工作区，不能声明 `spec-kit active-reference registered`。
