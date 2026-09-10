# 软件侧 M5 认证计划

本计划只覆盖 `llm_agent` 与 `agent-dev-kit` 的软件产品边界。`M5-ready` 表示认证、证据和回退控制面已经可执行，不等同于 `M5 certified`。真实运行证据不足时，认证器必须返回 blocked。

## 目标状态

- 版本与制品身份：以 `manifests/software_m5_policy.json:release` 为准，本文不复制可漂移的版本/commit/hash。
- 最终版本：只在现场 eligibility 通过后按同一 policy 的 `final_version` 提升。
- 机器策略：`manifests/software_m5_policy.json`。
- 试点账本：`manifests/software_m5_pilot_ledger.json`。
- append-only 事件链：`reports/field-evidence/software-m5-events.jsonl`。
- 认证入口：`scripts/software-m5.sh`。
- 阻断门禁：`scripts/check-software-m5-readiness.sh`。

## 阶段与验收

| 阶段 | 状态 | 退出条件 | 主要证据 |
|---|---|---|---|
| P0 软件控制面 | implemented / 当前验证另查 | doctor、writer lock、campaign resume、证据 hash、release rehearsal 均有负向测试 | 当前 change artifact 与 fresh validation |
| P1 M5-ready RC | evidence-pending | policy 指定 previous/candidate 制品连续性和回退；exact-commit 双构建一致；Codex source-to-live 零漂移 | policy 指定 rehearsal、source-to-live evidence、事件链 |
| P2 双 runtime campaign | blocked_external | Codex/Claude 各 60 任务、baseline/adk、3 trials；720 条 raw result 与 frozen plan 完整保留；所有统计门禁通过；总预算不超过 `$150` | `software-m5-campaign-state/` |
| P2.5 真实仓库 campaign | blocked_external | 至少两个 runtime、5 个冻结任务、至少 2 个 owner-approved 真实仓库任务、baseline/adk 各 3 trials；功能/安全/过程/trace/token/cost 门禁全部通过 | `repository_runtime_eval_contract.json` 与 owner-approved report |
| P3 独立现场试点 | active | 至少一个独立真实软件仓、至少两个 human operator、账本和观测跨度均不少于 30 天 | field 事件链和逐事件证据 |
| P4 eligibility | blocked | P2/P3 全部通过，故障、恢复、升级、回退、维护成本和复审事件完整 | `software-m5.sh certify` 的非版本 blocker 清零 |
| P5 最终发布 | blocked | 只做必要的 RC 到 policy `final_version` 提升，重建制品并复跑完整门禁；认证器返回 pass | final release 与 M5 status evidence |

2026-09-05 复核：旧 3.1 RC rehearsal 不能证明当前 v5 release continuity。当前状态必须由 policy、候选身份和新鲜门禁共同判定；根仓 dirty、官方 previous artifact 缺失、第二操作者和现场周期未闭环时继续保留 blocked。小规模试点入口见 [团队试点](runbooks/team-pilot-acceptance.md)。

## 双运行时执行

预算合同把 Claude primary 调用固定为 360 次，含一次重试的最坏调用数为 720 次；单次上限 `$0.20`，最坏预算 `$144`。未认证、模型或 CLI 版本漂移、结果缺失、usage/cost 缺失、P95 或 token 回退超阈值都会 fail closed。

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval campaign plan \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_v5.json \
  --output /tmp/software-m5-campaign-plan.json

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign run \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_v5.json \
  --state-dir agent-dev-kit/docs/changes/adk-platform-convergence-v1/software-m5-campaign-state \
  --approve-budget-usd 150 --execute --resume

rtk bash agent-dev-kit/scripts/devkit.sh eval campaign check \
  --contract agent-dev-kit/manifests/software_m5_eval_contract_v5.json \
  --state-dir agent-dev-kit/docs/changes/adk-platform-convergence-v1/software-m5-campaign-state \
  --certify --summary-json
```

上述路径在 2026-09-05 与 policy 的 `runtime_campaign.contract/state_dir` 对齐；执行前重新读取 policy，漂移则先更新计划。第一条命令仅在 `/tmp` 生成可审查计划，不登记为正式 campaign。`run --execute` 涉及付费/外部执行，必须已有显式预算与执行授权。

`state-dir` 保存 frozen plan、逐任务结构化结果和 campaign report，必须进入受 Git 管理的证据目录。这里的 raw result 指合同允许的逐任务结构化观测，不是聊天正文、工具 payload 或原始日志。根仓 certifier 会重算 manifest/contract/tasks/plan/record/report 哈希并校验 720 项矩阵；只有汇总 report、没有逐任务结果的结果固定阻断。

## 真实仓库执行证据

现有双 runtime campaign 继续验证 Skill 路由与安全分类；真实仓库修改由独立 contract 管理，避免把 route accuracy 当作工程 outcome。默认命令只生成 plan：

```bash
rtk bash agent-dev-kit/scripts/devkit.sh eval repository plan \
  --contract agent-dev-kit/manifests/repository_runtime_eval_contract.json \
  --summary-json

rtk bash agent-dev-kit/scripts/devkit.sh eval repository certify \
  --contract agent-dev-kit/manifests/repository_runtime_eval_contract.json \
  --report <owner-approved-repository-report.json> \
  --summary-json
```

- baseline 必须证明项目指令、Skills、Hooks、MCP 和 plugins 已隔离；不能证明时为 `not-comparable`。
- ADK condition 只启用受审 profile；其余 customization surface 保持关闭。
- 功能测试失败时安全 oracle 标记 skipped；功能通过后安全 oracle 必须通过。
- 最终测试通过但存在 blind retry、regression cycle、阶段乱序或遗漏最终验证时，按 `pass_with_invalid_process` 阻断。
- 结果记录 input/output/cached token、p50/p95/max、variation、cost-per-success、attempt、tool call 和 timeout。
- clean-room fixture 只验证 contract。Software M5 另要求至少两个 `approved-real-repository` task，且外部容器、凭证、网络和预算必须单独批准。

## 现场事件规则

- 事件只能通过显式 `software-m5.sh append` 追加；工具使用单 writer lock、连续 sequence、`previous_hash` 和 `event_hash`。
- 每个 evidence path 在事件中绑定文件 SHA256；证据文件后续发生内容漂移会破坏完整性，应新增 dated evidence 文件和新事件，不得原地覆盖。
- operator 只使用匿名稳定 ID，不记录姓名、邮箱、token 或 prompt 内容。
- fixture、模拟 runtime、本地发布 rehearsal 可以进入 source/test/runtime 层，但不能满足 field gate。
- 最终有效事件必须来自完成的 independent pilot，并覆盖 workload、upgrade、rollback、fault、recovery、maintenance 和 review。
- qualifying pilot 必须先记录 task preregistration/disposition 与 human baseline；accepted + rejected 必须等于 preregistered，workload 必须与选择记录一致。
- workload 必须分离 wall-clock、human-active、agent-active time，并记录 concurrent-agent peak；人工活跃时间不得超过 wall-clock，Agent 总时间不得超过并发归一化上限。
- 独立 reviewer 的 review event 必须明确 selection bias、time measurement 和 confidence interval 已评估，不能用自报“完成”代替。
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
- `repository_runtime_campaign` 与原 `runtime_campaign` 是两个独立 blocker；任一缺失都不能进入 eligibility。
- 出现 event/evidence hash 破坏、campaign raw evidence 缺失、预算越界、未来时间、证据路径越界、独立仓身份不成立或声明漂移时立即停止，不允许人工改成 pass。
