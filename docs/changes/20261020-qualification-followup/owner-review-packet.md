# ADK 资格复核与 Owner 决策包

本包把能够免费、客观复核的源码与机器结果整理为一次可审阅的交付。它提供三个冻结原始变更的独立 AI Spec/Quality 结论、七维 Harness 的实际现状和 Native 可用资源清单。**本包没有代填 human Owner 的决定，没有更新旧复审日期，没有授予 Native、field 或 ProductM5 资格。**

复核日期：2026-10-20 UTC。原始源码基线：ADK `da25a7d86a0efe61110f5d8d892c49ff80d91dcc` / 8.0.34。受协调的下一次源码修复已在独立 ADK 工作树推进 8.0.35；本包的历史 diff 审查对象仍是下面的三个精确冻结提交，不随版本滚动。执行环境为真实 RTK 与隔离 Python 3.12.14，无新增付费调用。

## 1. 独立性、范围与证据身份

Reviewer：本轮独立源码审查 AI。Reviewer Independence：`independent`，相对于三个原始 PR 的作者工作；这不是注册 human Owner 身份或 GitHub 人工审批。审查分别读取完整原始 PR patch、精确 base/head/merge 身份及对应历史 requirements/design/tasks/negative-results。当前源码测试重放用于检查仍在维护的行为，不冒充原始 PR 当时的运行结果。

