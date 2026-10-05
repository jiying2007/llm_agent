# llm_agent / ADK 内外部审查与迭代记录

本工件状态为 reviewing。本轮计划与审查合并存放在 docs/changes，避免超过根仓 active report 数量预算；不增加 root script 或 manifest。不代表 Knowledge Provider 已记录长期结论。

## 提交交付阶段（2026-10-06，本节优先于历史检查点）

- 用户新增授权：检查、提交、推送、受管应用并开始下一轮。merge 仍按独立授权处理；不调用真实模型。
- ADK 优化提交 a6a1367、版本前移 dedeba7 和投影修正 b668712 已推送至 canonical 交付分支；[PR #173](https://github.com/jiying2007/agent-dev-kit/pull/173) 的全部 hosted 检查成功，head=b668712d3277ed1a4347e78ba83628b643a0c1e9，mergeStateStatus=CLEAN。直接推送 main 曾被 ruleset 拒绝，保留为负结果。
- source candidate 7.14.0；root gitlink、adk.lock、interface lock 同时绑定该完整 commit、tree=2adf96c5a41018846cb1303117e676f17351ac46、manifest blob=538995c328009f640ee9208e7a4d57249dbe106e。生成 current-status 保持 historical / release_authorized=false。
- 最终 root frozen full：72/72 PASS，exit=0，证据 /tmp/llm-delivery-b668-full.json；不复用中途身份变化导致的旧失败。独立交付 delta review spec/quality PASS，reviewed staged snapshot=346411dcb560ca0015171c404a6631ab632ff647b606bcfc8bbca71d3983e42d。本节仅追加交付事实，之后重新进行文档与暂存区检查。
- clean-source release build PASS：/tmp/adk-delivery-7.14.0-build/agent-dev-kit-7.14.0.tar.gz，sha256=ddcf2f4612b8573918fc4e9e3f8623d9897355016329e9a7c22fa57b3cc7a655，provenance=git-clean-commit/b668712。release_eligible 仅是组件构建属性，不等于签名 promotion、产品资格或 live apply。
- 上轮源码任务按实际已完成范围关闭，预算超限历史未改写。本阶段曾将全部交付登记为一个 goal，commit terminal gate 要求 completed，故显式 abort/replan 为“提交准备”阶段；源码、构建、独立审查和 checkpoint 回读后 commit gate PASS。未把尚未合并/应用标为完成。
- source-to-live 暂待合并授权与当前 main 签名 promotion。~/codex 当前仍绑定 7.12.4，repo/governance doctor PASS；已有 Execution Policy 和 Provider dirty 修改均保留，不提交、不覆盖。
- 下一轮已在 .worktrees/adk-next-strict-version-20261006 从 b668712 隔离实施：严格验证提前复用版本投影检查，quick 语义保留；负例和消费者定向验证已执行。独立 review 发现 fixture symlink 写回风险，正修复复审；本候选未提交、合并或应用。

本节不继承旧 7.13.0 矩阵的字节快照资格。最终 7.14.0 的 local parity 另行绑定 /tmp/adk-delivery-b668-parity.json；是否可复用只以其实际完成结果与 --check-receipt 为准。

## 最新闭环结果（2026-10-06，本节优先于下方历史检查点）

用户授权按全部建议实施，执行预算上调至 3000 万；真实模型评测明确仅落地工具、不调用模型。本地源码和工具项已落地，项目源码验证通过；正式发布、真实效果、运行部署及外部 owner 资格独立保留，不宣称产品放行。

### 实现与兼容

- ADK 仍在 canonical main，HEAD=ed688c94d3fb101c77b9f22a6c7b9a1aa90d9c40，原分支和用户参考仓保留；本轮无正式 commit/push。
- strict_json 统一关键 manifest/contract/receipt、campaign、task/effect JSONL 和 CLI 的重复键、NaN/Infinity/浮点溢出、深度/字节限制；补实际 prepare/campaign 消费者负例，错误不回显内容。保留重复键静态类别用语兼容。
- bundle 与 rollover fixture 使用独立临时 Git metadata；原源码无 .git 时安全白名单复制、剪枝隐藏/cache/symlink，仍执行可复现和 dirty 拒绝测试。正式 clean-source gate 未放宽。
- canonical `adk eval boundaries --summary-json` 提供 21 个固定副作用/MCP 演练；不执行 executor、网络、DNS 或模型，不作真实授权/锁/transport 资格。
- intake IO、reference 生命周期/移除规划拆分为拥有明确职责的 typed 模块，原消费者端口保留；官方来源 checker 的 1793 行 shell 收敛为 6 行转发与 6 个审查阶段，独立 AST 审查确认 322 条原业务语句保持一致。
- Provider/Execution Policy 文档入口统一；report retention 默认只读，依赖扫描覆盖 root/源码/相对链接，缺覆盖或资源预算不满足时阻断候选，不移动历史证据。root script 数量仍为 89、report 数量仍为 320，maintainability strict 通过。
- effect_planning 准备 12 个任务、3 trial、两条件、72 次计划运行，冻结同一 bank bytes，拒绝覆盖，输出事务可回滚；没有模型调用或真实收益声明。
- profile footprint 的 +435 bytes 被门禁发现后，将演练说明移至 runbook，技能参考恢复原文；没有提高字节预算。

### 最终验证与审查

| 层 | 新鲜结果 | 证据 |
|---|---|---|
| root full | 72/72 PASS，fail=0 | /tmp/llm-optimization-verified-full.json |
| Python 3.8.20 full | 97/97、routing 30/30、wheel/audit PASS | 最终 parity receipt |
| Python 3.11.15 full | 97/97、routing 30/30、wheel/audit PASS | 最终 parity receipt |
| Python 3.12.13 full | 97/97、routing 30/30、wheel/audit PASS | 最终 parity receipt |
| source semantic review | independent spec/quality PASS；旧 1 major / 1 minor 已修复；无剩余已确认 B/M/m | optimization_review 最终交接 |
| 模块/文档/格式 | core ruff、module budget、registry、UTC、doc-sync、两仓 diff --check PASS | 定向命令与完整矩阵 |

最终 `/tmp/adk-optimization-final-closed-parity.json`：status=pass、mode=full、source_snapshot_sha256=9186698d01499e69aec7cbd39d54e7597a094eac1d5a98eab9a5332ddf52354e、receipt sha256=efb5d176090fc49502e766a9820b6505569775bb7e23f3b41be1801f74635e49。矩阵 exit=0，之后 --check-receipt exit=0，明确匹配 current snapshot / versions=3 / full。此回执仅是 local parity，不是 runtime 或 release 认证。

最后一次独立 source review 的 managed-diff-v2=b6f12e5be673c535f81627506b081b201ab62ea21d63fe0f798c86900c2d11a1；已排除测试运行中的 transient fixture 误绑定。本节更新只变更 root 收口文档，不更改已验证 ADK 源码或矩阵身份。

### 跨日来源核验与负结果

午夜后 3 条既有官方来源到期，实际读取官方页面再刷新，而非直接延长日期：[non-interactive](https://learn.chatgpt.com/docs/non-interactive-mode)、[Record & Replay](https://learn.chatgpt.com/docs/extend/record-and-replay)、[Appshots](https://learn.chatgpt.com/docs/appshots)。确认 JSONL/ephemeral/最小权限、skill packaging、前台窗口/可用文本/权限边界；retrieved_at=2026-10-06，expires_at=2027-01-04，符合原 90 天政策。原 URL、owner、adopted 决策和默认禁用边界不变。

保存而不复用的负结果包括：最初 footprint/错误消息不匹配；午夜到期导致 11 个连锁失败；Docker 无 .git 时的 fixture 失败。最终矩阵在修复和真实来源核验后完整重跑，不能将早期失败回执写成 PASS。

### 资格与控制面边界

- 构建仅使用显式 allow-unbound-snapshot 的本地 candidate；release_eligible=false，没有发布、签名造假或 live apply。
- 产品资格仍需当前源码的签名/正式提交身份、真实 runtime/field、参考 baseline owner 复核和 owner 决策；用户明确未运行模型，真实收益/费用保持 not-measured。
- Execution Policy 最后 steady snapshot 的控制面统计超过 3000 万，recommended_action=stop；按规则停止新工作，仅保存已完成验证和交接。预算失败不覆盖 root 72/72、三版本 97/97 和独立源码审查证据。
- 当前 ADK tasks 中 F 的“最终回执”以本节为准，避免修改 ADK 规划 metadata 使刚验证的 source snapshot 失效。整体 release/runtime qualification 不标 complete。
- 回滚锚点：旧分支仍保留，所有正式改动未提交；生成物仅在 /tmp 或既有 .cache；不清理用户 dirty/reference 数据。

恢复若只处理正式交付资格，先回读本节和最终 receipt，核 source hash，再分别获得对应提交/发布/部署及 owner 权限；不要重放已通过的源码优化。

- goal_statement：审查当前 llm_agent 与 ADK 实现、契约和外部实践，修复可复现缺陷，给出分层验证结果与后续优先级。
- scope：根仓维护入口、验证快照与只读 intake；ADK 评测输入与跨 cwd 测试入口。按仓库顺序修改，保留既有子仓指针与参考仓现场。
- implementation_permission：用户已授权内部审查、外部搜索和本地迭代，并显式要求同步 ADK 主分支且保留有效修改；已执行 fetch、switch main 和 ff-only。无新提交、push 或外部 merge 授权。
- required_evidence：基线门禁、外部一手资料链接、负例复现、定向回归、整仓回归、最终 diff 与 Execution Policy。
- claimant：当前执行 Agent；verifier：确定性测试及单独最终 diff 审查。未进行独立 Agent 审查。
- retry_budget：同一失败最多两次无信息增量重试；第三次前必须 replan。
- staleness_threshold：源码修改后旧快照证据失效；外部资料以本轮访问日期为准。
- stop_condition：pass / replan / split / blocked；不通过修改 owner、签名、现场证据或 dirty baseline 日期制造 PASS。
- logical_task_open：true；completion_claim：本轮源码迭代已落地，整体资格与最终矩阵未闭环；heartbeat：2026-10-05；stop_condition：Execution Policy stop。

## Phase 1：基线和外部证据（已完成）

- ADK HEAD：ee3eb59；工作树初始干净；根仓既有 ADK 指针变化和参考仓目录保留。
- ADK strict validation 通过；根仓 quick working-tree 52 项，34 PASS / 18 FAIL。
- validation_plan 被已登记的 mattpocock-skills 未跟踪仓目录阻断。
- intake_pipeline 在 Python 3.8 因 Path.is_relative_to 报错。
- 从根仓运行 ADK 全回归出现 tests 包导入与 Path.cwd() 指向父仓的问题。
- 外部研究覆盖评测、长任务恢复、工具延迟加载、MCP 安全、safe outputs 和 harness 简化；仅作为研究输入。

## Phase 2：确定性修复（进行中）

1. 主分支同步后，参考根目录和 Python 3.8 路径问题已由根仓现有实现解决；本轮仅修复路径前缀误判，使用显式文件族 glob 保留高风险分级。
2. 将根 AGENTS 的 Knowledge 与 final 入口对齐现有 Provider / Execution Policy。
3. 修复 ADK 全回归 cwd，严格拒绝重复键 JSON 评测输入；补负例。
4. 旧 manifest / CLI 入口已由根仓现有实现解决；本轮修复采纳矩阵中的退役源码链接，绑定删除前固定提交，不恢复旧权威。

### 主分支重新冻结

- 原分支保留：codex/adk-deep-optimization-local-20260927，HEAD ee3eb59。
- ee3eb59 与已合入主分支的 9dc8c67 源码树完全相同：a25fd1b87a88f51a912a0a609bed79c15c4c8b6f；本地有效修改均已包含。
- 当前 ADK main / origin/main：ed688c94d3fb101c77b9f22a6c7b9a1aa90d9c40（7.13.0），匹配根仓 gitlink 与 adk.lock。
- main quick working-tree 基线：52 项，47 PASS / 5 FAIL；早期 34/18 仅保留为同步前负结果。
- 定向 validation_plan 19 tests PASS；adoption evidence 206 rows / 602 paths PASS；结构化矩阵同步 PASS。
- 重复键定向首轮因 ManifestError 继承 ValueError 导致错误消息被包装；已将捕获收窄至 JSONDecodeError / UnicodeError，等待复验。

## Phase 3：验证与收口（待执行）

- 定向测试后执行根仓与 ADK 全回归；资源矩阵：ADK host 使用独立临时目录和 /tmp/adk-audit-20261005-main-full.json，根仓使用独立临时 fixture 和 /tmp/llm-root-audit-20261005-full.json，Docker 使用只读源快照与隔离 tmpfs。独立输出可并发，源码与共享配置修改串行。
- 从非仓库 cwd 验证维护入口；回读计划和报告；最终审查 diff。
- 原有签名缺失、锁与真实现场证据不一致单列，不更新虚构资格。
- source-to-live：仅在源与根仓 readiness 闭环后执行；当前门禁阻断。

## 恢复信息

- evidence：/tmp/llm-adk-audit-20261005-main.json；/tmp/adk-audit-20261005-main-full.json；/tmp/llm-root-audit-20261005-full.json；/tmp/adk-audit-20261005-parity.json（后 3 项运行中）。
- excluded context：凭证、raw session、参考仓未提交正文与历史发布资格。
- next-actions：完成 Phase 2 定向修复；执行 Phase 3；更新最终报告和 open_items。

## 外部检索与内部能力对照

检索日期：2026-10-05。只使用 Anthropic、MCP 和 GitHub 官方一手资料；检索词覆盖 long-running harness、agent evals、advanced tool use、MCP security、safe outputs。外部来源全部保持研究输入，无 clone、安装或 runtime 注册。

| 来源 | 可复用实践 | 当前内部证据 | 本轮处理 / 后续优化 |
|---|---|---|---|
| [Anthropic Agent evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | 多 trial、稳定环境、区分 transcript 与 outcome、质量与回归评测分开 | effect_trials、run_evidence、trace_summary 和 eval_suites 已存在 | 补齐歧义 JSON 负例；下一步以预注册真实任务验证收益，不能把合成测试通过率作为效果 |
| [Anthropic 长任务 harness](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | 可恢复状态、单步验收、交接记录 | campaign/native_campaign、planning-execution-loop 已具备 checkpoint 和恢复契约 | 不新增第二套计划系统；增加真实中断/恢复、未知写入结果对账的跨层故障演练候选 |
| [Anthropic advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use) | 工具按需发现、程序化编排减少上下文负担 | token_context_policy 已声明 deferred loading；task_cost 与 profile footprint 有测试 | 候选：固定真实任务集，采集冷启动上下文、错误选 skill、token/cost/latency，按效果调整加载；不照搬厂商 API |
| [MCP 安全实践](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices) | token audience、SSRF、redirect、DNS TOCTOU、状态 handle 与认证分离 | MCP staging 与默认禁用边界已有静态契约 | 候选：真实 target 启用前追加 transport 负例与 redirect/state-handle 演练；保持协议能力观察，不由新规范元数据自动激活 |
| [GitHub safe outputs](https://github.github.com/gh-aw/reference/safe-outputs/) | 只读推理产出结构化请求，独立受控 job 执行写入 | tool-effect-contract 与 proposal/executor/receipt 的方法边界已存在 | 候选：把未知结果恢复、重复 operation、stale proposal、撤销权限纳入可复跑跨层演练；不新增后台写入 |
| [Anthropic Managed Agents](https://www.anthropic.com/engineering/managed-agents) | harness 假设随模型变化需要重新评估；session/harness/sandbox 解耦 | typed core 与 runtime adapter 已分离 | 候选：用真实效果删除无收益的规则和重复门禁，先评测再减法，不导入 hosted service |

上述后续项均为 review-required 候选，未变更 adoption decision、默认 runtime 或发布权限。由资料推导出的优化方向是工程判断，不是外部资料证明本项目已获得收益。

## 优化优先级与验收

| 优先级 | 条目 | 验收 | 状态 |
|---|---|---|---|
| P0 | ADK 主分支和本地有效修改收敛 | canonical origin/main、gitlink、lock 一致；旧分支可恢复；tree equality 证明保留 | 已实现并核验 |
| P0 | 跨 cwd 测试与歧义评测输入 | 父仓/非仓库调用正确；重复 root/nested/escaped key 与 CLI invalid 负例 | 已实现，最终回归中 |
| P0 | 历史证据链接和新接口分层 | 不恢复退役权威；固定删除前 commit；fixture hash 与矩阵同步 | 已实现并定向通过 |
| P0 | 发布/现场资格证据 | 签名、source identity、真实 runtime/field、owner review 各自闭环 | 仍阻塞；禁止伪造或放宽 |
| P1 | 真正可用性的量化 | 预注册 representative task bank；固定 runtime/model/grader；每任务重复 trial；成功率护栏与成本分布 | review-required 候选 |
| P1 | 控制面文档去重 | Provider/Execution Policy 入口一致；旧入口有移除说明；不改变权限 | 根 AGENTS 已对齐，其他 runbook 需定向同步 |
| P1 | 大模块与脚本收敛 | practice_intake 2078 行、reference_repository 1333 行、ADK official docs checker 1793 行；按稳定能力边界拆分且原合同测试不变 | 候选；不在未冻结契约时大规模拆分 |
| P1 | 来源/证据统一严格解析 | 评测、campaign materializer、manifest/receipt 逐项审计重复键与限额；共享 parser 必须有兼容说明 | 本轮只硬化 compare-trials；其余待审查 |
| P2 | 报告生命周期和过度治理减法 | 当前 active report 320；先 governed supersession/归档，再新增常驻报告；效果证明后删除重复步骤 | 合并本轮计划与报告，无新增 active report |

## 负结果与修正

- 同步前门禁 34/52 PASS 不适用于当前 main；同步后重新冻结为 47/52 PASS。
- 首轮重复键错误被 ValueError 包装；收窄为 JSONDecodeError / UnicodeError 后 CLI 仍脱敏且可区分歧义错误。
- 在 host suite 运行期间修改 runner 导致 Bash 文件读取位置不一致，旧 host run 没有可用完整 receipt；最终用固定源码从 /tmp 重跑，验证期间不再修改该脚本。
- 本机默认 Python 3.8 不满足根仓 3.11+ 契约；使用现有 /tmp/llm_agent_py311_venv（Python 3.11.16）重跑，不修改依赖要求。
- 原 runtime_control 只剩两份未跟踪 __pycache__，已完整移至 /tmp/adk-retired-runtime-control-cache-20261005-01a10c77；没有删除用户源码，旧分支仍保留。接口、native readiness 与 terminal closure 定向恢复通过。
- 原 local CI receipt 不匹配新源码，未复用旧 PASS；启动新隔离矩阵，结果需按其自身 snapshot 判断，不替代最终源码证据。
- Execution Policy 首次 snapshot 缺 intake；按新用户规则读取自动 intake 文档后登记真实两条请求并回读，REGISTERED。未补造测试或发布资格。

## 收口检查点（NEEDS_REVIEW / 未整体完成）

- 根仓 final full：69 tests / 68 PASS / 1 FAIL；唯一失败 test_software_m5_rollover，原因是当前 root source 存在未提交修改，不能作为 clean-source 认证证据。证据：/tmp/llm-root-audit-20261005-final-full.json。
- validation_plan 19 tests PASS；adoption evidence 206 rows / 602 paths PASS；结构化矩阵 PASS；maintainability strict PASS（报告数量 320，无新增 active report）；git diff --check 两仓通过。
- 接口、native readiness、effect readiness、terminal closure、reference repository removal 定向均通过。
- ADK final host 从 /tmp 调用，--timing-json 为相对输出路径；最终 95 tests / 94 PASS / 1 FAIL。runtime bundle 源码测试 3/3 PASS，但 clean-commit 身份阶段被 dirty source 阻断，构成唯一失败。最终 suite receipt：/tmp/adk-audit-20261005-final-full.json；相对路径写入 /tmp 已复验。
- ADK 隔离矩阵：Python 3.8.20 full 95/95、routing 30/30 和 audit PASS；Python 3.11 进行中，Python 3.12 尚未执行。矩阵绑定其启动时隔离 snapshot，后续相对输出路径修改尚未获得同 snapshot 资格；禁止复用为当前完整 PASS。目标回执：/tmp/adk-audit-20261005-parity.json。
- 根仓 quick main 基线 47/52 PASS，历史证据链接修复后对应项定向 PASS；仍有 cosign 缺失、参考 baseline 过期及 M5 source/evidence 不匹配。未伪造签名、日期或现场资格。
- Provider：ARCHIVED / persisted=true；item_id=provider-llm-agent-85cdfb6aec9222231a5a7243；candidate_status=reviewing；active_promoted=false；owner_review_performed=false。
- Execution Policy：当前准确线程的 intake 已登记；steady snapshot 在 2026-10-05T14:56:22Z 返回 recommended_action=stop / token-budget-exhausted，统计 goal_tokens=1469509、配置 token_budget=300000。本次按 stop 收口，不重设预算或伪造完成。
- completion_guard：needs-fix；未做独立 Agent review；只有确定性验证和本执行者的最终 diff 核对。没有 commit/push 或 live apply。
- rollback_path：旧 ADK 分支保留；本轮 patch 未提交且可逐项回退；两份旧缓存完整保存在 /tmp/adk-retired-runtime-control-cache-20261005-01a10c77，不清理用户参考仓。
- Codify Decision：reusable_pattern=tree equality before synchronization / cwd-safe runner / strict evidence input；promotion_candidate=reviewing-only；next_task_friction_reduced=减少重复合入和假失败；reduced_by=入口及证据边界修复；reduction_evidence=定向回归和 68/69 根仓结果；owner_review=pending；do_not_promote_reason=完整矩阵、clean-source 和外部资格未闭环。

### 恢复后的最多三步

1. 回读已结束的 host suite 回执与隔离矩阵（session 43349）结果，先核 SHA / snapshot 是否仍相同；运行中的脚本禁止修改。
2. 完成同 final snapshot 的受支持 Python 矩阵与 fresh review；不以 dirty snapshot 替代 clean-source 制品身份。
3. 按已有门禁分别补 cosign/签名、参考仓 baseline 的实际复核和 M5 真实证据；之后才进入 source-to-live。执行策略需先由真实路由重新裁决，不能绕过 stop。
