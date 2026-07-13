# llm_agent / agent-dev-kit 软件侧 M5 readiness 审计

- 日期: 2026-07-13
- 范围: 软件产品目标、架构、功能、效果、性能、可靠性、安全、发布、体验、维护与长期现场资产
- 当前版本: `agent-dev-kit 3.1.0-rc.1`
- 最终版本: `3.1.0`，只允许在现场 eligibility 通过后提升
- 机器状态: `manifests/product_maturity_scorecard.json`
- M5 策略: `manifests/software_m5_policy.json`
- 试点账本: `manifests/software_m5_pilot_ledger.json`

## 执行结论

本轮已经把软件侧升级到 **M5-ready control plane**，但没有把产品伪报为 M5：

- 总体成熟度仍为 `M3 / release-candidate`，因为 D04 双 runtime 效果证据仍被 Claude 未认证阻断。
- 软件 M5 readiness 为 `m5-ready`；认证状态为 `blocked`；`terminal_mature=false`。
- 一个真实 self pilot 已在 2026-07-13 启动，状态为 `self_pilot_active`；self evidence 不计作 independent field certification。
- 最终 M5 还缺双 runtime campaign、第二个有 field 事件的真实软件仓、至少一个 independent repo、第二位 human operator、30 天账本与观测跨度、完整现场事件，以及最后的 `3.1.0` 提升。

因此当前可发布的是供试点使用的 RC 和认证控制面，不是“所有软件场景终态成熟”。

## 目标与非目标

### 目标

1. `agent-dev-kit` 作为平台中立的 Agent 资产 compiler/control plane，在并发、失败、升级和评测场景下可验证、可恢复。
2. `llm_agent` 作为 evidence-first intake 与产品成熟度控制面，能够保存真实现场证据并防止状态漂移。
3. 软件 M5 必须由真实 runtime 和真实独立项目长期运行证明，而不是由目录数量、mock、固定 prompt 或人工改状态证明。

### 非目标

- 不实现 LLM 推理 loop、session scheduler、模型网关或生产 Agent runtime。
- 不把嵌入式硬件现场要求强塞给纯软件 M5；软件试点必须来自真实软件仓与真实操作者。
- 不自动认证 Claude、不自动消费模型预算、不自动发布 final、不自动写外部仓。
- 不把 self pilot、本地 release rehearsal 或 synthetic positive fixture 计入 independent field gate。

## 架构落地

```text
ADK manifest + 60-task contract
  -> doctor / model+CLI readiness / budget plan
  -> resumable dual-runtime campaign
  -> per-result hash + plan/contract/task binding
  -> confidence/resource/cost gates
  -> standalone campaign report hash

ADK export/install/release
  -> same-target writer lock
  -> transactional plan/apply/rollback
  -> safe release extraction
  -> 3.0.0 -> RC -> rollback rehearsal

llm_agent M5 control plane
  -> policy SSOT
  -> anonymized pilot ledger
  -> append-only hash-chain events
  -> M5-ready / eligible-for-final / certified state machine
  -> scorecard declaration consistency gate
```

### ADK 软件能力

- `locking.py` 对 export/apply/rollback 和 campaign state 建立单 writer 契约；锁 owner 有明确 metadata，未知 lock 不自动清除。
- `matcher.py` 用结构化 YAML 读取和 frontmatter cache 替代逐次 Bash 子进程，60 条 deterministic 集达到 60/60，并将本机 P95 降到毫秒级预算内。
- `doctor.py` 检查 manifest、Python、PyYAML、runtime、认证状态、target 可写性和 lock，但不输出环境变量或凭证值。
- `campaign.py` 固化 runtime/model/CLI、60 tasks、baseline/adk、3 trials、一次 retry、`$150` 总预算，逐任务原子落盘并支持可信 resume。
- campaign report 绑定 manifest、contract、tasks、runtime provenance、结果摘要、成本、gates、evidence hash 和 report hash。
- `release.py` 对 archive 路径、类型、重复成员、成员数、单文件/总大小做 fail-closed 校验，并兼容历史平铺包与单根目录包。
- release rehearsal 已真实执行 `3.0.0 -> 3.1.0-rc.1 -> rollback`，31 项 managed assets 全部恢复。

