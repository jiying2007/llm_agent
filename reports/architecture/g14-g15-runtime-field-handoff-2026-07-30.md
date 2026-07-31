# G14/G15 Runtime、Field 与多维护者证据执行包

## 结论

截至 2026-07-30，软件控制面 integrity 为 `pass`、readiness 为 `m5-ready`，但 eligibility/certification 仍为 `blocked`。本执行包把 G14/G15 推进到本地可交接边界，不把配置、fixture、自试点或 AI 自报替代真实 runtime、独立仓、第二位 human operator 和 30 天证据。

## 当前事实

| 事实 | 状态 | 证据 |
|---|---|---|
| Python 3.11/3.12 release-grade parity | pass | 两环境各 57/57，dependency audit 无已知漏洞 |
| Direct target static contracts | pass | Claude Code、Hermes Agent、OpenCode static check |
| ADK repository ownership/freshness metadata | pass | `agent-dev-kit/OWNERS`、`.adk/harness-readiness.json` |
| 自试点 | active | `software-m5-self-pilot-20260713` |
| 独立真实仓 | missing | `independent_repository` blocker |
| 第二 human operator / independent reviewer | missing | `operator_count` blocker |
| 双 runtime campaign | missing | `runtime_campaign` blocker |
| 真实仓 runtime campaign | missing | `repository_runtime_campaign` blocker |
| 30 天独立试点 | missing | `pilot_duration` blocker |
| 10 类现场事件 | missing | `required_field_events` blocker |

当前 blocker 固定为：

`final_version`、`independent_repository`、`operator_count`、`pilot_duration`、`real_repository_count`、`repository_runtime_campaign`、`required_field_events`、`runtime_campaign`。

## 权限与成本边界

- transport：Codex/Claude runtime CLI，仅在 owner 明确批准认证、模型、预算和证据目录后执行。
- credentials：只从 runtime 自身受管环境读取；禁止写入报告、事件链、manifest 或命令参数。
- budget：双 runtime campaign 与 repository campaign 各自最多 `$150`；没有精确 owner approval 不执行 `--execute`。
- deny-path：不访问独立仓未授权路径、用户凭证目录、浏览器状态、SSH 私钥或其他项目数据。
- external writes：不自动 publish、comment、commit、push、merge、release 或修改远端仓库。
- fallback：无认证、模型漂移、预算缺失、runtime/version 不匹配或证据目录不安全时保持 `not-run/blocked`。

## 执行顺序

### 1. 指定独立角色与仓库

在任何现场事件前，由用户/owner 明确提供：

- 一个与 `llm_agent` 不共享 Git common-dir 的真实软件仓；
- 匿名稳定 operator ID；
- 至少一名第二 human operator，其中独立 reviewer 必须亲自写入最终 `pilot_reviewed`；
- 任务 preregistration、拒绝日志、人工 baseline 和证据保留位置。

未知人选不得写成 CODEOWNERS、ledger operator 或已批准 reviewer。

### 2. 只读 preflight

```bash
rtk bash agent-dev-kit/scripts/devkit.sh doctor --summary-json
rtk bash agent-dev-kit/scripts/devkit.sh target check --all --level static --summary-json
rtk bash agent-dev-kit/scripts/devkit.sh eval repository plan \
  --contract agent-dev-kit/manifests/repository_runtime_eval_contract.json \
  --summary-json
rtk scripts/software-m5.sh status --summary-json
rtk scripts/check-software-m5-readiness.sh . --summary-json
```

任何 contract、runtime、model、source、hash、workspace 或 budget 漂移都先停止，不进入付费执行。

### 3. 双 runtime campaign

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval campaign plan \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc5.json \
  --output agent-dev-kit/docs/changes/archive/20260719-intent-boundary-governance-v2/software-m5-campaign-state/campaign-plan.json

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign run \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc5.json \
  --state-dir agent-dev-kit/docs/changes/archive/20260719-intent-boundary-governance-v2/software-m5-campaign-state \
  --approve-budget-usd 150 --execute --resume

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign check \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc5.json \
  --state-dir agent-dev-kit/docs/changes/archive/20260719-intent-boundary-governance-v2/software-m5-campaign-state \
  --certify --summary-json
```

执行前必须复核 frozen contract 中的模型仍可用且符合 owner 的比较目的。官方“最新模型”变化不自动改写 RC frozen baseline。

### 4. 真实仓 runtime campaign

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval repository certify \
  --contract agent-dev-kit/manifests/repository_runtime_eval_contract.json \
  --report <owner-approved-repository-report.json> \
  --summary-json
```

至少 5 个冻结任务、2 个 owner-approved 真实仓任务、两个 runtime、baseline/adk 各 3 trials。功能失败时安全 oracle 为 skipped；功能通过后安全 oracle 必须通过。

### 5. 30 天现场事件链

只用以下入口追加，不回填、不覆盖旧 evidence：

```bash
rtk scripts/software-m5.sh append \
  --event-id <stable-id> --pilot-id <pilot-id> \
  --occurred-at <UTC-time> --event-type <type> --evidence-layer field \
  --repository-id <repo-id> --operator-id <operator-id> \
  --summary <sanitized-summary> --evidence <repo-relative-path> \
  --metric key=value
```

必须依次覆盖 `pilot_started`、`task_selection_recorded`、`human_baseline_recorded`、`workload_executed`、`upgrade_completed`、`rollback_exercised`、`fault_observed`、`recovery_completed`、`maintenance_recorded`、`pilot_reviewed`。ledger 日期跨度与真实事件跨度都必须达到 30 天。

### 6. 认证

```bash
rtk scripts/software-m5.sh status --summary-json
rtk scripts/check-software-m5-readiness.sh . --summary-json
rtk scripts/software-m5.sh certify --summary-json
```

只有八个 blocker 全部清零后才能讨论 final `3.1.0`；不得先改版本再倒推 evidence。

## 停止条件

出现以下任一情况立即停止并保持 blocked：

- runtime 未认证、版本或模型不符合 frozen contract；
- owner 未明确批准成本、独立仓或写操作；
- raw result、usage/cost、trace、hash 或 evidence path 缺失；
- 预算越界、未来时间、事件链断裂、同仓 worktree 冒充独立仓；
- 第二操作者未真实参与，或 reviewer 没有亲自记录 `pilot_reviewed`；
- fixture、自试点、静态 target check 被误当作 field evidence。

## 当前 handoff

- owner action：指定独立仓、第二 human operator/independent reviewer，并决定是否授权两项各 `$150` 上限的 runtime campaign。
- earliest completion：从合格独立 `pilot_started` 的真实时间起至少 30 个日历日。
- 当前可声明：`M5-ready / eligibility blocked / certification blocked`。
- 当前不可声明：runtime effective、field verified、multi-maintainer proven、M5 certified、final release ready。
