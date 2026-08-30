# llm_agent 工作区规则

高频入口见 `docs/llm-agent-maintenance-guide.md`，吸收边界见 `docs/absorption-governance.md`。

## 1. 默认模式

- 默认简体中文、adk-first、`token-lean`；修改前读目标子仓规则。非平凡任务先冻结目标、边界、风险、验收和产物。
- 根因未明先取证；行为变化补确定性测试。无新鲜证据不得声明完成、可提交或可合并。
- dirty 默认属于用户，不回退、覆盖或清理无关内容；单次默认只改一个子仓。
- 不自动 commit/push/merge/rebase；提交格式 `<type>(scope): <中文动词摘要>`，摘要不超过 50 字且无句号。

## 2. 路由与 SSOT

- 外部实践 intake：`docs/runbooks/external-practice-intake.md`；只生成 review-required candidate。
- 参考仓生命周期：`docs/runbooks/reference-repository-lifecycle.md`；candidate 与 ADOPT decision 分离，默认 dry-run。
- 检查/同步/差异/分析：`scripts/check-all.sh`、`scripts/sync-subrepos.sh`、`scripts/diff-scan.sh`、`scripts/analyze-repo.sh`。
- 优化/发布/吸收：`agent-dev-kit/scripts/devkit.sh`、`scripts/version-manager.sh`、`docs/absorption-governance.md`。
- 子仓 SSOT：`subrepos/registry.csv`；采纳 SSOT：`subrepos/adoption-matrix.md|jsonl`；一次性证据进 `reports/`。

## 3. 硬边界

- shell 必须经 `rtk`；手工源码、脚本、配置和文档修改用 `apply_patch`，禁用 heredoc、重定向、cat、tee、Python 写仓库文件。
- 禁止破坏性命令、直接写 `.git`、硬编码密钥和不可信输入拼接。外网仅显式 `--allow-network`；Gitee 空结果标记 `degraded-empty`。
- MCP/connector/GUI 先声明 transport、权限、工具、deny-path、脱敏和回退；外部写另行授权。
- 运行资产只走 `agent-dev-kit -> ~/codex -> ~/.codex`；不得绕过 source-to-live 或手改 `~/.codex`。

## 4. Token、Hub 与连续性

- 先摘要后原文；按 stable/dynamic/evidence/excluded 管理，压缩保留目标、证据、fallback 和最多 3 个下一步。
- 项目事实、决策、runbook、release、debug 或长期结论先运行：

```bash
rtk bash ~/knowledge-hub/tools/knowledge-context.sh --cwd "$PWD" --query "<任务>" --task-type <type> --context-budget small --limit 3 --summary-json
```

- 已知项目加 `--project`；仅歧义/高风险回退 `--json` 与原文。耐久结论写 reviewing candidate，或声明无可归档结论；不得静默写 memory。
- final/apply/目标切换前先 snapshot；`goal_status=idle` 记 `not-applicable` 并跳过 final gate，仅 active goal 按 Runtime Control 决策收口。

## 5. 验证与并行

- 仅 2–4 个边界独立任务并行；shared contract/schema/根配置/依赖/CI/lockfile 串行，由主 Agent 整合。
- 外部参考只作输入；生产资产由 ADK manifest/handoff 声明。公众号仅 metadata，不保存正文、不自动吸收。
- 轻量门禁：`rtk scripts/check-doc-sync.sh .`、`rtk scripts/check-agents-coverage.sh .`、`rtk scripts/check-token-budget.sh . --summary-json`。
- 非平凡验证先运行 `rtk python3 -m tools.codex_assets.validation_plan --root . --summary-json`；按L1-L4执行，harden优先复用同snapshot supported-full receipt，Codex刷新仍走完整source-to-live。
