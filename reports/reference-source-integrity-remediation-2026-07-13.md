# Reference Source Integrity Remediation

- date: 2026-07-13
- owner: adk-team
- status: verified
- scope: `llm_agent` reference intake and `agent-dev-kit` source-governance documentation
- breaking_change: no

## Goal

保证参考仓分析只读取可复现的 commit 对象，区分权限、内容、文件类型、untracked 和 staged 漂移，并阻止分析或验证流程继续污染来源仓和根仓工作树。

## Non-Goals

- 不清理、reset、覆盖或提交 `OpenSpec`、`superpowers`、`vibeflow` 的既有本地改动。
- 不同步参考仓上游。
- 不执行 `~/codex -> ~/.codex` live apply。
- 不把模拟设备 pilot 声明为真实硬件 production-ready。

## Before-Fix Evidence

| Finding | Evidence |
|---|---|
| 根仓 quick gate 未放行 | `54/56`, `check-subrepo-state` 与聚合 `check-evidence-bundle` 失败 |
| 参考工作树混合漂移 | OpenSpec 655、superpowers 115、vibeflow 216 个 dirty 条目 |
| 来源真实性不可判定 | baseline 只有 fingerprint/count，没有 mode/content/type 分类 |
| 分析读取并写回 dirty 来源仓 | `scripts/analyze-repo.sh` 遍历工作树并写 `<repo>/analysis/` |
| 验证产生副作用 | OSS cycle 测试把 queue/evidence 默认写入根仓 `reports/` |
| 动态统计漂移 | ADK `AGENTS.md` 和架构报告硬编码数量与 manifest/文件系统不一致 |
| quick 反馈过慢 | 优化前约 148 秒；token budget 55 秒、WeChat ledger 48 秒 |

## Implemented Controls

1. `classify-repo-worktree.sh` 统一输出 mode/content/type/untracked/staged、HEAD、dirty count 和 fingerprint。
2. dirty baseline 增加 `expected_classification` 与 `analysis_policy=commit-snapshot-only`。
3. triage schema v2 校验 fingerprint、分类、策略、计数、owner 和 expires_on。
4. `analyze-repo.sh` 使用 `git archive <commit>` 临时快照，输出到 `reports/repo-analysis/<repo>/<commit>/`。
5. pipeline 不再扫描或写入 `<repo>/analysis/`。
6. `sync-subrepos.sh pull` 在网络操作前拒绝 dirty 工作树。
7. health JSON 输出实时 governance status 和动态资产清单；active 文档不再硬编码当前数量。
8. current-status 明确为 last-verified committed baseline，并校验 7 天 freshness 和实时 subrepo state。
9. OSS continuous-operation 测试的 cycle/queue/evidence 全部写入临时目录，workspace entrypoint 比较执行前后完整 Git porcelain 状态。
10. quick gate 跳过重复 release gate并记录逐项耗时；完整覆盖保留在 full/独立 release gate。

## Verified State

| Area | Result |
|---|---|
| ADK strict validation | PASS |
| ADK full regression | PASS, 47/47 |
| Reference source integrity regression | PASS |
| Root test suite | PASS |
| Root quick gate | PASS, 54/54,约 31 秒 |
| Token budget | PASS, `scripts/README.md` 518/520 行 |
| Subrepo state | PASS, clean=4, known_dirty=3, unexpected_dirty=0, classification_mismatch=0 |
| Dirty triage schema v2 | PASS, `reports/reference-dirty-triage-2026-07-13.json` |
| ADK harden readiness with pilot | PASS |
| Workspace entrypoints and side-effect assertion | PASS |
| Runtime live footprint | PASS, 14/14, missing_required=0 |

## Delivery

- `agent-dev-kit`: `b29a2ce docs(governance): 强化参考源分析边界`, pushed to `origin/main`.
- `llm_agent`: root implementation verified; commit and push are the final delivery step.
- Runtime apply decision: not required because the ADK commit changes documentation only and has no exported/live asset mapping.

## Residual Boundaries

- 三个参考仓的既有本地改动仍保留，但只能通过 commit snapshot 参与分析；下一次 baseline 复核不晚于 2026-07-20。
- 内容或 symlink 类型改动仍需 owner 单独决定是否保留或清理，本次不替用户做破坏性处理。
- 真实嵌入式生产放行仍需烧录/readback、boot log、HIL、OTA rollback 和现场包证据。

## Gate Result

`pass` for source and repository delivery; real-device production readiness remains out of scope.
