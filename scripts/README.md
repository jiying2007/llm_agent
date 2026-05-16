# 子仓治理脚本使用手册

完整维护流程见 `docs/llm-agent-maintenance-guide.md`。本文件只说明脚本入口、门禁含义与常用参数。

## Registry 字段约定（v1）

`subrepos/registry.csv` 统一使用以下列：

```csv
repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade
```

- `status`：`active` / `disabled`
- `owner`：治理责任方
- `last_reviewed_on`：最近复审日期（`YYYY-MM-DD`）
- `intake_policy`：吸收策略（如 `adopt-first`、`observe-first`、`selective-adopt`、`pilot-first`）

## 0. 阶段门禁（先压实 adk）

默认策略：先压实 `agent-dev-kit`，再跟踪外部子仓更新。

### adk v2.0.0 当前状态（2026-05-05）

- 综合评分: 97/100
- 全量测试: 97/97 通过
- 意图路由: 22 条 routing 覆盖全部 28 个 core skill
- 模板体系: 18 个模板全部填充（含使用说明）
- Profile: 10 个，含选择指南
- Scripts: 24 个，8 个运维命令接入 devkit.sh
- 安装验证: `agent-dev-kit -> ~/codex -> ~/.codex` 真实链路验证
- shellcheck: 已修复关键警告  
门禁文件：`subrepos/phase-gate.env`（默认 `allow_upstream_sync=no`）。

```bash
# 先做压实检查（严格校验 + 可选技能回归 + 外部引用门禁）
scripts/check-adk-harden-readiness.sh .

# 通过后自动开门（可选）
scripts/check-adk-harden-readiness.sh . --open-gate

# 要求 codex 试跑证据也必须就绪（更严格）
scripts/check-adk-harden-readiness.sh . --require-pilot
scripts/check-adk-harden-readiness.sh . --require-pilot --open-gate

# 若临时不检查全局 ~/.codex 健康（不建议）
scripts/check-adk-harden-readiness.sh . --skip-global-codex-check

# 若临时跳过 adk 全量回归（不建议）
scripts/check-adk-harden-readiness.sh . --skip-full-suite

# 显式打开三类新增门禁检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-skill-metadata --check-routing-conflicts --check-doc-sync

# 显式打开矩阵状态检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-matrix-status

# 显式打开 observe 吸收深度检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-observe-intake-depth

# 显式打开 delivery 采纳深度检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-delivery-adopt-depth

# 显式打开生产级路由、pilot 覆盖、上游吸收、Codex handoff 规范检查（默认已开启）
scripts/check-adk-harden-readiness.sh . --check-runtime-routing
scripts/check-adk-harden-readiness.sh . --check-pilot-coverage
scripts/check-adk-harden-readiness.sh . --check-upstream-intake
scripts/check-adk-harden-readiness.sh . --check-codex-handoff

# 临时跳过某类新增检查（不建议）
scripts/check-adk-harden-readiness.sh . --skip-skill-metadata-check
scripts/check-adk-harden-readiness.sh . --skip-routing-conflicts-check
scripts/check-adk-harden-readiness.sh . --skip-doc-sync-check
scripts/check-adk-harden-readiness.sh . --skip-matrix-status-check
scripts/check-adk-harden-readiness.sh . --skip-observe-intake-depth-check
scripts/check-adk-harden-readiness.sh . --skip-delivery-adopt-depth-check
scripts/check-adk-harden-readiness.sh . --skip-runtime-routing-check
scripts/check-adk-harden-readiness.sh . --skip-pilot-coverage-check
scripts/check-adk-harden-readiness.sh . --skip-upstream-intake-check
scripts/check-adk-harden-readiness.sh . --skip-codex-handoff-check
```

若未开门，`sync-subrepos.sh` / `diff-scan.sh` 会返回 `[BLOCK]`。  
紧急一次性绕过：追加 `--force`（建议仅临时使用并留痕）。

codex pilot 统一检查脚本（合并 evidence + coverage + 场景验证）：

```bash
# 完整检查（默认模式：evidence + coverage + 场景验证）
scripts/check-codex-pilot.sh .

# 只检查 4 个基础证据字段
scripts/check-codex-pilot.sh . evidence

# 只检查 7 个覆盖字段
scripts/check-codex-pilot.sh . coverage

# 完整检查（等价于默认模式）
scripts/check-codex-pilot.sh . full
```

当 `pilot_full_coverage_ready=yes` 时，`coverage` 和 `full` 模式会强制校验六类场景字段、场景章节、`ImplementationPlan/ReviewReport/TestReport` artifact 标签与命令级 Evidence Index。

> **旧脚本兼容提示**：`check-codex-pilot-evidence.sh` 和 `check-codex-pilot-coverage.sh` 已标记为弃用，会自动转发到新脚本。

全局 `~/.codex` 健康检查脚本（运行目录由 `~/codex` apply 生成）：

```bash
scripts/check-global-codex-health.sh ~/.codex minimal
```

技能元数据检查脚本：

```bash
scripts/check-skill-metadata.sh .
```

技能路由冲突检查脚本：

