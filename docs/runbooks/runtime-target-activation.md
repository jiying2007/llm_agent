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
`--explain-target` 输出单个 JSON object，不与 `--summary-json` 组合使用。

## 5. Evidence Index 模板

启用 runtime target 前，在 `reports/runtime-target-activation/<target-id>/` 中记录最小 Evidence Index。建议把主索引命名为 `evidence-index.md`，命令输出按 gate 分别保存为 `explain-target.json`、`runtime-health.json`、`apply-dry-run.md`、`footprint-policy.json`、`rollback.md` 等稳定文件，避免证据散落。可用下列入口生成草稿并校验 schema：

```bash
rtk scripts/collect-runtime-target-evidence-package.sh . --target <target-id> --summary-json
rtk scripts/generate-runtime-target-evidence-index.sh . --target <target-id> --out reports/runtime-target-activation/<target-id>/evidence-index.md
rtk scripts/check-runtime-target-evidence-index.sh . --target <target-id>
rtk scripts/check-runtime-target-evidence-index.sh . --target <target-id> --require-index --strict-artifacts --summary-json
```

Evidence Index 只记录真实执行或明确计划的证据，不得只复制 `required_evidence` 关键词来满足门禁。`check-runtime-targets.sh` 是声明校验，只能证明 manifest 中声明了对应证据类别，不能证明 artifact/report 已存在。
`collect-runtime-target-evidence-package.sh` 是 report-only 采集器，只运行 `explain-target`、runtime target summary、adapter fixture、runtime health 和 footprint 等只读门禁；source-to-live plan、dry-run、rollback 和 apply 行只记录为 `blocked` / `planned`，不会执行真实 apply、rollback 或 live root 写入。

字段约束：

- `Evidence ID`: 使用 `TARGET-GATE-SEQ`，例如 `CLAUDE-CODE-HOME-DRYRUN-001`。
- `Gate`: 固定为 `declare`、`dry-run`、`health`、`footprint`、`apply`、`rollback`、`activation` 之一。
- `Exit Code`: 真实执行命令后必须记录；`planned` / `blocked` 行可为 `-` 或 `null`。
- `Result Summary`: 只写实际结果；不得把 `Expected Result` 或 `required_evidence` 复制成结果。
- `Write Scope`: 固定为 `read-only`、`source-repo-only`、`workspace-local`、`live-root`、`rollback-live-root` 之一。
- `Approval Required`: 纯只读命令和 `--dry-run` 可为 `no`；任何会修改目标 `live_root`、`~/.codex` 或执行等价恢复/回滚动作的命令必须为 `yes`，并记录审批人、审批时间和审批范围。
- `Approval Status`: 固定为 `not-required`、`required`、`approved`、`denied`、`expired` 之一。
- `approved_by`、`approved_at`、`approval_scope`: `approval_required=yes` 且执行状态进入 `passed` / `approved` 时必须非空。
- `Status`: 固定为 `planned`、`passed`、`failed`、`blocked`、`approved` 之一。
- `artifact_exists` / `artifact_sha256`: JSONL 证据中保留这两个字段；`--strict-artifacts` 下 `passed` / `failed` / `approved` 行必须有真实 artifact，`passed` / `approved` 行必须有匹配的 64 位 sha256 hash。
- `--index`: 校验一个已落盘 `evidence-index.jsonl` 或配套 Markdown 索引；严格门禁以 JSONL 为真源。
- `--require-index`: 要求每个选中 target 都存在 `reports/runtime-target-activation/<target-id>/evidence-index.jsonl`。
- `--strict-artifacts`: 只读校验 artifact 存在性、hash、exit code、审批身份和路径边界；它必须与 `--index` 或 `--require-index` 组合使用，不执行 evidence command。
- Evidence package: canonical `evidence-index.jsonl` 可以位于 `reports/runtime-target-activation/<target-id>/evidence-index.jsonl`；带时间戳的采集包可放在 `reports/runtime-target-activation/<target-id>/<timestamp>/`，其 artifact 仍必须保持在同一 target evidence 目录树下。

