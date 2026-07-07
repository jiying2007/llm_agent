# llm_agent 工作区入口

`llm_agent` 是长期跟踪 AI Coding 参考实现并把高价值实践压实到 `agent-dev-kit` 的治理工作区。

本文件只保留 AI 进入本仓时必须立即执行的路由、硬边界和高频入口。长清单、历史记录和详细 runbook 不放在这里：

- 维护指南：`docs/llm-agent-maintenance-guide.md`
- 吸收治理：`docs/absorption-governance.md`
- 子仓清单 SSOT：`subrepos/registry.csv`
- 采纳/观察/拒绝记录：`subrepos/adoption-matrix.md`
- 结构化矩阵：`subrepos/adoption-matrix.jsonl`
- adk 源资产：`agent-dev-kit/`

进入任一子仓后，若该子仓存在本地 `AGENTS.md`，则子仓规则优先于本文件。

## 1. 工作原则

1. 默认中文输出，技术标识保留英文。
2. 修改前先确认目标子仓本地 `AGENTS.md`、README 和局部约定。
3. 默认单次只改一个子仓，避免混合提交。
4. 无验证证据不得声称“完成”“可提交”“可合并”。
5. 发现已有 dirty 变更时默认视为用户改动；不得回退、覆盖或清理无关变更。
6. 不自动 commit / push / merge / rebase，除非用户明确要求。
7. 所有 shell 命令必须通过 `rtk` 执行，例如 `rtk scripts/check-doc-sync.sh .` 或 `rtk bash -lc "..."`。
8. 手工创建或修改源码、脚本、配置和文档时必须使用 `apply_patch`。

## 2. 意图路由

| 用户意图 | 触发关键词 | 执行动作 | 主要入口 |
|---|---|---|---|
| 接入新仓库 | 接入、新增子仓、add repo、onboard、纳入治理 | 先发现/评分/隔离分析，再注册或拒绝 | `docs/runbooks/oss-intake-lifecycle.md`、`scripts/oss-intake.sh` |
| 全面检查 | 检查、check、验证、门禁、健康检查 | 运行一键检查并汇总门禁结果 | `scripts/check-all.sh`、`scripts/devkit.sh check` |
| 同步子仓 | 同步、sync、拉取更新、fetch | 在 phase gate 允许后拉取 enabled active 参考仓；`agent-dev-kit` 为应用/落地仓，默认排除 | `scripts/sync-subrepos.sh` |
| 差异扫描 | 差异、diff、变更、最近变化 | 扫描子仓近 N 天变更 | `scripts/diff-scan.sh` |
| 深度分析 | 深度分析、拆解、analyze、prompt分析、skill拆解 | 对参考实现做结构化分析，输出可采纳/观察/拒绝依据 | `scripts/analyze-repo.sh` |
| 生成周报 | 周报、weekly report、本周汇总 | 生成本周变更周报 | `scripts/generate-weekly-report.sh` |
| 清理报告 | 清理、归档、cleanup、prune | 归档过期报告 | `scripts/cleanup-reports.sh` |
| 版本发布 | 发布、release、tag、版本 | 执行发布流程 | `scripts/version-manager.sh` |
| 健康摘要 | summary-json、低 token 健康、health json | 输出低 token JSON 健康摘要 | `scripts/health-check.sh --summary-json` |
| 安装 hook | hook、pre-commit、提交检查 | 安装 git pre-commit hook | `scripts/install-pre-commit-hook.sh` |
| 一键流水线 | 流水线、pipeline、一键更新、全量更新 | 同步、差异、分级、分析、采纳、模式检测、吸收、报告 | `scripts/pipeline-subrepo-update.sh` |
| 优化 adk | 优化、改进、升级 adk、enhance | 在 `agent-dev-kit` 压实资产、验证并记录证据 | `agent-dev-kit/scripts/devkit.sh` |
| 自动吸收 | 吸收、absorb、自动吸收、提取模式 | 必须全盘比对、去重、冲突检查、冗余检查、架构评估、决策论证、质量补充、验证 | `docs/absorption-governance.md`、`scripts/auto-absorb.sh` |
| 需求探索增强 | brainstorm、grill-me、需求拷问、先发散、拷问需求 | 先发散 2-4 个方向，再收敛目标/非目标/边界/验收 | `adk-structured-requirements-questioning`、`adk-requirements-triage` |
| 备份回滚 | 备份、回滚、backup、rollback、恢复 | 创建安装备份、列出备份、恢复或回滚 | `agent-dev-kit/scripts/backup-rollback.sh` |
| 冻结后周期 | 冻结后、post-freeze、冻结后检查、周期执行 | 文档同步、差异扫描、采纳矩阵状态、摘要生成 | `scripts/run-post-freeze-cycle.sh` |

## 3. 吸收与落地边界

1. 外部实践吸收必须先判断“可借鉴优点”和“不可迁移缺点”，禁止只做完全增量更新。
2. 高价值实践优先在 `agent-dev-kit` 落地为 Agent、Skill、Workflow、manifest、脚本或 runbook，再更新采纳矩阵。
3. `agent-dev-kit -> ~/codex -> ~/.codex` 是运行资产交付链路；不要从本仓绕过 `~/codex` 直接修改 `~/.codex`。
4. `subrepos/phase-gate.env` 控制是否允许追踪上游更新；未满足压实门禁时不要常态同步参考仓。
5. 官方 OpenAI 实践吸收要记录 source URL、retrieved_at、review_status、expires_at，并区分“实质吸收”和“纳入观察”。

## 4. 常用验证入口

日常轻量检查：

```bash
rtk scripts/check-doc-sync.sh .
rtk scripts/check-agents-coverage.sh .
rtk scripts/check-adoption-matrix-status.sh .
rtk scripts/check-adk-target-evidence.sh .
rtk scripts/check-token-budget.sh . --summary-json
```

adk 或治理资产改动后：

```bash
rtk scripts/check-adk-harden-readiness.sh .
rtk scripts/check-all.sh --quick
```

准备刷新 `~/codex -> ~/.codex` 运行资产时，必须走 source-to-live 链路，最小证据链见 `docs/llm-agent-maintenance-guide.md`。

## 5. 文档分流

| 内容 | 写入位置 |
|---|---|
| 子仓是否纳入治理、状态、owner、复审日期 | `subrepos/registry.csv` |
| 候选实践的采纳/观察/拒绝、目标层和证据 | `subrepos/adoption-matrix.md` |
| 结构化低 token 读取 | `subrepos/adoption-matrix.jsonl` |
| 维护流程、门禁解释、source-to-live 证据链 | `docs/llm-agent-maintenance-guide.md` |
| 新仓发现、评分、注册、拒绝生命周期 | `docs/runbooks/oss-intake-lifecycle.md` |
| 自动吸收的全盘评估规则 | `docs/absorption-governance.md` |
| 一次性试跑、复核、周报、证据包 | `reports/` |

根 `AGENTS.md` 只在路由、硬边界或高频入口变化时更新；不要把完整参考子仓清单、历史计划、长报告或一次性分析写回本文件。

## 6. 维护记录

详细历史记录参见 `reports/` 和相关 runbook。维护本入口时至少运行：

```bash
rtk scripts/check-doc-sync.sh .
rtk scripts/check-agents-coverage.sh .
```