```bash
scripts/check-skill-routing-conflicts.sh .
```

文档与治理文件同步检查脚本：

```bash
scripts/check-doc-sync.sh .
```

tracked 文件权限检查脚本：

```bash
# 检查工作区权限是否匹配 Git index：100644 不可执行，100755 可执行
scripts/check-file-modes.sh .

# 修复工作区权限漂移，不改 Git index
scripts/check-file-modes.sh . --fix
```

该检查已接入 `scripts/check-all.sh` 和 `scripts/check-adk-harden-readiness.sh`。文档、README、manifest、skill、template 默认不应带 executable bit；`scripts/*.sh`、可直接执行的测试脚本和稳定 CLI 包装层应保持 executable bit。

adoption-matrix 状态检查脚本（真实记录不得有 `pending`，`blocked` 必须写解除条件）：

```bash
scripts/check-adoption-matrix-status.sh .
```

observe 吸收深度检查脚本（`observe+done` 行必须同时具备 Agent/Skill/Workflow 三层证据，并附 intake 任务包报告证据）：

```bash
scripts/check-observe-intake-depth.sh .
```

当 `observe+done` 行为 0（已全部收口为 `adopt/reject`）时，脚本返回通过并提示 backlog cleared。

delivery 采纳深度检查脚本（`delivery + adopt + done` 行必须同时具备 Agent/Skill/Workflow 三层证据，并附 wave 任务包报告证据）：

```bash
scripts/check-delivery-adopt-depth.sh .
```

生产级 runtime routing 资产检查脚本：

```bash
scripts/check-runtime-routing.sh .
```

该脚本会同时调用 `agent-dev-kit/scripts/check-profile-coherence.sh`，防止 profile 继承后重复声明 Agent/Skill 或引用漂移。

上游吸收生产准入检查脚本：

```bash
scripts/check-upstream-intake-readiness.sh .
```

当前默认不强制 `--require-pilot`。  
如需“先试跑再开门”，请在开门命令追加 `--require-pilot`。

工作区入口回归检查脚本：

```bash
scripts/check-workspace-entrypoints.sh .
```

该脚本覆盖 `scripts/devkit.sh health`、`scripts/devkit.sh sync status`、旧 pilot wrapper、weekly report 输出和 registry 评级列解析，防止统一入口与文档承诺再次漂移。

## 1. 同步子仓增量

```bash
scripts/sync-subrepos.sh . fetch
scripts/sync-subrepos.sh . pull
scripts/sync-subrepos.sh . fetch --force
```

- `fetch`：对启用子仓执行 `git fetch --all --prune`
- `pull`：仅对 `registry.csv` 中 `sync_mode=pull` 的子仓执行 `git pull --ff-only`

## 2. 扫描高价值变更

```bash
scripts/diff-scan.sh . 7 reports/weekly-change-report.md
scripts/diff-scan.sh . 7 reports/weekly-change-report.md --force
```

- 参数 2：扫描最近 N 天（默认 `7`）
- 参数 3：报告输出路径（默认 `reports/weekly-change-report.md`）

冻结后一键巡检（文档同步 + 周报扫描 + 矩阵状态）：

```bash
scripts/run-post-freeze-cycle.sh .
scripts/run-post-freeze-cycle.sh . 7 reports/weekly-change-report.md
```

adoption-matrix 汇总报告生成脚本（统计 done/pending/blocked 与类别分布）：

```bash
scripts/generate-adoption-matrix-summary.sh .
scripts/generate-adoption-matrix-summary.sh . reports/adoption-matrix-summary.md
```

## 3. 检查 AGENTS 覆盖

```bash
scripts/check-agents-coverage.sh .
```

- 检查项：
  - 子仓是否存在本地 `AGENTS.md`
  - 若上游参考子仓不适合直接写入治理文件，可使用根仓托管覆盖文件 `subrepos/agents/<repo>.md`
  - 根 `AGENTS.md` 是否包含子仓名称

## 4. 新仓库接入

当有新参考仓库需要纳入 llm_agent 治理时，使用一键接入脚本：

```bash
scripts/new-repo-onboard.sh <repo-path> [--adopt|--observe|--selective|--pilot]
```

功能：
- 自动注册到 `registry.csv`
- 生成/追加仓库 `AGENTS.md`
- 更新 `adoption-matrix.md`
- 运行基础检查
- 生成接入报告到 `reports/`

详细流程参见：`docs/runbooks/new-repo-onboarding.md`

## 5. 备份回滚

```bash
scripts/backup-rollback.sh [ACTION] [OPTIONS]
```

功能：
- 提供安装资产的备份和回滚能力。
- `backup`：创建当前 `~/.codex` 的完整备份快照；生产变更优先使用 `~/codex` apply plan / rollback。
- `rollback`：从已有备份点恢复 `~/.codex`；常规资产回滚优先走 `~/codex/scripts/rollback.sh`。
- `list`：列出所有可用备份点。
- 支持自动清理过期备份。

## 6. 全局 codex 目标策略校验

```bash
scripts/check-global-codex-target-policy.sh [WORKSPACE_ROOT]
```

