# llm_agent / agent-dev-kit 吸收优化复审（2026-06-15）

## Scope

本次复审处理 `llm_agent` 到 `agent-dev-kit` 的吸收治理闭环，不新增外部来源，不执行上游同步，不安装或启用任何外部运行时资产。

## Source Inventory

| Source | Read Status | Decision |
|---|---|---|
| `subrepos/adoption-matrix.md` / `.jsonl` | local read | 修正过期证据路径，不新增候选 |
| `agent-dev-kit` current worktree | local read | 作为落地目标压实，不作为来源吸收 |
| `subrepos/phase-gate.env` | local read | 复审窗口到期后顺延到 2026-06-29 |

## Decisions

| Item | Decision | Reason |
|---|---|---|
| 外部来源新增吸收 | reject | 当前无明确新来源；矩阵无 pending/blocked，不做增量堆叠 |
| `adk-planner` 证据路径 | adapt | 现有 agent 已标准化为 `architecture-planner` |
| AAR `memory candidate` 触发词 | adapt | 裸触发词应归属 `adk-memory-curator`；AAR 只处理任务复盘后的候选生成 |
| `adk.lock` | adapt | 对齐当前 `agent-dev-kit` worktree commit，恢复锁文件门禁 |
| fallback sunset | archive-only | 当前通过阈值，但 live footprint 多数为 gap，不升级为满分或 release-ready 声明 |

## Validation Evidence

| Command | Result | Summary |
|---|---|---|
| `rtk bash scripts/check-upstream-intake-readiness.sh .` | pass | 80 条 adopt 行具备证据 |
| `rtk bash scripts/check-adoption-matrix-status.sh .` | pass | adoption matrix 无 pending/blocked 状态错误 |
| `rtk bash agent-dev-kit/scripts/pilot-readiness.sh --summary-json` | pass | `pilots=10`, `ready=10`, `device_simulated_pass=1` |
| `rtk bash agent-dev-kit/scripts/check-fallback-sunset.sh --summary-json` | pass | `replacement_score=58/70`，阈值通过但存在 live gaps |
| `rtk bash scripts/check-all.sh --quick` | needs-fix before patch | 暴露 lock、证据路径和 routing trigger 冲突 |
| `rtk bash scripts/check-adk-lock.sh .` | pass after patch | `adk.lock` 与 gitlink / worktree commit 一致 |
| `rtk bash scripts/check-adoption-evidence-integrity.sh .` | pass after patch | `rows=85`, `paths=166` |
| `rtk bash scripts/check-runtime-routing.sh .` | pass after patch | 无 routing conflict，profile coherence 通过 |
| `rtk bash scripts/check-skill-routing-conflicts.sh .` | pass after patch | 无 skill trigger 冲突 |
| `rtk bash agent-dev-kit/scripts/validate-assets.sh --strict` | pass after patch | strict asset validation 通过 |
| `rtk bash scripts/evidence-bundle.sh . --format json --max-summary-chars 1200` | pass after submodule commit | 子仓提交后 `subrepo_state` 恢复为 `unexpected_dirty=0` |

## Remaining Risk

- `embedded-production-field-readiness` 的设备侧状态包含 `simulated-pass`，不能声明真实硬件 production-ready。
- fallback sunset 的 `live=gap` 说明本次复审没有把全部 core fallback 替换项升级为 live footprint 完整证据。
- 本次不执行 `~/codex -> ~/.codex` apply 链路，因此不声明 live target 已刷新。
- `agent-dev-kit` 子仓改动已提交为 `df59f253ded3fec892ba9e50658d9cf94f6714c7`；父仓通过 gitlink 和 `adk.lock` 固定该版本。