可直接复制下表：

| Evidence ID | Target ID | Gate | Command | Exit Code | Expected Result | Result Summary | Write Scope | Artifact / Report | Layer | Related Artifact | Approval Required | Approval Status | Status |
|---|---|---|---|---:|---|---|---|---|---|---|---|---|---|
| `<TARGET>-DECL-001` | `<target-id>` | declare | `rtk scripts/check-runtime-targets.sh . --explain-target <target-id>` | `0` | `activation_ready=true` or clear `next_action` | explain-target result | read-only | `reports/runtime-target-activation/<target-id>/explain-target.json` | RuntimeTarget | - | no | not-required | planned |
| `<TARGET>-TARGETS-001` | `<target-id>` | declare | `rtk scripts/check-runtime-targets.sh . --summary-json` | `-` | `status=pass` | not executed yet | read-only | `reports/runtime-target-activation/<target-id>/runtime-targets.json` | RuntimeTarget | - | no | not-required | planned |
| `<TARGET>-ADAPTERS-001` | `<target-id>` | health | `rtk scripts/check-runtime-health-adapters-fixtures.sh .` | `-` | fixture pass | not executed yet | workspace-local | `reports/runtime-target-activation/<target-id>/adapter-fixtures.md` | RuntimeTarget | adapter contract | no | not-required | planned |
| `<TARGET>-HEALTH-001` | `<target-id>` | health | `rtk scripts/check-runtime-health.sh . --target <target-id> --profile minimal --summary-json` | `-` | `status=pass` | not executed yet | read-only | `reports/runtime-target-activation/<target-id>/runtime-health.json` | RuntimeTarget | runtime health | no | not-required | planned |
| `<TARGET>-FOOTPRINT-001` | `<target-id>` | footprint | `<target footprint command>` | `-` | no missing required assets | not executed yet | read-only | `reports/runtime-target-activation/<target-id>/footprint-policy.json` | RuntimeTarget | footprint policy | no | not-required | planned |
| `<TARGET>-PLAN-001` | `<target-id>` | dry-run | `<source repo plan command>` | `-` | plan generated and reviewed | not executed yet | source-repo-only | `reports/runtime-target-activation/<target-id>/apply-plan.md` | RuntimeTarget | source-to-live plan | no | not-required | planned |
| `<TARGET>-DRYRUN-001` | `<target-id>` | dry-run | `<source repo apply dry-run>` | `-` | no unexplained overwrite/delete | not executed yet | source-repo-only | `reports/runtime-target-activation/<target-id>/apply-dry-run.md` | RuntimeTarget | source-to-live dry-run | no | not-required | planned |
| `<TARGET>-ROLLBACK-001` | `<target-id>` | rollback | `<rollback dry-run or documented procedure>` | `-` | rollback path reviewed | not executed yet | read-only or rollback-live-root | `reports/runtime-target-activation/<target-id>/rollback.md` | RuntimeTarget | rollback plan | yes | required | planned |
| `<TARGET>-APPLY-001` | `<target-id>` | apply | `<source repo apply command>` | `-` | live root updated as approved | blocked until approval | live-root | `reports/runtime-target-activation/<target-id>/apply-report.md` | RuntimeTarget | apply report | yes | required | blocked |

`<TARGET>-APPLY-001` 和真实 `<TARGET>-ROLLBACK-001` 默认不执行；只有用户明确授权写 live root 时才执行。
`required_evidence is not artifact evidence`：manifest 中的 `required_evidence` 只表示声明类别，不能替代 `evidence-index.jsonl`、命令 exit code、artifact path、hash 或审批记录。

## 6. Required Gates

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

## 7. 不允许的捷径

- 不允许只把 target 改成 `enabled=true`。
- 不允许在 `runtime_targets.json` 中重新加入 `health_check`。
- 不允许 adapter 指向写入型脚本。
- 不允许 adapter `target_ids` 指向 disabled target。
- 不允许用参考子仓 dirty 状态作为 runtime target 证据。
- 不允许 dry-run 出现覆盖或删除而没有解释来源、影响和回滚方式。