### 根仓软件能力

- `software_m5_policy.json` 固定双 runtime、模型、预算、30 天、独立仓、两位 human operator、必需事件和 metrics。
- `software_m5_pilot_ledger.json` 只保存匿名 operator ID、repo 分类、pilot 窗口和关系，不保存姓名、邮箱或 prompt。
- `software-m5-events.jsonl` 使用连续 sequence、`previous_hash`、`event_hash`、evidence file SHA256 和单 writer file lock；任何历史行或证据内容修改都会阻断。
- `tools.codex_assets.software_m5` 同时验证路径 containment、时间顺序、独立 Git common-dir、metric 类型/范围、720 条 campaign raw result、release rollback 和 scorecard 声明。
- raw campaign 复核覆盖固定路径矩阵、attempt 顺序、runtime/model、usage、latency、逐调用 cost、final 派生关系与汇总成本，不能只凭自封口的 passing report 放行。
- independent review 只有在 reviewer-authored `pilot_reviewed` 事件存在时成立；policy rule、事件集合和 metric contract 不能通过删字段或放宽阈值降级。
- synthetic positive fixture 证明条件齐全时 certifier 确实可达到 M5；live fixture 证明当前必须 blocked。

## 功能与效果

| 能力 | 当前状态 | 证据边界 |
|---|---|---|
| Deterministic routing | pass，60/60 | 证明 matcher 对冻结任务成立，不代表开放世界效果 |
| Codex runtime smoke | pass，显式 `gpt-5.5` | 证明当前 CLI 的单任务只读路由成立，不替代完整 campaign |
| Claude runtime | blocked | CLI `2.1.138` 已安装但未认证，未产生模型调用或费用 |
| Dual-runtime campaign | planned/blocked | 360 次 primary Claude calls，含 retry 最坏 720 次，最坏 `$144` |
| Writer concurrency | pass | 4 process/40 increments 与同 target 双 apply 竞争均有回归 |
| Release upgrade/rollback | pass | 3.0.0 安装、RC 升级、31 项回退恢复 |
| Field pilot | active/self only | 真实启动事件存在，但 independent repo 和 30 天证据为 0 |

旧版 Codex 30 任务 A/B 的 success/route 从 `0.90` 到 `1.00`，safety 保持 `1.00`，仍作为历史 runtime evidence。新的 60 任务 campaign 增加模糊、多意图、安全和资源门禁，但尚未执行完整双 runtime，因此不外推新的效果结论。

## 性能与成本

- deterministic 60 条路由通过且 matcher P95 低于 20ms 合同预算；本轮定向实测处于亚毫秒级。
- Codex 两次单任务真实 smoke 分别约 13.5 秒和 43.4 秒，波动显著；它们只证明功能路径，不支持 latency 改善结论，也不属于平台 matcher latency。
- Claude 单次硬上限 `$0.20`；primary 最坏 `$72`，含每任务一次 retry 的最坏预算 `$144`，低于 owner 给出的 `$150` 上限。
- campaign 对每个 trial 分别计算 latency P95 ratio 和 token usage ratio；缺 usage、cost 或 latency 证据会失败。
- 不声称尾延迟已经全面改善；旧 30 任务证据仍保留 candidate P95 回退事实。

## 可靠性、安全与供应链

