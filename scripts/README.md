# 子仓治理脚本使用手册

## 0. 阶段门禁（先压实 gdk）

默认策略：先压实 `global-dev-kit`，再跟踪外部子仓更新。  
门禁文件：`subrepos/phase-gate.env`（默认 `allow_upstream_sync=no`）。

```bash
# 先做压实检查（严格校验 + 可选技能回归 + 外部引用门禁）
scripts/check-gdk-harden-readiness.sh .

# 通过后自动开门（可选）
scripts/check-gdk-harden-readiness.sh . --open-gate

# 要求 codex 试跑证据也必须就绪（更严格）
scripts/check-gdk-harden-readiness.sh . --require-pilot
scripts/check-gdk-harden-readiness.sh . --require-pilot --open-gate

# 若临时不检查全局 ~/.codex 健康（不建议）
scripts/check-gdk-harden-readiness.sh . --skip-global-codex-check

# 若临时跳过 gdk 全量回归（不建议）
scripts/check-gdk-harden-readiness.sh . --skip-full-suite
```

若未开门，`sync-subrepos.sh` / `diff-scan.sh` 会返回 `[BLOCK]`。  
紧急一次性绕过：追加 `--force`（建议仅临时使用并留痕）。

codex 试跑证据检查脚本：

```bash
scripts/check-codex-pilot-evidence.sh .
```

全局 `~/.codex` 健康检查脚本：

```bash
scripts/check-global-codex-health.sh ~/.codex minimal
```

当前默认不强制 `--require-pilot`。  
如需“先试跑再开门”，请在开门命令追加 `--require-pilot`。

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

## 3. 检查 AGENTS 覆盖

```bash
scripts/check-agents-coverage.sh .
```

- 检查项：
  - 子仓是否存在本地 `AGENTS.md`
  - 根 `AGENTS.md` 是否包含子仓名称
