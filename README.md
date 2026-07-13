# llm_agent 使用指南

`llm_agent` 是长期跟踪 AI Coding 参考仓、评估高价值工程实践，并把经审查实践压实到 `agent-dev-kit`（ADK）的证据化工作区。ADK 是平台中立的 Agent 资产编译、安装、评测和发布控制面；两者都不是通用 LLM/Agent runtime。

当前生产目标不是把参考仓内容直接混装进 `~/.codex`，而是走固定闭环：

1. 参考子仓：以不可变 commit 快照同步、扫描和生成静态证据。
2. `reports/repo-analysis/`：保存 `analysis.json`、`review-required` 决策候选和 task pack。
3. `subrepos/adoption-matrix.md`：只在语义、重复、架构、许可证、安全和效果复核后记录 `adopt/observe/reject`。
4. `agent-dev-kit`：把批准项实现为 Agent/Skill/Workflow/Profile/runbook/script/test，并导出可交接资产。
5. `~/codex`：作为 Codex CLI 声明式资产仓库，吸收 ADK 资产并完成 build/doctor/plan/apply 治理。
6. `~/.codex`：只接收 `~/codex` apply 后的运行资产。
7. `reports/`：记录评测、pilot、安装、回归和回灌结论。

运行态 target 由 `manifests/runtime_targets.json` 显式声明，健康检查 adapter 由 `manifests/runtime_health_adapters.json` 绑定；当前默认 target 是 `codex-home`，其 source/live 链路为 `agent-dev-kit -> ~/codex -> ~/.codex`。其他运行时如 `claude-code`、`hermes-agent`、`opencode` 保留为 supported kind，但必须先声明各自 source/live chain 与只读 health adapter 才能成为 active target。

## 快速入口

```bash
# 本工作区所有命令必须通过 rtk 执行
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
rtk scripts/check-runtime-targets.sh .
rtk scripts/check-runtime-health.sh .
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-upstream-intake-readiness.sh .
```

## 常用文档

- `docs/llm-agent-maintenance-guide.md`：工作区持续维护和生产验证详细指南。
- `docs/product-maturity-model.md`：M0-M5、十二维和 source/test/runtime/field 证据模型。
- `manifests/product_maturity_scorecard.json`：当前产品成熟度机器 SSOT。
- `manifests/product_maturity_task_pack.json`：剩余门禁与可执行任务包。
- `scripts/README.md`：子仓治理、门禁和同步脚本说明。
- `AGENTS.md`：本工作区代理执行规则与维护记录。
- `subrepos/registry.csv`：参考子仓单一清单。
- `subrepos/adoption-matrix.md`：参考仓吸收决策矩阵。
- `manifests/runtime_targets.json`：运行态 target registry。
- `manifests/runtime_health_adapters.json`：运行态健康检查 adapter contract。
- `docs/runbooks/runtime-target-activation.md`：新增或启用 runtime target 的 checklist。
- `reports/reference-dirty-triage-YYYY-MM-DD.md`：参考子仓 dirty 分流报告。
- `reports/codex-pilot-report.md`：`~/codex -> ~/.codex` pilot 证据。
- `reports/adk-production-landing-implementation-2026-05-02.md`：adk 生产级落地记录。
- `agent-dev-kit/README.md`：adk 使用指南。
- `agent-dev-kit/docs/codex-agents-integration.md`：`~/.codex/AGENTS.md` 与 adk 配合指南。

## 维护原则

- 先压实 adk，再追踪参考子仓更新。
- 不把第三方参考资产或 adk 导出资产直接复制进 `~/.codex`；必须先进入 `~/codex` 的源资产与 manifest 治理链路。
- `agent-dev-kit/manifest.json` 是 ADK 3.0 Agent/Skill/Profile/Target 的结构化 SSOT；`manifest.yaml` 仅是受同步门禁约束的兼容镜像。
- direct target 安装必须先生成 plan，再 apply 并保留 receipt；回滚拒绝已漂移的托管资产。
- 仓库不提供自动吸收写入口；静态分析不能直接修改 adoption matrix 或 ADK。
- 没有命令证据，不声明“完成”“可发布”“可在生产使用”。

## 生产放行标准

最小放行命令：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

该命令覆盖软件与模拟 pilot 门禁，但不替代真实现场证据。它覆盖：

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
- runtime pilot evidence
- runtime pilot coverage
- `~/codex` build/apply 链路与全局 `~/.codex` health

## 下一步维护

1. 若只修改 adk 文档：至少运行 `rtk scripts/check-doc-sync.sh .` 与相关 adk 测试。
2. 若修改 Agent/Skill/Profile/Target：运行 `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` 与 `rtk bash agent-dev-kit/tests/run_all.sh`。
3. 若影响生产部署、`~/codex` 分发或 `~/.codex`：运行 `rtk scripts/check-adk-harden-readiness.sh . --require-pilot`，并在 `~/codex` 侧执行 build/apply dry-run。
4. 若评估参考仓更新：先运行 `rtk scripts/analyze-repo.sh <repo> --ref HEAD --all`，审查结构化 decision/task pack 后再决定是否创建 ADK change artifact。
