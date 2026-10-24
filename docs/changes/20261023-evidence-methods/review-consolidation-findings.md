# 分析整合与维护预算：独立 Spec / Quality 复审

Reviewer：`ai/root/architecture_audit`。实现作者：`ai/root`。审查者参与了此前独立路径、发布、集成和矩阵审核，并只读审查了本次整合方案；没有实现本次五个文件及删除变更。

本次绑定提交前冻结的五个源文件和一个删除事实。父提交为本地 `4c700de642fb8a1755b657e52b760b4384a5129d`、远端 `64c5192f2d6aaacf65143223f03190564032facc`，两者 tree 为 `81d552d11888dd4b2c2c758497d9f2eacc7c0cc5`。新的实施提交和完整 CI 尚未发生，不由本审核预先认证。

**结论：Spec PASS / Quality PASS。** 本次修正范围内没有未解决阻断发现。八个要求的原始入口独立执行全部 exit 0；全量回归、两个 quick 与新精确提交的 PR / main CI 仍须分别留证。

## METHODS-CONSOLIDATION-01：新增报告超出既有 strict 预算 — 已修正

远端 run 39965536971 及同树本地完整回归在 41 组通过后，于 `test_maintainability_budgets` 失败。原始报告数为 321，warning_limit 为 320；strict 模式拒绝 warning。原始候选、失败日志、五成员 CI ZIP 和旧审核保留为历史，不能通过修改历史结论或重标旧 PASS 消除失败。

实际修正将本轮新增 `reports/evidence-methods-absorption-2026-10-23.md` 的分析并入已有 `docs/changes/20261023-evidence-methods/implementation-map.md`，删除重复载体。审查验证：

- Git 父提交、真实远端 `64c5192f…` 的原报告 blob 与保存的原版字节一致：10280 bytes，SHA-256 为 `50662a903fe77a7915265025f45ab3a62bff4dfccf825b4649c9c034451239f4`，Git blob 为 `53cda81736ca0b702af426ffbcc7091e47ae2109`。
- 去掉原报告标题并统一标题层级后，合并正文只有三处文字调整：两处“本报告”改为“本分析”；原未来审核段落改为准确描述已完成的六文件、七入口历史审核。其余正文逐字保留。
- 四项生产承接、五项研究方法、三项观察及重新进入条件、固定发布来源、ASW 非执行认证、崩溃原子性 / exactly-once 限制、Native / G22 / field / Product M5 资格边界均完整保留。
- `reports/` 的 tracked diff 只有本轮新增报告的删除；没有移动旧报告、添加排除目录、改变计数方法或提高预算。
- 原 maintainability 回归实际 exit 0。独立 strict 实测的十四项 budget 全部 pass、warnings/failures 为空，报告数为 **320**，warning_limit 仍为 **320**，hard_limit 仍为 **400**。当前结果没有新增报告数量余量；它也不构成行为收益或未测语义指标的证明。

十九个相关门禁、测试、planner、checker、policy 与预算配置在执行前后保持父提交字节；十七个原来源、决策、要求、设计、任务和两代审核历史文件保持原字节。

## Intake 与证据语义

四条生产行仍是 EXT-06、EXT-08、EXT-09、EXT-11，target 为 `agent-dev-kit`、decision 为 `adopt`、state 为 `done`。逐对象比较确认只有四条 evidence 中的分析载体路径从被删除报告改为 implementation map；真实 ADK 代码路径、其他字段及其余 206 行未变，总计 210 行。

原 upstream gate 接受实际 `agent-dev-kit/` 本地生产证据，未规定每个 adopt 必须增加根 reports 文件。观察行的深度合同保持原样：本轮三个 OBSERVE 继续留在原 decision ledger，原生产矩阵中的 11 个 observe 行仍由原 gate 校验。整合没有制造生产 intake 包或 ASW 执行回执。

十二个 source、十二个 candidate、十二个 decision 及原 ID / 字节保持不变，决策仍为九个 ENHANCE、三个 OBSERVE。五个研究 ENHANCE 与三个选型 OBSERVE 的原限制继续有效。相关十六个 ADK 实现及 ASW 职责文件继续匹配此前实际读过并绑定的已发布提交 `415590db44e88979185efb850e2339a3f95411ef`；本次没有修改 ADK，也没有重新执行其完整套件。

## 实际执行与摘要依赖

独立执行时间：**2026-10-23T14:18:41.041405Z 至 14:18:51.491714Z**。完整 argv、cwd、UTC 时间、returncode、stdout 和 stderr 见 `evidence/consolidation-independent-execution.json`。

| 原始入口 | 实际结果 |
| --- | --- |
| `scripts/check-upstream-intake-readiness.sh .` | exit 0；164 adopt rows |
| `scripts/check-observe-intake-depth.sh .` | exit 0；11 rows |
| `scripts/check-adoption-matrix-structured.sh .` | exit 0 |
| `scripts/check-adoption-matrix-status.sh .` | exit 0 |
| `scripts/check-adoption-evidence-integrity.sh .` | exit 0；210 rows / 621 paths |
| `scripts/check-adoption-real-assets.sh . --summary-json` | exit 0；234 checked / 233 real assets / 1 个既有例外 |
| `tests/test_reference_repository_removal.sh` | exit 0 |
| `tests/test_maintainability_budgets.sh` | exit 0 |

另外四次调用只解决本次具体依赖风险：strict budget 输出证实 320 及未改阈值；canonical exporter 输出与新 JSONL 逐字一致；canonical planner 与 fixture JSON 对象一致；父提交中的旧 `46ca…` 摘要实际被原 checker 以 exit 2 和 `artifact hash is stale` 拒绝。fixture 语义 diff 只有 `/artifact_sha256/adoption_decision`，新值为 `da66a91c839169f540175cfcfabea245526657e9e9f47b868ea7e1d4b74493b4`。

规划器的 `--as-of 2026-07-19` 是原历史 fixture 输入；本审核使用真实 2026-10-23 时间，没有重写或续期 dirty review。五个冻结源文件、报告缺失状态、十九个 guard 和十七个历史文件在运行后再次核对一致。

## 权威与交付限制

旧 `review-evidence.json`、`review-projection-correction.json` 及附件仍为其对应快照的历史证据。前次七个定向门禁 PASS 是真实历史；随后 64c 的完整集成 FAIL 也是真实历史，本次没有互相替换。当前记录用新五文件与删除事实建立新的绑定。

SHA-256 证明文件身份和内部一致性，不认证作者、上游身份、许可证或全部来源陈述。本次没有外部来源重新认证、付费调用、真实任务收益测量或 ASW 全流程执行。原 dirty-triage 过期与历史 Product M5/current candidate 限制未被修改；静态预算中的 churn、owner concentration 和 inactive assets 仍保留原来的不可用及 report-only 边界。当前定向 PASS 不表示 full / quick / 受保护合并或产品发布已获批准。
