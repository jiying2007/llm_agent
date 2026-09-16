# llm_agent 使用指南

`llm_agent` 是长期跟踪 AI Coding 参考仓、评估高价值工程实践，并把经审查实践压实到 `agent-dev-kit`（ADK）的证据化工作区。ADK 是平台中立的 Agent 资产编译、安装、评测和发布控制面；两者都不是通用 LLM/Agent runtime。

当前生产目标不是把参考仓内容直接混装进 `~/.codex`，而是走固定闭环：

1. 参考仓：身份以 `manifests/reference_pins.json` 的不可变 commit 快照保存；默认**不作为 Root submodule/source checkout**，需要源码取证时才显式 materialize 到用户 cache。
2. `reports/repo-analysis/`：保存 `analysis.json`、`review-required` 决策候选和 task pack。
3. `subrepos/adoption-matrix.md`：只在语义、重复、架构、许可证、安全和效果复核后记录 `adopt/observe/reject`。
4. `agent-dev-kit`：把批准项实现为 Agent/Skill/Workflow/Profile/runbook/script/test，并导出可交接资产。
5. `~/codex`：作为 Codex CLI 声明式资产仓库，吸收 ADK 资产并完成 build/doctor/plan/apply 治理。
6. `~/.codex`：只接收 `~/codex` apply 后的运行资产。
7. `reports/`：记录评测、pilot、安装、回归和回灌结论。

运行态 target 由 `manifests/runtime_targets.json` 显式声明，健康检查 adapter 由 `manifests/runtime_health_adapters.json` 绑定；当前默认 target 是 `codex-home`，其 source/live 链路为 `agent-dev-kit -> ~/codex -> ~/.codex`。其他运行时如 `claude-code`、`opencode` 保留为 supported kind，但必须先声明各自 source/live chain 与只读 health adapter 才能成为 active target。

## 快速入口

```bash
# 本工作区所有命令必须通过 rtk 执行
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
rtk scripts/check-runtime-targets.sh .
rtk scripts/check-runtime-health.sh .
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-upstream-intake-readiness.sh .

# LTA-02 跨运行时可移植性只读认证；真实双运行时证据缺失时必须返回 BLOCKED
rtk python -m tools.control_plane.cli runtime-portability --root . --summary-json

# LTA-04 30 天纵向运营只读认证；窗口未满或真实 summary 缺失时必须返回 BLOCKED
rtk python -m tools.control_plane.cli longitudinal-operation --root . --summary-json

# reference repo 默认只校验 exact pins，不拉取源码
rtk python -m tools.control_plane.reference_pins --root . --summary-json

# 查看某个参考仓将被物化到哪个用户 cache 目录（无网络写入）
rtk python -m tools.control_plane.reference_pins --root . --plan OpenSpec --summary-json

# 只有显式指定 ID 时才按 exact commit 拉到用户 cache
rtk python -m tools.control_plane.reference_pins --root . --materialize OpenSpec --summary-json
```

Root 控制面的统一 Python 入口是 `llm-ctl`（`pyproject.toml`）；GitHub Actions 和本地脚本逐步收敛到同一组 `tools.control_plane` 实现。Reference materialization 永远不把第三方仓重新写回 Root working tree。

`runtime-portability` 只认证已经存在的真实 comparison evidence，不启动模型、不执行第二运行时，也不生成外部证据。它要求至少两个不同且健康的 runtime binding 共享同一 frozen task 与精确 ADK release identity，各自拥有独立 execution receipt，并由 `digital-worker` 提供绑定同一 receipt 集的 domain verification 与 independent review。缺少第二运行时、binding 仍为 future-only、或证据缺失时均为 `BLOCKED`，不能升级成 PASS。

`longitudinal-operation` 只读取现有 Software M5 append-only field ledger/event log 与 LTA-04 summary，不创建现场事件，也不会把 Product M5 的初始资格重新改成 30 天门禁。当前独立 pilot 从 `2026-09-12T04:19:00Z` 开始，因此 LTA-04 最早在 `2026-10-12T04:19:00Z` 之后才可能通过。到期后 summary 必须绑定当前 event-chain head，并显式表示 incident、regression、recovery 和 unresolved risk；即使数量为 0 也必须明确写出。存在 blocking risk 或 review hold 时仍返回 `BLOCKED`。

## 常用文档

