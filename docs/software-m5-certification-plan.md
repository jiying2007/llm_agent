# 软件侧 M5 认证计划

本计划只覆盖 `llm_agent` 与 `agent-dev-kit` 的软件产品边界。`M5-ready` 表示认证、证据和回退控制面已经可执行，不等同于 `M5 certified`。真实运行证据不足时，认证器必须返回 blocked。

## 目标状态

- RC 版本：`agent-dev-kit 3.1.0-rc.2`。
- 最终版本：`agent-dev-kit 3.1.0`，只在现场 eligibility 通过后提升。
- 机器策略：`manifests/software_m5_policy.json`。
- 试点账本：`manifests/software_m5_pilot_ledger.json`。
- append-only 事件链：`reports/field-evidence/software-m5-events.jsonl`。
- 认证入口：`scripts/software-m5.sh`。
- 阻断门禁：`scripts/check-software-m5-readiness.sh`。

## 阶段与验收

| 阶段 | 状态 | 退出条件 | 主要证据 |
|---|---|---|---|
| P0 软件控制面 | implemented | doctor、writer lock、campaign resume、证据 hash、release rehearsal 均有负向测试 | ADK 3.1 change artifact |
| P1 M5-ready RC | implemented | 3.0.0 升级到 RC 后可回退；双构建一致；隔离 wheel 安装通过；自试点已真实启动 | `release-rehearsal.json`、事件链 |
| P2 双 runtime campaign | blocked_external | Codex/Claude 各 60 任务、baseline/adk、3 trials；720 条 raw result 与 frozen plan 完整保留；所有统计门禁通过；总预算不超过 `$150` | `software-m5-campaign-state/` |
| P3 独立现场试点 | active | 至少一个独立真实软件仓、至少两个 human operator、账本和观测跨度均不少于 30 天 | field 事件链和逐事件证据 |
| P4 eligibility | blocked | P2/P3 全部通过，故障、恢复、升级、回退、维护成本和复审事件完整 | `software-m5.sh certify` 的非版本 blocker 清零 |
| P5 最终发布 | blocked | 只做必要的 RC 到 `3.1.0` 提升，重建制品并复跑完整门禁；认证器返回 pass | final release 与 M5 status evidence |

## 双运行时执行

预算合同把 Claude primary 调用固定为 360 次，含一次重试的最坏调用数为 720 次；单次上限 `$0.20`，最坏预算 `$144`。未认证、模型或 CLI 版本漂移、结果缺失、usage/cost 缺失、P95 或 token 回退超阈值都会 fail closed。

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval campaign plan \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc2.json \
  --output agent-dev-kit/docs/changes/adk-v3-1-software-m5-ready/software-m5-campaign-plan.json

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign run \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc2.json \
  --state-dir agent-dev-kit/docs/changes/adk-v3-1-software-m5-ready/software-m5-campaign-state \
  --approve-budget-usd 150 --execute --resume

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign check \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_rc2.json \
  --state-dir agent-dev-kit/docs/changes/adk-v3-1-software-m5-ready/software-m5-campaign-state \
  --certify --summary-json
```

`state-dir` 保存 frozen plan、逐任务原始结果和 campaign report，必须进入受 Git 管理的证据目录。根仓 certifier 会重算 manifest/contract/tasks/plan/record/report 哈希并校验 720 项矩阵；只有汇总 report、没有 raw result 的结果固定阻断。

## 现场事件规则

- 事件只能通过显式 `software-m5.sh append` 追加；工具使用单 writer lock、连续 sequence、`previous_hash` 和 `event_hash`。
- 每个 evidence path 在事件中绑定文件 SHA256；证据文件后续发生内容漂移会破坏完整性，应新增 dated evidence 文件和新事件，不得原地覆盖。
- operator 只使用匿名稳定 ID，不记录姓名、邮箱、token 或 prompt 内容。
- fixture、模拟 runtime、本地发布 rehearsal 可以进入 source/test/runtime 层，但不能满足 field gate。
- 最终有效事件必须来自完成的 independent pilot，并覆盖 workload、upgrade、rollback、fault、recovery、maintenance 和 review。
- independent repository 必须是独立 Git top-level，且不能与 `llm_agent` 共享 Git common-dir；同仓 worktree 或普通子目录不计入独立仓。
- required metric 不只检查存在性，还检查类型、范围、版本绑定和 review decision；低于 success threshold 或 `decision!=approve` 均不放行。
- `pilot_reviewed` 必须由 ledger 中标记为 independent reviewer 的 human operator 亲自记录；仅让 reviewer 参与其他事件不能放行。
- pilot 的 ledger 日期跨度与真实事件观测跨度都必须达到 30 天；只回填日期不能放行。
- policy 的关键 rule、事件集合和 metric contract 是不可弱化基线；删除规则或放宽阈值会触发 integrity failure。

```bash
rtk scripts/software-m5.sh append \
  --event-id <stable-id> --pilot-id <pilot-id> \
  --occurred-at <UTC-time> --event-type <type> --evidence-layer field \
  --repository-id <repo-id> --operator-id <operator-id> \
  --summary <sanitized-summary> --evidence <repo-relative-path> \
  --metric key=value
```

## 认证与停止条件

```bash
rtk scripts/software-m5.sh status --summary-json
rtk scripts/check-software-m5-readiness.sh . --summary-json
rtk scripts/software-m5.sh certify --summary-json
```

- `status` 在证据结构完整时允许返回 `M5-ready + blocked`。
- `check` 校验 policy、ledger、事件链、scorecard 声明和当前边界；未认证本身不是 RC 门禁失败，状态漂移才是失败。
- `certify` 只有最终 M5 证据全部成立才返回 0。
- 出现 event/evidence hash 破坏、campaign raw evidence 缺失、预算越界、未来时间、证据路径越界、独立仓身份不成立或声明漂移时立即停止，不允许人工改成 pass。
