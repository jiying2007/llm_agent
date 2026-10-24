# 方法生产投影修正：独立 Spec / Quality 复审

- Reviewer：`ai/root/architecture_audit`；实现作者：`ai/root`。
- 审查方式：独立读取冻结文件、相关已发布 ADK 实现与既有 ASW 职责合同，并实际执行原始门禁及拒绝旧摘要的负例。审查者未实现本次六个文件的修正。
- 受审父提交：本地 `9fd3324b3142990a8351b4b3949941f4c70c2e59`，远端等树提交 `bc6f7a093ef61f0701fea6acef7b0f2ae217e9d5`；tree 为 `7ea992639a9a2b941c10d454283601a2bc88ca84`。本次结论绑定提交前冻结的六个文件 SHA-256，不声称尚未创建的最终提交或 CI。
- 实际执行时间：2026-10-23 13:49:47–13:49:54 UTC。完整 argv、cwd、时间、returncode、stdout、stderr 与文件摘要见 `evidence/projection-correction-independent-execution.json`。
- 结论：**Spec PASS / Quality PASS**；本次修正范围内没有未解决的阻断发现。此结论不使整套 quick 检查、当前产品资格或未来远端 CI 自动通过。

## 发现与修正判断

### METHODS-PROJECTION-01：方法决策被错误投影成生产吸收完成 — 已修正

原来的十二个 `llm_agent + done` 行不符合既有 upstream / observe intake 合同。尾注不能重新定义门禁中的生产完成语义。新投影只保留 EXT-06、EXT-08、EXT-09、EXT-11 四个 `adopt / done / agent-dev-kit` 行，并将它们绑定到已经发布的 ADK 8.0.39 实现和具体分析报告。

原十二个来源、十二个 candidate、十二个 decision 的字节、ID 和关系保持不变；决策仍为九个 ENHANCE、三个 OBSERVE。EXT-01、03、04、05、07 是研究和工作方法承接；EXT-02、10、12 继续观察。八项只退出生产矩阵，没有被删除、改成拒绝、自动采纳或宣称完成新的运行资产。矩阵从 218 行变为 210 行，其他非本轮 EXT 行逐对象未变。原两条门禁分别实际通过 164 个 adopt 行和 11 个 observe 行。

四项生产映射的语义审查如下：

| 来源 | 实际承接 | 结论边界 |
| --- | --- | --- |
| EXT-06 | Native 输出复用 `atomic_io`；公开 publish 复用 canonical release verifier；调用者仍保留正常和失败路径 | 是现有实现的模块职责和复用映射；没有声称测得复杂度、速度或真实任务收益改善 |
| EXT-08 | 输出全集合预检、staging、失败补偿与恢复材料保留；export writer lock 和路径身份复核 | 是代码已具备的恢复行为；没有扩大成 crash atomic、多系统事务或 exactly-once 保证 |
| EXT-09 | 固定 Git commit/tree/blob 来源；tar 全量 source digest 独立重算；外部声明不成为 release authority | 只支持实际 release 来源完整性边界；没有声称新增通用 prompt injection 防护、模型安全认证或 Agent Builder 执行 |
| EXT-11 | publish 对捕获字节进行校验并发布 tar/checksum/contract；dry-run 不写输出；正式 immutable 和签名另有发布证据 | 静态方法映射不代替实际远端发布与密码学验证；不重新认证全部发布流程 |

审查涉及的八个 ADK 实现文件和八个 ASW 职责/参考文件，均与精确提交 `415590db44e88979185efb850e2339a3f95411ef`（tree `51d400e80ba555a49ca85fcfefbd74f7fe499072`）的 Git 对象、sibling 工作树及 Root 子模块字节一致。ASW 引用仅解释已有职责合同；本次没有执行它们的全部步骤，也没有创建或宣称新的 ASW execution receipt。新报告对此作了明确限制。

### METHODS-PROJECTION-02：矩阵改变后 removal fixture 的摘要必须同步 — 已修正

fixture 语义 diff 只有 `/artifact_sha256/adoption_decision`：

- 旧值：`8e33bf87ba1323ad194942537f510c758bd2c31181f68d1f85f23a93565b1c6b`。
- 新值：`46ca2f731f41b4ab2ad8422bc0eba996749404e8528a37117e4794e0f3e2fcb2`。

独立运行 canonical `plan-removal` 的 JSON 对象与修正后的 fixture 完全一致。原始 removal 回归 exit 0。将父提交中的旧 fixture 交给原 `check-removal --no-fixtures --summary-json`，实际 exit 2，明确报告 `artifact hash is stale`。这证明旧摘要仍被拒绝；没有放宽 validator、测试或 hash 合同。规划器中的 `--as-of 2026-07-19` 是既有历史 fixture 的输入，审查时间仍为真实的 2026-10-23；没有重写历史日期或续期 dirty review。

## 实际验证

| 原始入口 | 实际结果 |
| --- | --- |
| `scripts/check-upstream-intake-readiness.sh .` | exit 0；164 adopt rows |
| `scripts/check-observe-intake-depth.sh .` | exit 0；11 rows |
| `scripts/check-adoption-matrix-structured.sh .` | exit 0；同步 |
| `scripts/check-adoption-matrix-status.sh .` | exit 0 |
| `scripts/check-adoption-evidence-integrity.sh .` | exit 0；210 rows / 621 paths |
| `scripts/check-adoption-real-assets.sh . --summary-json` | exit 0；234 checked，233 real assets，1 个既有矩阵例外 |
| `tests/test_reference_repository_removal.sh` | exit 0 |
| canonical JSONL exporter | exit 0；输出与冻结 JSONL 逐字一致 |
| canonical removal planner | exit 0；输出与 fixture 对象一致 |
| 旧摘要拒绝负例 | 预期 exit 2，实际 exit 2；stale hash 被拒绝 |

这十次调用是独立审查者的一次实际执行，不是实现者回执的转述，也没有为补齐证据改写返回值。六个冻结源文件在执行前后保持一致；十五个相关 guard、validator、测试、导出器和 policy 文件与父提交相同；十四个原始来源、决策、要求、设计、任务和审核历史文件与父提交相同。完整列表和 SHA-256 在执行证据中。

## 历史、独立性与交付限制

旧 `review-evidence.json`、`review-findings.md`、旧 probes 和旧执行记录保留原字节。旧审核对初始 collector / 来源边界的观察仍是历史证据，但其十二行生产投影结论和遗漏的两条门禁不被本次继承为通过证明。新增记录只评价本次修正后的文件。

本审查者此前独立参与 ADK 路径边界、发布与 Root 集成检查，未实现本次 Root 方法投影修正；这不是第二次完整的外部来源或许可证认证。没有下载或执行第三方 Skill 正文，没有新增付费模型调用、runtime / field 评估或任务收益测量。现有 dirty-triage 到期与历史 Product M5 / 当前 candidate 不一致仍按各自原始门禁保留阻断；本次没有延长期限、修改产品资格政策或虚构认证。

新源提交、最终 Root 树、受保护 PR 的全部 required checks、实际 main push CI 和最终合并交付由后续精确身份的证据另行确认。本文件不授权合并或产品发布，不修改 ADK Harness/source review 的既有绑定。