| 原始目标 | Base | 原始 Head | 冻结 Merge | 完整 diff 范围 |
|---|---|---|---|---|
| [ADK #197](https://github.com/jiying2007/agent-dev-kit/pull/197)，8.0.19 | `2fe242e9e309e4111c8639e511e53f6a585a1ed7` | `180fa29f7e1827a81953129164d946b04495199e` | `d0c7a9baac8a1942be79a027b1d6feff81079b39` | 17 文件，+156 / −9 |
| [ADK #198](https://github.com/jiying2007/agent-dev-kit/pull/198)，8.0.20 | `d0c7a9baac8a1942be79a027b1d6feff81079b39` | `068e5df7340ea4909eb461bd2234aec90feb0dfe` | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` | 23 文件，+227 / −80 |
| [ADK #199](https://github.com/jiying2007/agent-dev-kit/pull/199)，8.0.21 | `61ff6079dc1d994ac33fbd07a0f069d80b39341d` | `3d52c28cde3fc253e87aaf879289f262f8fa8caa` | `6fa8b40977e83569a775297371759b126406adcd` | 25 文件，+121 / −33 |

当前 [#201](https://github.com/jiying2007/agent-dev-kit/issues/201) 明确允许 solo-maintainer 政策下一名实际 human Owner 作出逐变更决定。原始 PR `reviews` 数组为空是可观测事实，不是必须增加第二名人工审批者的依据。若 Owner 同时是原作者，应如实记录 `author-self-review`；不能把本包的 AI 独立性变成人工独立性。

## 2. #197：目录竞争、拒绝与弃权

**Spec verdict：在声明的确定性源码范围内通过。Quality verdict：完整原始 diff 未发现阻断或 major 代码问题。Owner disposition：尚未作出。**

原始 fixture 包含 20 个明确分类的请求：8 个主路由、4 个近邻竞争、4 个否定、4 个弃权。测试检查表头、五列格式、唯一 ID、合法分类、非空请求以及最低样例数量；负例和弃权要求预期 Skill 为 `-`，竞争和否定必须指定近邻对象。

行为检查调用生产 `match_text(..., scope="auto")`：正例验证确切 Skill 身份与 primary role；弃权验证 `match=false`、`decision=abstain` 和 `mutation_permission=deny`。竞争对照也通过相同公开 matcher 对指定 Skill 求值，要求被比较的近邻确实能匹配，而非放入一个从不匹配的虚弱对照。否定用例要求该近邻不能匹配。生产 matcher 在这个 PR 中没有改变。

这满足原始要求中的竞争与拒绝回归，不宣称真实模型排名、真实 Native 自动发现或 Token 改善。原来没有这组 20 条目录竞争验收；变更后在现有测试入口增加这组验收，没有引入新模型、运行时或 CI job。

Owner 需要判断的具体风险：手选的 20 条样例是否覆盖当前最有价值的自然请求与冲突边界；今后业务词汇变化时，维护者是否接受对预期路由变更进行显式复核。样例数量本身不代表自然请求分布的准确率。

## 3. #198：保守 E0–E3 与证据前提

**Spec verdict：在 advisory effort 与权限分离的范围内通过。Quality verdict：完整原始 diff 未发现阻断或 major 代码问题。Owner disposition：尚未作出。**

新增 effort 投影位于既有 permission/effect contract 应用之后。`risk=high`、release mode 或存在 escalation effects 时为 E3；只读为 E0；仅明确 low-risk implementation、workspace-write effect ceiling 且最终 mutation permission 仍为 workspace-write 时为 E1；其余为 E2。输出增加 effort 与依据，没有把 E0/E1 变成写入、设备操作或发布授权。

原始测试覆盖真实只读 E0/deny、debug E2、driver E3/显式设备边界和 release E3，并以受控 fixture 检查 E1 的所有守卫：unknown risk、deny、未分类均保守回到 E2；高风险、effect escalation 以及带 publish effect 的只读请求仍为 E3。当前没有声称存在实际生产 low-risk E1 路由，E1 的正向覆盖属于合成契约测试。

Skill 文本继续要求关键前提证伪、真实活动有效性、源码/构建/输入/频率温度条件一致、A/B/A/B、p50/p95/p99 或明确不确定性、功能等价、预算与回滚。删除固定 300 秒/30 秒阈值及不适用的跨构建比较，不等于降低证据质量；R2 requirements/design/tasks 的合法链路仍在。接口示例从入口移到既有 `references/details.md`，实际核对该引用仍包含 `iface_msg_t` 与 `IFACE_ERR_PARAM` 定义，未发生示例丢失。

Owner 需要判断的具体风险：对所有已声明 escalation effects 保守升级 E3 是否符合实际操作成本；effort 标签是否容易被团队误解为自动权限；压缩后的前提说明是否足够明确。这个 PR 没有测量实际 Token、延迟或模型效果收益，不能据此批准相关收益结论。

## 4. #199：八个 Skill 描述边界

**Spec verdict：在描述与静态近邻检查范围内通过。Quality verdict：完整原始 diff 未发现阻断或 major 代码问题。Owner disposition：尚未作出。**

八组描述分别收紧了以下边界：需求不明确与已可拆任务、嵌入式 MCU/RTOS 单测与一般测试策略、实际 KPI 性能问题与缺少信号、既有归档元数据修复与新知识候选、复杂并行拆解与单点修改、提交/PR 质量门禁与独立审查、版本规划与实际发布。Skill 身份保持不变，生成目录随描述更新；没有新 Skill、provider 或运行时路由。

新增测试使用生产 frontmatter reader，检查八对身份、描述长度、正向词、排除说明及近邻区分词。它能够防止已声明的静态边界意外丢失，不能证明 Claude Code 或 OpenCode 在真实任务中一定选择正确 Skill。

逐个完整原始 patch 的 UTF-8 文本增减核对显示八个 Skill 入口净变化为 −25、−18、−48、−11、−11、−3、−12、−12 字节，合计 −140 字节，均未增加入口体积。这是字节预算证据，不是 Token 使用率实测。

Owner 需要判断的具体风险：这些边界文字是否准确表达当前团队使用方式；词汇级测试在允许的语义等价改写时可能需要维护；真实宿主的自然任务发现仍依赖独立 G21 证据，不能用静态关键词断言替代。

## 5. Owner 一次复核的具体决策单

| 冻结目标 | 本包 AI Spec / Quality | Owner 需要形成的实际记录 | 当前 Owner 答案 |
|---|---|---|---|
| #197 / `d0c7a9ba…` | 范围内通过 / 无阻断或 major | 对 20 条确定性竞争、否定和弃权范围作出 `pass`、`needs-fix` 或有理由的 `accepted-risk`；记录未覆盖的实际任务风险 | 未作出 |
| #198 / `61ff6079…` | 范围内通过 / 无阻断或 major | 确认 effort 是保守提示、权限与高风险边界仍合适；记录 E1 当前为契约 fixture 及性能证据限制 | 未作出 |
| #199 / `6fa8b409…` | 范围内通过 / 无阻断或 major | 确认八个描述的业务边界与字节预算；接受或要求补充静态词汇覆盖的限制 | 未作出 |

实际 Owner 记录应保留精确目标、真实身份与日期、Reviewer Independence、分开的 Spec/Quality verdict、发现和未解决风险。完成既有清单后才通过原有 `workflow review` / `archive` 生命周期与受保护 PR 处理。三个历史 `state.yaml` 目前仍为 `verified`，说明历史 CI 已验证且人工语义决定尚未记录；本包未改动这些状态。不能仅执行一个带 `--owner` 字符串的命令就推定真实人类已经复核。

## 6. #205：七维 Harness 的实际复核起点

2026-10-20 实际运行 `bash scripts/devkit.sh harness readiness --root . --gate --summary-json`，**exit 2**，`schema=adk-harness-readiness-report/v1`，`overall_status=partial`：pass 0、partial 6、needs-review 0、blocked 0、not-applicable 1。扫描没有错误或截断。六个适用维度均报告 `stale_last_verified_at`；tool permissions/MCP 维度仍按既有声明为 not-applicable。

七维当前 metadata Owner 均为 `leiwenjun`，`last_verified_at=2026-07-18`；90 天合同阈值已经经过。下面是本次真实扫描已找到的来源类别和必须由实际 Owner 判断的内容。文件存在仅支持来源可定位，不证明其实际使用效果。

| 维度 | 当前机器结果 | 可定位的既有来源 | Owner 本次实际复核需要回答 |
|---|---|---|---|
| Context | partial，日期过期 | `.adk/harness-readiness.json`、AGENTS、README | 当前上下文入口和层级是否真实满足团队任务，哪些说明已不适用？ |
| Execution contract / Spec | partial，日期过期 | 同一 metadata；历史 change requirements/design/tasks/negative-results | 当前执行约束是否与实际任务、风险及责任一致，未解决例外是什么？ |
| Tool permissions / MCP | not-applicable | 既有 metadata 的 N/A 声明 | 当前是否确实不适用？若已引入工具或 MCP，应按真实情况恢复适用范围并提供权限证据。 |
| Continuity | partial，日期过期 | metadata、历史 `state.yaml` 和连续性 runbook | 实际交接与恢复是否仍可追溯，哪些流程只停留在文档？ |
| Verification / Eval | partial，日期过期 | metadata、CI workflows、AGENTS/README、测试入口 | 当前测试与 eval 是否覆盖实际风险，哪些只能证明源码、不能证明真实效果？ |
| Recovery | partial，日期过期 | metadata、`scripts/backup-rollback.sh` | 现有恢复方法是否适合实际操作，真实恢复 evidence 与残余风险是什么？ |
| Freshness / Entropy | partial，日期过期 | metadata、CODEOWNERS/OWNERS、format/catalog/eval/MCP freshness 检查 | 来源、所有权、权限和过期项是否已经实际复审，哪些维度尚不能刷新日期？ |

现有扫描还明确 `field_evidence_status=not-verified`，没有给出可代替真实 field evidence 的分数。本次已发布包 A→B→A 恢复验收可以为 recovery 的软件正确性提供补充材料，但不自动构成七维实际 Owner 复审。

[#205](https://github.com/jiying2007/agent-dev-kit/issues/205) 的完成判据是：逐维真实复审、记录真实身份/日期/证据/风险，仅更新确已复审维度，经受保护 PR 后以当前日期重跑 gate 得到实际 exit 0 / pass，并保留精确源码结果。历史 `--as-of` 或只延长日期不满足该判据。

## 7. #153：Native 真实资源与下一步

当前免费只读 `target check --all --level static --summary-json` 实际 **exit 0**，`schema=adk-target-check/v1`，两目标各检查 78 个资产、106 个文件。但 Claude Code 与 OpenCode 均仍是 experimental / static / not-certified / not-run，runtime identity 为空、evidence 为空、trust disabled。

| 目标 | 本次读到的 contract digest | 当前文档 freshness 截止 | 资格结果 |
|---|---|---|---|
| Claude Code | `98aa15d888da7e866e7815871ae4c2a031819d9028fef9f3121cb2d58e8dca2f` | 2026-12-25 | static pass，未 Native certified |
| OpenCode | `f7f1f62d555eb9a07f58e275ab7bc6ac2aa3c4ae96b455e89343e121fd73d562` | 2027-01-11 | static pass，未 Native certified |

本地实际可用性查询未找到 `claude`、`opencode`、`codex`、`docker` 或 `podman`；当前进程没有可用 provider credential 环境入口。真实 `~/codex` Provider 入口缺失，执行结果为 exit 127；没有创建同名替身，没有声称 Provider 或 Execution Policy gate 通过，也没有试运行收费模型。

现有 Claude hosted lane 只接受 manual dispatch。通过支持的 GitHub Actions collection API 查询 `event=workflow_dispatch&per_page=100`，实际 total_count=1、返回 1 条，为 [Release run 34690751760](https://github.com/jiying2007/agent-dev-kit/actions/runs/34690751760)，2026-09-12、source `59cbd5cb40ca7077ee5407636bfc617e295ec7e5`。没有可取回的 Native hosted campaign run。这个结果限定于当前保留的公开历史，不能断言已删除或其他环境中的历史运行从未发生。当前 managed Native trust registry 的 authorities 也是空集合。

因此没有足够真实资源或既存签名证据可以自动关闭 [#153](https://github.com/jiying2007/agent-dev-kit/issues/153)。可继续自动完成的是源码预检、范围冻结、失败诊断与复核包；一旦实际免费可用的已认证运行环境及权限存在，下一位执行者可沿现有 canonical `native-campaign prepare/run/finalize` 处理一个 direct target。必须绑定精确源码/版本、contract、bundle、runtime binary/version、authenticated identity、命令、assertions、authority/backend 与预算。

成功 finalize 后仍需要原始收据签名、managed registry 的精确 receipt/bundle/authority/target 绑定、生产 loader 验证、真实 Owner 复核与 target promotion、ADK 正式 Release 和 Root 精确推广，最后 Root `native-readiness --require-native --summary-json` 实际 exit 0。源码回归、假 runtime、未认证 smoke、fixture 或无签名收据都不满足该路径。

本轮另有一个独立工程变更处理 failed hosted campaign 的后续默认 success-only 上传导致诊断丢失。ADK change `20261020-native-failure-diagnostics` 只补有限 metadata 失败工件，保留原始失败状态；该工程变更本身没有产生 Native 通过证据。

## 8. 本轮实际执行与边界

以下命令通过真实 RTK proxy 和隔离 Python 3.12.14 执行；退出码为实际返回值。历史 diff 的完整读取另经 GitHub 只读接口完成。测试期间协调者开始了 8.0.35 版本身份同步；表中行为源码来自 8.0.34 基线，未将当前重放写成三个历史 PR 的原始 receipt。

| 命令或查询 | 实际结果 | 可支持的结论 |
|---|---|---|
| `bash tests/test_skill_trigger_matrix.sh` | exit 0，4 tests | 现有 matcher 路由及 effort 相关确定性回归通过 |
| `bash tests/test_skill_governance.sh` | exit 0，16 tests | 现有描述和治理边界回归通过 |
| `bash tests/test_skill_content.sh` | exit 0，456 passed / 0 failed | 当前 Skill 内容断言通过 |
| `bash tests/test_catalog.sh` | exit 0，PASS | 当前生成目录一致性通过 |
| `bash scripts/check-change-governance.sh docs/changes/20261016-skill-catalog-competition` | exit 0 | #197 历史变更包结构有效 |
| `bash scripts/check-change-governance.sh docs/changes/20261016-effort-evidence-v1` | exit 0 | #198 历史变更包结构有效 |
| `bash scripts/check-change-governance.sh docs/changes/20261016-skill-description-discovery` | exit 0 | #199 历史变更包结构有效 |
| `bash scripts/devkit.sh harness readiness --root . --gate --summary-json` | exit 2，partial，六维 stale | 当前 human readiness 仍未完成 |
| `bash scripts/devkit.sh target check --all --level static --summary-json` | exit 0，两目标 static pass | 源码布局有效，Native 未认证 |
| GitHub `actions/runs?event=workflow_dispatch&per_page=100` | HTTP 成功，1 / 1，只有 Release run | 当前没有可取回的 hosted Native campaign 证据 |

结构检查通过不等于语义或 Owner 批准；本地 Python 3.12 结果不冒充其他解释器或真实宿主运行。既有正式 8.0.34 的受保护合并、三版本 main CI、签名便携 promotion evidence、immutable Release 及正式 8.0.33→8.0.34→8.0.33 恢复验收属于已完成的软件发布链，可以引用为相应技术证据，不能替代这里仍待完成的人类决定和真实运行资格。

## 9. 本轮合并与资格关闭的边界

按三项 Issue 原文推断，#153 是明确 external-evidence-only 的终端 Native 缺口，#201 是已发布历史源码的语义/Owner 记录缺口，#205 是单独保留失败状态的实时 human readiness gate；它们没有要求阻断无关的、通过既有门禁的源码受保护合并或组件 Release。实际 required checks 与 release gate 仍必须照常通过。

三项资格关闭则各有未完成的真实证据：#153 缺认证 Native campaign 及完整签名推广链；#201 缺三项逐变更真实 human Owner 决定和既有生命周期记录；#205 缺逐维实际复审及当前 gate pass。这个薄聚合 runner 和本包可以把缺口持续、精确地暴露出来，不能替这些权威入口作出通过判断。
