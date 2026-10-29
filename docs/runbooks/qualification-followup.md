# 六项既有资格任务的自动复核

## 入口与输出

```bash
rtk python3 -m tools.control_plane.cli qualification-followup --root . --summary-json
```

这个只读入口收集既有 certifier/diagnostics 的实际输出；它不签发新的资格或审批，不调用模型和远程 runtime。输出到 stdout，调用者可在仓库外保留原始 JSON。

- `scan_status=complete` / 退出 0：六项客观复核均正常结束，允许它们仍然 blocked。
- `scan_status=error` / 退出 1：执行、预算、JSON/schema 或来源一致性有错误；同时保留其他检查结果。
- 历史归档的固定来源还必须是 **Root 已提交 HEAD 的 `agent-dev-kit` Gitlink**，不能由可变 Root Index 伪装。逐字节核对受保护 Root HEAD 的 `adk.lock` / `adk_interface.lock.json` 与 index、工作区普通文件、ADK HEAD/tree/manifest 版本身份，拒绝 staging-only 的 gitlink B 与受保护 HEAD A 不一致（即使 B 的 archive Git Tree 与 A 一样）。
- 不论新 validator 返回 PASS 还是旧指纹失配，三份历史 archive 必须先验证原始 review record SHA-256、Git 树/索引/工作区全量普通文件与固定 Root 版本锁；任何替换回执、未被回执引用的文件变更或可执行权限位漂移均不得作为新的有效历史审核。使用文件描述符的 `fstat` 核验工作区文件模式和读取身份，并拒绝额外的空目录、嵌套目录和特殊文件。跨文件读取及父目录并发重命名仍不是原子事务，不能当成完全 TOCTOU 防护。
- 对三份历史 archive，现需先验证原始 ADK Git Tree 与当前固定 ADK HEAD 同一 Tree SHA，并核实所有原始普通文件的 HEAD/index/工作区 blob、文件模式与目录清单；包括未被 review record 引用的 `provenance.md`、`state.yaml`、`review-report.md`、`requirements.md` 等。扫描前的变造、暂存修改、符号链接、未跟踪文件均不得被归为合法 stale，而须 `scan_status=error`。Git Tree SHA-1 是 Git 对象身份，不是回执 SHA-256，不能继承旧审批或产品认证。
- 对三个已完成、不可重写的 #201 历史 archive，若现行受保护 ADK 校验器只因旧 \`validator_sha256\` 被拒绝，则严格核对冻结的历史 record SHA-256、旧校验器指纹、固定 Git base/head/原始 patch、完整证据引用、stage 和 archive provenance。全部匹配时只报告 \`historical-review-validator-stale\`，扫描仍可正常结束，但历史记录 **不能继承为当前来源有效审核**：\`review_verified=false\`、\`delegated_review_verified=false\`、\`qualification_ready=false\`。任何其他异常（包括篡改、缺文件、权限来源漂移）仍按 \`scan_status=error\` 失败关闭。后续真实新审核须另留证据，不改写旧日期、伪造签名或绕过唯一校验器。
- 每项 `command_exit` 是实际子命令退出码；文件审核证据消费为 null。`result` 保留对应有界原始结果，`remaining_evidence` 与 `next_actions` 指向下一步。
- `llm-agent-qualification-followup/v2` 报告将 `required_in_current_scope` 标到每项。`required_qualification_ready` 只汇总当前研究/控制工作区必需的五项；`qualification_all_ready` 仍要求六项全部就绪。两者与扫描成功是不同事实。
- #236 在本范围保持 `status=conditional`、`assessment=not-assessed`、`required_in_current_scope=false`。诊断原始输出继续保留，但不签发 M5；`release_authorized=false`、`may_fill_owner=false` 固定表示本报告没有授权。
- `generated_at` 使用真实 UTC。报告保留前后来源身份、输入摘要和一致性，必须核对实际来源再使用，不能仅凭 artifact 名称或 workflow 绿色下结论。
- 最终 UTF-8 JSON 连同 CLI 末尾换行受 4 MiB 上限约束。超限报告保持 `scan_status=error`，所有资格就绪为 false，并标记 `report_truncated=true`；六项实际退出码和已有 stdout/stderr 摘要保留。
- 超限时完整 `result` 与快照的逐项 `inputs` 可被显式省略。`inputs_omitted=true` 的快照保留原 Git 身份、原完整 `git + inputs` 的 `sha256`、包含缺失项的 `input_count` 及已读取文件的 `input_file_bytes` 合计；这些值不是压缩对象的重新摘要。`source_consistent` 仍是省略前实际比较结果。若继续超限，`diagnostics_omitted=true` 表示命令参数及人工可读说明也已省略；不能把缺失字段当作完整证据或无阻塞。

## 六项权威

