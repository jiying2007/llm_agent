# Reference Repository Lifecycle

## Boundary

本流程从已存在的 repository candidate + 独立 owner decision 开始，不负责发现、评分或 ADK 吸收。上游 intake 见 `docs/runbooks/external-practice-intake.md`。

## Entry Gate

- Candidate 使用 `external-practice-candidate/v1`，provider 为 GitHub/GitLab/Gitee/manual 且 `repository` metadata 非空。
- Decision 使用 `external-practice-decision/v1`，必须 `ADOPT` 且 `target=reference-repository`。
- Owner 不能是 collector、automation 或 `external-practice-curator`。
- analysis、duplicate review、security review 均为仓库内持久证据。
- phase gate、registry/path conflict、materialization 和 rollback gate 全部通过。

## Dry-run Registration

```bash
rtk scripts/onboard-reference-repository.sh . \
  --candidates reports/external-practice-candidates.jsonl \
  --decisions reports/external-practice-decisions.jsonl \
  --candidate-id <epc-id> \
  --analysis reports/<analysis>.md \
  --duplicate-check reports/<duplicate-review>.md \
  --security-review reports/<security-review>.md

rtk scripts/check-reference-repository-registration.sh . --plan reports/reference-repository-onboarding-<id>-<date>.json
```

默认 mode=`dry-run`。计划 schema 固定 `reference-repository-onboarding/v1`；旧评分状态和旧 plan schema 直接失败。

## Explicit Apply

`--apply` 是单独授权点，只登记 reference lifecycle，不修改 ADK 或 live runtime。`metadata-only` 只允许 dry-run；apply 必须显式选择 `local-submodule`，并同时满足：workspace clean、本地 source 为 clean Git worktree、HTTPS `origin` 与批准候选完全一致、HEAD 已写入 plan、全部 review artifact hash 未漂移、plan 输出位于仓库 `reports/`：

```bash
rtk scripts/onboard-reference-repository.sh . \
  <同上参数> \
  --apply \
  --materialization local-submodule \
  --submodule-source /path/to/reviewed/local-repository
```

Apply 可能修改 `.gitmodules`、registry、adoption matrix Markdown/JSONL 和 subrepo lifecycle；执行前必须审查 plan 与 rollback。metadata 与 applied plan 作为一个事务写入；任一步失败都会恢复旧 metadata 并移除本轮新增 submodule。它不会联网发现、clone 远端、执行第三方代码、写 agent-dev-kit 或 apply `~/.codex`。

## Removal

```bash
rtk scripts/plan-reference-repository-removal.sh . \
  --repo <registered-name> \
  --evidence-dependency-scan reports/<dependency-scan>.md \
  --rollback-plan reports/<rollback-plan>.md
rtk scripts/check-reference-repository-removal.sh .
rtk tests/test_reference_repository_removal.sh
```

Removal 当前只生成和校验 `reference-repository-removal/v1` dry-run，不自动删除。adoption decision、evidence dependency scan、dirty baseline review 和 rollback plan 必须存在于仓库并写入 SHA-256；`agent-dev-kit`、active-core、protected、active-reference、watch 或 evidence 依赖未清理的条目必须 fail closed。Fixtures 位于 `fixtures/reference-repository/removal/`；历史 `reports/subrepo-removal-plan-*` 仅可作为显式 provenance artifact，不再由新门禁自动扫描。

## Verification

```bash
rtk scripts/check-reference-repository-registration.sh .
rtk tests/test_reference_repository_registration.sh
rtk scripts/check-reference-repository-removal.sh .
rtk tests/test_reference_repository_removal.sh
rtk scripts/check-practice-intake.sh .
```
