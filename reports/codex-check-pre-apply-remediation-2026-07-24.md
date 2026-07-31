# Codex `check.sh` pre-apply 语义修复记录

- 日期：2026-07-24
- 状态：committed / pushed / applied / verified
- 归档状态：Knowledge Hub candidate（未自动写入 Hub）
- 目标：在禁止实际写入 `~/.codex` 的 source-to-live 预演中，让 source/build/tests/smoke/plan/dry-run 获得真实零退出门禁，同时保留默认发布后 live 一致性检查的 fail-closed 语义。

## 根因

原 `scripts/check.sh` 没有参数解析，并且无条件执行：

1. `doctor.sh --scope all`
2. `diff.sh --target ~/.codex`
3. `drift.sh --target ~/.codex`

因此，source 已更新但 live 明确禁止 apply 时，预期的 build/live 差异必然让整条命令返回 1。`check.sh --help` 也会忽略参数并启动完整检查，进一步证明脚本没有阶段或 CLI 契约。

## Hypothesis Matrix

| # | 假设 | 验证 | 结果 |
|---|---|---|---|
| 1 | 构建、测试或治理存在真实失败 | 审查前次日志和本次完整回归 | 证伪；相关门禁均通过 |
| 2 | `check.sh` 已有 source-only/pre-apply 模式，只是调用错误 | 阅读脚本和执行 `--help` | 证伪；参数被忽略 |
| 3 | 单一发布后语义错误覆盖了预演阶段 | 空 target 正反实验 | 证实 |

## Repair Note

- failed_scope：禁止 live apply 时，默认 `check.sh` 因预期 live diff 返回 1。
- passing_scope_to_preserve：build、repo/build/governance doctor、MCP gate、全部 Python tests、Skill gate、bwrap gate、plan、apply dry-run、5 profile smoke，以及默认 post-apply 的 live diff/drift。
- minimal_rerun：CLI 定向测试、空 target pre-apply 正例、同一 target post-apply 负例、真实 `~/codex` 默认完整检查。
- rollback_anchor：`~/codex` 当前 HEAD `684f7f8`；本次只新增或修改 3 个此前无本地 dirty 的路径。
- root_cause_status：known。
- repair_action：
  - 新增 `--pre-apply`。
  - 新增 `--target PATH`。
  - 新增 `--help` 和未知参数 fail-closed。
  - pre-apply 跳过 live doctor/diff/drift，但保留 plan 和 apply dry-run。
  - 默认 post-apply 行为继续核对 live doctor/diff/drift。
- semantic_verification：空 target 下 pre-apply 返回 0，默认模式返回 1；真实 live 同步状态下默认完整检查返回 0。
- do_not_repeat：不再用默认 post-apply 模式评价“尚未获准 apply”的预演完成度。

## 改动

- `/home/leiwenjun/codex/scripts/check.sh`
- `/home/leiwenjun/codex/tests/test_check_script.py`
- `/home/leiwenjun/codex/docs/codex-operating-model.md`

没有修改 `~/.codex`，没有覆盖或清理原 `~/codex` 的既有 dirty，也没有 commit、push、merge 或 rebase。

上述句子记录的是修复实现与首次验证阶段的边界。用户后续明确授权后，已完成下述交付；既有 dirty 仍未进入提交。

## 提交、远端与 source-to-live 交付

- 新提交：`43c6c83ce38cdc43bd24324a40a1487e4f9df66e fix(check): 区分应用前后验证门禁`
- 同批推送的既存 ahead commit：`684f7f8b39d6b0e9ccf46440c01cdd6dbe841482 feat(skills): 硬切OpenAI调用元数据合同`
- 远端：`origin/main=43c6c83ce38cdc43bd24324a40a1487e4f9df66e`
- push：非 force `main:main`，未推 tag。
- apply plan：`/home/leiwenjun/codex/build/apply-plan.json`
- 审计副本：`reports/codex-check-fix-apply-plan-2026-07-24.json`
- plan SHA256：`50bb3200e3a37891e3d6f771b49bcee7c3bfd87d44808e5c8d43533fb9ab55d8`
- plan summary：`copy=0 keep=440 overwrite=0 delete=0 mkdir=274 skip=0`
- dry-run：退出码 0。
- actual apply：退出码 0，`dry_run=0`。
- live 结果：没有文件复制、覆盖或删除；build/live `same=439 diff=0 missing=0`，managed drift 全零。

## Evidence Index

| Command | Exit Code | Result Summary | Layer |
|---|---:|---|---|
| `rtk bash scripts/check.sh --help`（修复前） | 0，但错误启动完整检查 | 参数被忽略，证明无 CLI 契约 | Negative |
| `rtk shellcheck scripts/check.sh` | 0 | Shell 静态检查通过 | Source |
| `rtk python3 -m unittest tests.test_check_script` | 0 | 3/3：help 无副作用、未知参数和缺 target 值 fail closed | Test |
| `rtk bash scripts/check.sh --pre-apply --target <empty-target>` | 0 | 88 tests、5 profile smoke、432-copy dry-run 完成；live assertion 显式 skipped | Workflow |
| `rtk bash scripts/check.sh --target <same-empty-target>` | 1（预期） | 默认模式在 `missing=431` 的 build/live diff 处失败 | Negative |
| `rtk bash scripts/check.sh`（真实 `~/codex`） | 0 | 109 tests、5 profile smoke、`same=439 diff=0 missing=0`、drift 全零 | Workflow |
| `rtk bash /home/leiwenjun/codex/scripts/check.sh --help`（cwd=`/tmp`） | 0 | 非仓库 cwd 可用，未触发 build | CLI |
| `rtk git commit -m "fix(check): 区分应用前后验证门禁"` | 0 | 仅提交 3 个本次路径，104 insertions、5 deletions | Repository |
| `rtk git push origin main:main` | 0 | 两个 ahead commits 非 force 快进到 origin/main | Repository |
| `rtk bash scripts/apply.sh --plan build/apply-plan.json --dry-run` | 0 | 同一计划 dry-run；无 copy/overwrite/delete | Runtime |
| `rtk bash scripts/apply.sh --plan build/apply-plan.json` | 0 | 实际 apply 完成，计划为内容级 no-op | Runtime |
| `rtk bash scripts/check-routing-precedence.sh` | 0 | token-lean 默认路由保持 ADK-first，Superpowers 未误激活 | Workflow |
| `rtk bash scripts/check.sh`（apply 后） | 0 | 109 tests、5 profile smoke、live diff/drift 全绿 | Workflow |
| `rtk bash /home/leiwenjun/codex/scripts/final-ready.sh` | 0 | final-ready pass；剩余提示仅对应长线程和 40 项既有 dirty | Workflow |

## 使用契约

尚未授权 apply：

```bash
rtk bash scripts/check.sh --pre-apply
```

已完成 apply，需要发布后终态核验：

```bash
rtk bash scripts/check.sh
```

`--pre-apply` 通过只证明 source/build/governance/tests/smoke/plan/dry-run 闭环，不证明 live 已发布，不替代默认 post-apply 门禁。
