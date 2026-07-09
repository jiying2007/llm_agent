# Runtime Target Activation Runbook

本 runbook 用于把 `claude-code`、`hermes-agent`、`opencode` 等 runtime target 从 candidate 提升为 `enabled=true`。默认 target 仍是 `codex-home`；新增 target 不得绕过 source/live chain、只读 health adapter、dry-run 和 rollback 证据。

## 1. 目标边界

- `llm_agent` 只声明和校验 runtime target，不直接写 live root。
- live 写入必须通过对应 source repo 的声明式 apply chain。
- 参考子仓不得成为 runtime target。
- target 启用前必须先通过 `check-runtime-targets.sh --explain-target <id>` 确认缺口。
- 真正 apply 或 rollback 属于写 live root 操作，必须有人工授权；本 runbook 默认只做声明、dry-run、报告和验证。

## 2. Candidate 前置状态

启用前，target 与 adapter 应处于可解释的 candidate 状态：

- target: `enabled=false`
- target: `role=target-candidate`
- target: `write_policy=not-enabled`
- target 不声明 active `source_repo`、`live_root`、`registry_repo`、`health_adapter`、`footprint_check`、`target_policy_check`
- adapter: `enabled=false`
- adapter: `status=candidate`
- adapter: `script=null`
- adapter: `target_ids=[]`
- adapter: `profiles=[]`
- adapter: `read_only=true`

## 3. Activation Checklist

### 3.1 Target Registry

在 `manifests/runtime_targets.json` 中更新目标 target：

- `enabled=true`
- `role` 不得为 `target-candidate`
- `source_repo` 指向声明式 source repo
- `live_root` 指向 runtime live root
- `registry_repo` 指向治理 registry 名称
- `source_to_live_chain` 为非空数组
- `health_adapter` 指向 `runtime_health_adapters.json` 中的 adapter id
- `footprint_check` 和 `target_policy_check` 指向可执行脚本
- `write_policy` 不得为 `not-enabled`
- `required_evidence` 至少覆盖 dry-run、rollback、runtime health、runtime live footprint

### 3.2 Health Adapter

在 `manifests/runtime_health_adapters.json` 中启用对应 adapter：

- `enabled=true`
- `status=active`
- `runtime` 与 target runtime 一致
- `script` 指向只读健康检查脚本
- `target_ids` 包含该 target id
- `profiles` 至少包含 `minimal`、`security`、`strict`
- `read_only=true`

### 3.3 Evidence

启用前必须有可审查证据：

- source repo 存在并可构建
- apply plan 或等价 dry-run
- rollback 方式和回滚证据
- runtime health 检查通过
- live footprint 或 target policy 检查通过
- 若涉及 `~/.codex`，仍需 `~/codex` build/doctor/apply 链路证据

### 3.4 Registry / Lock 边界

- `subrepos/registry.csv` 必须有对应 runtime target 策略记录。
- 当前 `codex` registry 行必须保持 `group=runtime-target`、`enabled=no`、`status=disabled`、`intake_policy=pilot-first`，notes 提到 `~/codex` 和 `~/.codex`。
- Codex 默认 target 必须匹配 `adk.lock` 的 `codex.source` 与 `codex.target`。
- 不得创建 workspace-local `codex/` 目录替代 `~/codex`。

## 4. Explain Target

先运行：

```bash
rtk scripts/check-runtime-targets.sh . --explain-target claude-code-home
```

输出字段用于排查：

- `target_id`
- `enabled`、`role`
- `source_repo`、`live_root`、`source_to_live_chain`
- `health_adapter`
- `adapter_declared`、`adapter_enabled`、`adapter_status`、`adapter_read_only`
- `adapter_script`、`adapter_runtime`、`adapter_bound`
- `evidence_status`
- `activation_ready`
- `next_action`

`--explain-target` 是只读诊断入口；target 不存在时返回 exit 1，target 存在时返回 exit 0。它不替代正式门禁。

## 5. Required Gates

```bash
rtk scripts/check-runtime-targets.sh . --summary-json
rtk scripts/check-runtime-health.sh . --target <target-id> --profile minimal --summary-json
rtk scripts/check-runtime-health-adapters-fixtures.sh .
rtk scripts/check-workspace-entrypoints.sh .
rtk scripts/check-all.sh --quick
```

涉及生产可用性或 live refresh 结论前，额外执行 source-to-live 证据链：

```bash
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
```

真正 apply 或 rollback 需要人工授权，并在 `reports/` 留记录。回滚后必须重新运行 runtime health 和 footprint 检查。

## 6. 不允许的捷径

- 不允许只把 target 改成 `enabled=true`。
- 不允许在 `runtime_targets.json` 中重新加入 `health_check`。
- 不允许 adapter 指向写入型脚本。
- 不允许 adapter `target_ids` 指向 disabled target。
- 不允许用参考子仓 dirty 状态作为 runtime target 证据。
- 不允许 dry-run 出现覆盖或删除而没有解释来源、影响和回滚方式。