- `docs/llm-agent-maintenance-guide.md`：工作区持续维护和生产验证详细指南。
- `docs/product-maturity-model.md`：M0-M5、十二维和 source/test/runtime/field 证据模型。
- `manifests/product_maturity_scorecard.json`：当前产品成熟度机器 SSOT。
- `manifests/product_maturity_task_pack.json`：剩余门禁与可执行任务包。
- `manifests/long_term_asset_qualification.json`：Product M5 之上的长期资产终态资格 SSOT；单人维护、LTA-01～LTA-04 与 terminal blocker 均在此 fail-closed 判定。
- `manifests/adk_interface.lock.json`：当前 ADK 跨仓接口身份与 active/deprecated surface contract。
- `manifests/reference_pins.json`：非 source reference repository 的 exact commit / URL SSOT。
- `manifests/gitlinks.json`：Root managed dependency gitlink registry；终态仅保留 ADK 与 Codex。
- `manifests/digital_worker_runtime_pilot.json`：`digital-worker + agent-dev-kit + llm_agent` 联合 Runtime Pilot 的 report-only 证据合同；Runtime 输出不得替代 Verification PASS。
- `tools/control_plane/runtime_portability.py`：LTA-02 双运行时真实 comparison evidence 的只读、fail-closed 认证器。
- `tools/control_plane/longitudinal_operation.py`：LTA-04 30 天独立 pilot 纵向运营 summary 的只读、fail-closed 认证器。
- `scripts/README.md`：子仓治理、门禁和同步脚本说明。
- `AGENTS.md`：本工作区代理执行规则与维护记录。
- `subrepos/registry.csv`：参考仓 intake/生命周期清单。
- `subrepos/adoption-matrix.md`：参考仓吸收决策矩阵。
- `manifests/runtime_targets.json`：运行态 target registry。
- `manifests/runtime_health_adapters.json`：运行态健康检查 adapter contract。
- `docs/runbooks/runtime-target-activation.md`：新增或启用 runtime target 的 checklist。
- `reports/reference-dirty-triage-YYYY-MM-DD.md`：参考仓 dirty 分流报告。
- `reports/codex-pilot-report.md`：`~/codex -> ~/.codex` pilot 证据。
- `reports/adk-production-landing-implementation-2026-05-02.md`：ADK 生产级落地记录。
- `agent-dev-kit/README.md`：ADK 使用指南。
- `agent-dev-kit/docs/codex-agents-integration.md`：`~/.codex/AGENTS.md` 与 ADK 配合指南。

## 维护原则

- 先压实 ADK，再追踪参考仓更新。
- **只有 `agent-dev-kit` 与 `codex` 是 Root managed gitlink/source dependency。** OpenSpec、digital-worker、superpowers、vibeflow 等研究/试点仓只保留 exact reference pin，并按需物化到用户 cache。
- reference pin 是 evidence identity，不是 runtime enablement，也不允许递归 checkout 重新引入 Root source dependency。
- 不把第三方参考资产或 ADK 导出资产直接复制进 `~/.codex`；必须先进入 `~/codex` 的源资产与 manifest 治理链路。
- `agent-dev-kit/manifest.json` 是 ADK 唯一结构化 Manifest SSOT；当前跨仓身份由 `adk.lock` 与 `manifests/adk_interface.lock.json` 原子绑定，不维护平行 Manifest 镜像。
- direct target 安装必须先生成 plan，再 apply 并保留 receipt；回滚拒绝已漂移的托管资产。
- 仓库不提供自动吸收写入口；静态分析不能直接修改 adoption matrix 或 ADK。
- 没有命令证据，不声明“完成”“可发布”“可在生产使用”。
- 深度跨仓验证按 `manifests/gates.json` 的输入/依赖图计算，不再在 workflow 中维护平行路径正则。

## 生产放行标准

最小放行命令：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

该命令覆盖软件与模拟 pilot 门禁，但不替代真实现场证据。它覆盖：

- ADK strict validate
- optional skill 回归
- 外部引用检查
- skill metadata
- skill routing conflict
- 文档同步
- adoption matrix 状态
- observe/delivery 吸收深度
- runtime routing
- upstream intake
- ADK 全量测试
- runtime pilot evidence
- runtime pilot coverage
- `~/codex` build/apply 链路与全局 `~/.codex` health

## 下一步维护

1. 若只修改 ADK 文档：至少运行 `rtk scripts/check-doc-sync.sh .` 与相关 ADK 测试。
2. 若修改 Agent/Skill/Profile/Target：运行 `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` 与 `rtk bash agent-dev-kit/tests/run_all.sh`。
3. 若修改根仓脚本、契约或治理资产：运行 `rtk tests/run_all.sh`；全量门禁使用 `rtk scripts/check-all.sh --full --result-json <artifact>` 留存逐项状态和耗时。
4. 若影响生产部署、`~/codex` 分发或 `~/.codex`：运行 `rtk scripts/check-adk-harden-readiness.sh . --require-pilot`，并在 `~/codex` 侧执行 build/apply dry-run。
5. 若评估 reference repo 更新：先更新/审查 `manifests/reference_pins.json` 的 exact commit，再显式 materialize 到 cache 执行分析；审查结构化 decision/task pack 后才允许创建 ADK change artifact。
6. 若推进 LTA-02：先完成第二 runtime binding 的 source/live/health 治理，再对同一 frozen real task 产出两份独立 execution receipt 与 `digital-worker` verification/review，最后用 `llm-ctl runtime-portability` 认证；在此之前 LTA-02 必须保持 `blocked_external_evidence`。
7. 若推进 LTA-04：继续把真实独立 pilot 事件追加到现有 hash-chain event log；2026-10-12T04:19:00Z 之前 `llm-ctl longitudinal-operation` 必须保持 BLOCKED。到期后生成真实 `reports/long-term-assets/longitudinal-operation-current.json`，绑定当前 event-chain head 并显式汇总 incident/regression/recovery/unresolved risk，再由 certifier 决定 PASS/BLOCKED；禁止用 synthetic fixture 作为资格证据。