| 任务 | 既有权威与正确下一步 |
| --- | --- |
| [ADK #153](https://github.com/jiying2007/agent-dev-kit/issues/153) | Root `native-readiness` 消费精确 ADK；真正认证需 authenticated discovery/load/trigger、签名、受管信任和生产 loader |
| [ADK #201](https://github.com/jiying2007/agent-dev-kit/issues/201) | 三个固定原始 change 的独立 AI Spec/Quality、同一 ADK 委派政策与 canonical review/archive 生命周期 |
| [ADK #205](https://github.com/jiying2007/agent-dev-kit/issues/205) | ADK `harness readiness --gate` 使用当天日期；七维日期须绑定真实复审记录和所审源码 |
| [Root #236](https://github.com/jiying2007/llm_agent/issues/236) | 条件性 Product M5 当前候选认证；诊断不启动产品部署或未知费用请求，默认离线签名待验证不等于组件签名无效 |
| [Root #154](https://github.com/jiying2007/llm_agent/issues/154) | `effect-readiness`，真实预注册实验、全部当前资产的测量和逐项委派审核判断 |
| [Root #67](https://github.com/jiying2007/llm_agent/issues/67) | `longitudinal-operation`，真实完整窗口、末窗口观察、事件/风险总结和真实审核；日期届满不替代证据 |

## 唯一委派审核权威

仓库所有新增审核消费者调用 `tools/control_plane/adk_interface.py::validate_delegated_review`。该桥先比较实际加载 ADK 的 `review_evidence.py`、`strict_json.py`、`readiness_evidence.py` 与显式固定 `agent-dev-kit/src` 下三份普通文件的原始字节摘要，再调用唯一 `agent_dev_kit.review_evidence.validate_review`。安装包旧版本不能自行验证旧记录后绕过当前 pin。模块缺失、符号链接、指纹不一致或非法 API 返回对象均失败关闭。

同一桥还在调用 API 前后验证父 Root 的 Git index gitlink 等于 ADK HEAD，并逐项比较政策、其授权文本和三模块的 HEAD 普通 blob、index stage/mode/blob、worktree 未过滤原始 blob。仅保持 HEAD 字符串不变、修改政策再重算 receipt 摘要不能通过；staged authority、其他 ADK HEAD 或未提交文件也不能成为固定政策。

政策只来自 ADK 的 `.adk/review-policy.json` 及其摘要绑定授权文本。Root 不复制政策，不新增审核标准；审核者必须诚实标为 `kind=ai`、`independence=independent`，与作者不同，并留下真实执行的 Spec/Quality 判断和限制。摘要校验不构成平台身份认证、现场事件真实性证明或发布许可。

历史清单只接受一处 active `docs/changes/<id>` 或 archive `docs/changes/archive/YYYYMMDD-<id>`。两处同时出现、归档名称歧义或不安全路径均失败。每份记录的 `target` 必须同时匹配以下固定 Git 身份及 [设计中的原始完整 patch 摘要](../changes/20261020-delegated-auto-review/design.md)：

| Change | 原始 base | 原始 head |
| --- | --- | --- |
| `20261016-skill-catalog-competition` | `2fe242e9e309e4111c8639e511e53f6a585a1ed7` | `d0c7a9baac8a1942be79a027b1d6feff81079b39` |
| `20261016-effort-evidence-v1` | `d0c7a9baac8a1942be79a027b1d6feff81079b39` | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` |
| `20261016-skill-description-discovery` | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` | `6fa8b40977e83569a775297371759b126406adcd` |

`sources` 必须含 record-relative `evidence/original.patch`，其摘要须与记录 target 和固定历史摘要相等。active 要求 `stage: review-passed`；archive 还须有无重复字段的 `adk-change-provenance/v1`，核对原 change、原/最终阶段、审核者、pass 及记录摘要，并检查归档时间不早于审核、不在未来。`archived_by` 保留真实执行者，`reviewer_id` 来自验证后的独立审核记录，二者可以不同；state owner 不被冒充为审核者。

前后输入快照包含唯一政策、授权文本、三模块、历史审核材料、Harness 各维的结构化审核指针，以及 G22/LTA 指针和记录 `sources/evidence` 闭包。ADK 记录的 repository 基准为 ADK，G22/LTA 为 Root；二者不可混淆。任何扫描中输入漂移使本轮失效。

## 持续执行与证据闭环

[qualification-followup workflow](https://github.com/jiying2007/llm_agent/actions/workflows/qualification-followup.yml) 在相关 PR、main push、每天北京时间 **09:23** 和手动 `workflow_dispatch` 运行。只授予 `contents: read`，使用固定 action SHA 与 10 分钟整体预算。每份 artifact 保留 30 天。

PR 执行校验候选代码；主线/定时结果绑定其实际 checkout 的 main 和 ADK gitlink。工作流摘要分别显示扫描状态与六项资格状态。任何错误都保留已生成报告，不通过 `continue-on-error` 把失败任务变成成功。

GitHub 的定时执行可能延迟或漏调度，公共仓长期无活动还可能停用 schedule；实际采集时间和当前 workflow 状态比计划时间更有权威。相关源码 push 与手动入口是补充触发，不能声称无间断的真实现场运行。

## 真实证据到达后的闭环

1. 将真实证据提交到各自既有 governed 入口，保留原始身份、字节摘要、可信来源和实际操作者；按需要独立验签。
2. 在已授予的 owner-delegated-ai 范围，由独立 AI 审核者实际审查具体证据，再生成可验证记录；无需额外人工 verdict。历史包、七维 Harness、G22 与 LTA-04 各自绑定其真实输入，不用单一空泛 PASS 替代具体审核。
3. 执行对应 canonical gate 并通过受保护 PR；主线更新自动触发本复核器。
4. 核对 exact-source/fresh-main 的真实结果后，再按原 issue 的完成条件更新状态。聚合器不自动改期、填 Owner、关单、改信任注册或授权发布。

外部方法依据与本轮具体复核材料见 [研究判断](../changes/20261020-qualification-followup/external-methods.md) 和 [Owner 复核材料](../changes/20261020-qualification-followup/owner-review-packet.md)。

已授权审核策略的迁移与验证见 [delegated-auto-review 变更](../changes/20261020-delegated-auto-review/proposal.md)。此前要求人工决定的材料保留其历史上下文；当前范围依唯一委派政策消费独立 AI 审核。