- same-target writer 不再依赖操作约定；lock 竞争、错误 lock ID、进程并发和 stale install plan 均有负向覆盖。
- campaign plan/result/report 分层 hash，resume 拒绝 runtime version/model、manifest、contract、task 或结果内容漂移。
- 持久化 campaign plan 只保存 executable name，不保存本机绝对路径。
- field event evidence 必须是仓库相对 regular file 并绑定内容 SHA256；路径越界、symlink、未来时间、跨 pilot repo/operator 引用、PII 字段和 hash 篡改均阻断。
- final campaign 不能只提交汇总报告；frozen plan、60-task SSOT 和 720 条 raw result 必须同时存在并与 report evidence hash 一致。
- release 解包拒绝 traversal、symlink、hardlink、device、重复成员和压缩炸弹边界。
- wheel 在独立 venv 安装，依赖解析与 `pip check` 通过；错误的旧 setuptools 构建结果 `UNKNOWN-0.0.0` 没有被接受为证据。

## 发布、兼容与回退

- RC source archive 两次构建 SHA256 一致：`b6adcb98d5fc3be9138754a114122a1d1d92aa72a577b2a8200850558114324f`。
- wheel SHA256：`a03ce13931277db2d95cba81d279035122f899eed04fa36f643473295609fcf6`。
- 3.0.0 历史制品 SHA256：`1f5c125b0ee4712d66e57fbd480968956062678ee6a738ac1077726dcf556e1f`。
- release rehearsal 把历史平铺 archive 作为兼容输入；新安全解包器也支持显式单根目录布局。
- 未创建 tag、GitHub Release 或远端制品；final `3.1.0` 在 eligibility 前被 `final_version` gate 明确阻断。
- 本轮没有 mapped Agent/Skill/Profile 内容变更，不执行无意义的 `~/codex -> ~/.codex` apply。

## 可维护性与长期资产

1. M5 定义从报告文字提升为 policy SSOT，scorecard 只声明由 certifier 可重算的状态。
2. 现场证据从可覆盖 JSON 改为 append-only JSONL hash chain；事件绑定 evidence SHA256，摘要限长且禁止 operator PII。
3. campaign task、model、trial、预算和阈值全部进入 manifest contract，避免运行时临时改口径。
4. RC、evaluation version 和 final version 分离，允许使用 RC 的昂贵 campaign 证据，同时要求 final 只包含获批版本提升和复验。
5. `status`、`check`、`certify` 具有不同退出语义：当前 blocked 不破坏 RC 门禁，但证据损坏或声明漂移会破坏门禁。
6. synthetic fixture 只证明认证器可达，不进入 live ledger，也不能提升 field maturity。

## 软件 M5 阶段计划

| Gate | 当前 | 完成动作 | 放行标准 |
|---|---|---|---|
| G1 M5-ready RC | pass | 保持 ADK full/root full/release rehearsal 绿灯 | 无 blocker/major；制品可重复 |
| G2 Runtime campaign | blocked | 由 owner 完成 Claude 认证后执行冻结 campaign | 720 raw result、plan/report hash 完整；两 runtime 所有 gates=true；成本 <= `$150` |
| G3 Independent pilot | blocked | 登记至少一个不同 Git common-dir 的真实软件仓和第二位 human operator | 两者都有真实 field event，不是声明-only |
| G4 30-day operation | blocked | 连续记录工作负载、升级、回退、故障、恢复和维护 | ledger 与事件跨度均 >=30 天；metrics 完整 |
| G5 Independent review | blocked | 第二位 operator 记录 `pilot_reviewed` | 结论、维护成本、遗留风险有证据路径 |
| G6 Eligible for final | blocked | 运行 certifier，除 `final_version` 外 blocker 清零 | `eligibility_status=eligible-for-final` |
| G7 Final 3.1.0 | blocked | 仅提升版本、重建/回退/完整回归并更新 policy | `software_m5.sh certify` 返回 0 |

## 当前阻断项

认证器当前固定返回以下 7 项：

1. `runtime_campaign`：Claude 未认证，完整双 runtime report 不存在。
2. `real_repository_count`：只有 `llm_agent` 有 field event，低于 2。
3. `independent_repository`：独立真实软件仓 field evidence 为 0。
4. `operator_count`：只有一位 human operator 贡献 field event。
5. `pilot_duration`：completed independent pilot 为 0，观测跨度为 0 天。
6. `required_field_events`：独立 pilot 的八类事件与 metrics 未形成。
7. `final_version`：在 eligibility 前禁止从 RC 提升为 `3.1.0`。

