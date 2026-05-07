# llm_agent 使用指南

`llm_agent` 是长期跟踪 AI Coding 参考仓、吸收高价值工程实践，并把稳定实践压实到 `agent-dev-kit`（adk）的工作区。

当前生产目标不是把参考仓内容直接混装进 `~/.codex`，而是走固定闭环：

1. 参考子仓：同步、扫描、评估优秀实现。
2. `subrepos/adoption-matrix.md`：记录 `adopt/observe/reject` 决策与证据。
3. `agent-dev-kit`：把采纳项实现为 Agent/Skill/Workflow/runbook/script/test。
4. `~/.codex`：只安装经过 adk 门禁压实的资产。
5. `reports/`：记录 pilot、安装、回归和回灌结论。

## 快速入口

```bash
# 本工作区所有命令必须通过 rtk 执行
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-global-codex-health.sh ~/.codex minimal
```

## 常用文档

- `docs/llm-agent-maintenance-guide.md`：工作区持续维护和生产验证详细指南。
- `scripts/README.md`：子仓治理、门禁和同步脚本说明。
- `AGENTS.md`：本工作区代理执行规则与维护记录。
- `subrepos/registry.csv`：参考子仓单一清单。
- `subrepos/adoption-matrix.md`：参考仓吸收决策矩阵。
- `reports/codex-pilot-report.md`：`~/.codex` pilot 证据。
- `reports/adk-production-landing-implementation-2026-05-02.md`：adk 生产级落地记录。
- `agent-dev-kit/README.md`：adk 使用指南。
- `agent-dev-kit/docs/codex-agents-integration.md`：`~/.codex/AGENTS.md` 与 adk 配合指南。

## 维护原则

- 先压实 adk，再追踪参考子仓更新。
- 不把第三方参考资产直接复制进 `~/.codex`。
- `agent-dev-kit/manifest.yaml` 是 adk Agent/Skill/Profile 的单一事实源。
- 生产部署必须启用 `--backup`、`--install-report`、`--lock-version`。
- 没有命令证据，不声明“完成”“可发布”“可在生产使用”。

## 生产放行标准

最小放行命令：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

该命令覆盖：

- adk strict validate
- optional skill 回归
- 外部引用检查
- skill metadata
- skill routing conflict
- 文档同步
- adoption matrix 状态
- observe/delivery 吸收深度
- runtime routing
- upstream intake
- adk 全量测试
- codex pilot evidence
- codex pilot coverage
- 全局 `~/.codex` health

## 下一步维护

1. 若只修改 adk 文档：至少运行 `rtk scripts/check-doc-sync.sh .` 与相关 adk 测试。
2. 若修改 Agent/Skill/Profile：运行 `rtk agent-dev-kit/tests/run_all.sh`。
3. 若影响生产部署或 `~/.codex`：运行 `rtk scripts/check-adk-harden-readiness.sh . --require-pilot`。
4. 若吸收参考仓更新：先确认 adk 门禁通过，再执行同步和 diff scan。