功能：
- 确保工作区未回退到使用本地 `codex/` 目录。
- 校验 `registry.csv` 中 codex 行的策略指向 `~/codex` 声明式资产仓库，并由其 apply 到全局 `~/.codex`。
- 已接入 `check-adk-harden-readiness.sh` 主链路。

详细排查参见：`docs/runbooks/quality-gate-checklist.md`

## 7. 一键门禁检查

```bash
# 运行所有 check-* 脚本并汇总结果
scripts/check-all.sh

# 快速模式（跳过耗时的 check-adk-harden-readiness.sh）
scripts/check-all.sh --quick

# 详细模式（显示每个脚本的完整输出）
scripts/check-all.sh --verbose

# 组合使用
scripts/check-all.sh --quick --verbose
```

功能：
- 自动发现 `scripts/check-*.sh` 并逐个运行
- 记录每个脚本的 PASS/FAIL 状态
- 最后输出汇总表（脚本名 + 状态标记）
- `--quick` 模式跳过耗时的 `check-adk-harden-readiness.sh`
- 退出码：全部通过返回 0，否则返回 1

## 8. 统一入口 devkit.sh

```bash
# 查看帮助
scripts/devkit.sh help

# 一键门禁检查
scripts/devkit.sh check --quick
scripts/devkit.sh check --full

# 新仓库接入
scripts/devkit.sh onboard <repo-path> --adopt
scripts/devkit.sh onboard <repo-path> --observe

# 子仓同步
scripts/devkit.sh sync fetch
scripts/devkit.sh sync pull
scripts/devkit.sh sync status

# 差异扫描（默认 7 天）
scripts/devkit.sh diff
scripts/devkit.sh diff 14

# 健康检查
scripts/devkit.sh health

# 生成周报
scripts/devkit.sh weekly-report

# 清理过期报告
scripts/devkit.sh cleanup --dry-run
scripts/devkit.sh cleanup
```

`devkit.sh` 是 `llm_agent` 工作区的统一运维入口，将分散的脚本按功能聚合为子命令，降低记忆成本。

## 9. 工作区健康检查

```bash
scripts/health-check.sh check-all --root .
scripts/health-check.sh .
```

功能：
- 对 `llm_agent` 工作区执行综合健康检查。
- 检查项包括：目录结构完整性、关键文件存在性、registry 格式、依赖、门禁入口、脚本语法。
- 输出通过/失败/警告三级状态报告。

## 10. 版本管理

```bash
scripts/version-manager.sh [ACTION] [OPTIONS]
```

功能：
- 管理 `agent-dev-kit` 的版本锁定和升级路径。
- `check`：检查当前版本状态。
- `lock`：锁定当前版本号。
- `upgrade`：执行版本升级并验证。
- 支持版本回退和变更日志生成。

## 11. 自动生成周报

```bash
scripts/generate-weekly-report.sh [WORKSPACE_ROOT]
```

功能：
- 自动汇总最近 7 天 git 提交摘要。
- 读取 `subrepos/registry.csv` 中 `enabled=yes` 的子仓同步状态。
- 统计 `adoption-matrix.md` 决策分布与本周变更。
- 运行质量门禁快速检查（health-check / matrix-status / agents-coverage）。
- 输出报告到 `reports/weekly-report-YYYY-MM-DD.md`。

建议配合 cron 定时执行：
```bash
# 每周五下午 6 点自动生成周报
0 18 * * 5 cd /path/to/llm_agent && rtk scripts/generate-weekly-report.sh .
```

## 12. 清理归档旧报告

```bash
scripts/cleanup-reports.sh [WORKSPACE_ROOT] [--dry-run] [--days N]
```

功能：
- 将 `reports/` 中超过指定天数的 `.md` 报告移入 `reports/archive/`。
- 保留 `.template.md` 模板文件不移动。
- `--dry-run`：只显示会移动的文件，不实际执行。
- `--days N`：自定义天数阈值，默认 30 天。

示例：
```bash
# 模拟清理（查看哪些文件会被归档）
scripts/cleanup-reports.sh . --dry-run

# 清理 60 天前的报告
scripts/cleanup-reports.sh . --days 60
```

## 13. 安装 Pre-commit Hook

```bash
scripts/install-pre-commit-hook.sh [WORKSPACE_ROOT]
```

功能：
- 安装 git pre-commit hook 到 `.git/hooks/pre-commit`。
- 自动备份已有 hook（`.bak.YYYYMMDDHHMMSS`）。

hook 检查项：
1. **Shell 脚本语法**：对 `scripts/*.sh` 及暂存区中的 `.sh` 文件执行 `bash -n` 语法检查。
2. **AGENTS.md 引用文件**：检查 `AGENTS.md` 中反引号引用的 `.md/.sh/.py/.csv/.json/.yaml/.yml/.env` 文件是否存在。
3. **registry.csv 格式**：校验表头、列数（12列）、`enabled`（yes/no）和 `status`（active/disabled）字段值。

跳过 hook 检查：`git commit --no-verify`

卸载 hook：`rm .git/hooks/pre-commit`