## 真实负向发现

| ID | 严重度 | 发现 | 处理 |
|---|---|---|---|
| N1 | major | release builder 输出平铺 archive，新 rehearsal 解包器只接受单根目录 | 兼容两种明确布局并增加安全回归；真实 rehearsal 复跑通过 |
| N2 | major | 系统 setuptools 45 强行 no-isolation 构建出 `UNKNOWN-0.0.0` | 拒绝该制品；使用满足 `setuptools>=61` 的独立 build/runtime venv 重建 |
| N3 | minor | 初始 wheel smoke 使用未命中 trigger 的文案而返回 1 | 改用 manifest frontmatter 中真实 trigger；入口与 doctor 复跑通过 |
| N4 | privacy | campaign plan 持久化 runtime 绝对路径 | 改为 `executable_name` 并重新计算 plan hash |
| N5 | external | Claude CLI 未认证 | 不绕过、不模拟、不消费预算；campaign 保持 blocked |
| N6 | major | certifier 最初只检查 independent reviewer 参与过 pilot，没有要求其亲自记录 review | 改为 reviewer-authored `pilot_reviewed` 硬门禁，并加入重新封链的语义绕过负例 |
| N7 | major | 根 certifier 最初只复核 720 条 raw result 的身份和哈希，可能接受语义空记录 | 增加 path/attempt/usage/cost/final/总成本独立复核，并加入重算全部哈希后的篡改负例 |
| N8 | major | policy 可删除关键 rule 或 metric 后保持自洽 | 固化不可弱化 rule/event/metric baseline，删除 `append_only_hash_chain` 的负例固定失败 |

## Evidence Index

| Command | Exit Code | Result Summary | Layer |
|---|---:|---|---|
| `rtk bash agent-dev-kit/tests/run_all.sh --quick` | 0 | `15/15` | test |
| `rtk bash agent-dev-kit/tests/run_all.sh` | 0 | `49/49`，fail `0` | test |
| `rtk bash agent-dev-kit/tests/test_software_m5_ready.sh` | 0 | lock/campaign/release 负向与正向契约通过 | test |
| `rtk bash agent-dev-kit/scripts/devkit.sh eval run --suite runtime --runtime codex --model gpt-5.5 --limit 1 --execute` | 0 | Codex 单任务真实 smoke 通过 | runtime |
| `rtk bash agent-dev-kit/scripts/devkit.sh eval campaign plan ...` | 1 | 预期 blocked；唯一原因 Claude unauthenticated；最坏 `$144` | runtime-negative |
| `rtk bash agent-dev-kit/scripts/devkit.sh release rehearse ...` | 1 | before fix：历史平铺 archive 被错误拒绝 | runtime-negative |
| `rtk bash agent-dev-kit/scripts/devkit.sh release rehearse ...` | 0 | after fix：3.0.0 -> RC -> rollback，31 项恢复 | runtime |
| `rtk bash tests/test_software_m5_certification.sh` | 0 | synthetic positive 可达；live 状态保持 blocked；tamper/path/lock 负例通过 | test |
| `rtk scripts/check-software-m5-readiness.sh . --summary-json` | 0 | integrity/declaration pass，readiness=m5-ready，certified=false | runtime |

## 终态判断

- **已经落地**：软件 M5-ready 的实现、测试、升级回退、预算化双 runtime campaign、可恢复执行、长期试点账本和 fail-closed certifier。
- **尚未成熟**：跨 runtime 统计效果、独立仓真实采用、第二操作者体验、30 天稳定性、真实故障/维护趋势与 final release。
- **当前状态**：`M3 overall / M5-ready software control plane / self_pilot_active / M5 blocked`。
- **停止条件**：未满足 7 个 blocker 前不得把 scorecard、文档、tag 或 release 改成 M5；任何 hash、预算、时间或路径完整性失败均先修证据链，不允许手工绕过。
