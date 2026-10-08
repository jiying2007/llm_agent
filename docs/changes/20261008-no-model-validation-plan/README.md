# 真实证据阶段的可审查方案

2026-10-08。用户允许连续任务总上限提高至 9000 万、分阶段检查，并明确“仅准备可审查方案，继续禁止真实模型调用”。本阶段交付方案和离线验证，真实资格仍保持阻断。结构化方案见 [plan.json](plan.json)，当前 86 项资产内容身份见 [asset-inventory.json](asset-inventory.json)。

## 当前身份和输入

ADK 固定为 8.0.5 / `ef5384305421700ca01e89b3df3b3f7878a70265`，manifest SHA256 为 `0afeabc982ebfb9f7172f0c63b5263e05f003734094d1b73afdd12845e51df07`。资产清单包含 13 agent、65 skill、8 profile，仅记录当前内容身份；真实测量覆盖仍为 0/86。ADK Asset Profile 与 Codex Runtime Profile 分别选择，不能将 core / embedded-fullstack 与 default / team-collab 混用。

只执行版本查询，观察到 Codex CLI 0.159.2、Claude Code 2.1.138。版本输出不证明认证成功、原生触发通过或二进制固定；计划中保留 authenticated_execution_verified=false、binary_digest=null。尚无经审查确认的 immutable model revision、实际干预、未来实验窗口及 managed signer/authority。它们是冻结真实预注册包的输入缺项，不能填写当前配置中的模型别名、测试模型或旧实验日期来制造 readiness。

## 分阶段任务和出口

| 阶段 | 已有入口与可审查产物 | 当前权限与完成条件 |
|---|---|---|
| P0 身份及覆盖 | 当前 pin、86 项内容身份、版本查询、缺项清单 | 本阶段允许；不读取凭证或原始会话 |
| P1 离线软件复验 | 原生 readiness、effect planning、预注册 builder 的现有确定性测试 | 本阶段允许；fixture 不计入真实覆盖 |
| P2 真实实验输入审查 | 选择 runtime、固定模型 revision、独立任务、baseline/candidate、未来窗口、预算 | 只准备方案；输入齐备才生成真实 source/package |
| P3 可信预注册 | `effect_preregistration_package` 生成并复验 canonical package；main workflow 签名 | 本阶段不 dispatch；签名必须发生在任何运行观察之前 |
| P4 G21 原生验证 | discovery/load/trigger semantic assertions、签名 typed receipt、managed registry、production loader | 本阶段禁止执行；版本查询和退出码 0 不能代替语义断言 |
| P5 G22 真实试点 | checkpoint campaign、比较、真实 managed runtime/field receipts、逐资产决策 | 本阶段禁止调用模型；小试点不能替代整体 86 项验收 |
| P6 当前 M5 审查 | 当前候选 runtime、qualification、declaration、独立操作者及周期证据 | 保留历史；使用现有 policy 的要求，缺项不放行 |

重试上限 2 次，同类失败两次先 replan；阶段验证串行，共享输出与缓存不并发。定向复验完成后按实际差异执行 validation plan；本阶段不触发源码 full 或 source-to-live。新资产正文变化才重新走完整 source-to-live，并保留独立 Codex 用户修改和本机有效配置。

## 试点任务清单与比较边界

复用现有 12 项策划任务，六类、每类两项：

| 类别 | 任务 ID | 观察内容 |
|---|---|---|
| requirements | requirements-calibration、requirements-ota | 路由和验收项辨识 |
| planning | planning-recovery、planning-integration | 阶段、恢复和阻塞辨识 |
| test | testing-lifecycle、testing-io-rollback | 测试策略与故障注入辨识 |
| debug | debug-latency、debug-resource | 只读取证和可证伪假设 |
| review | review-snapshot、review-authority | 快照与权限层级辨识 |
| denied action | release-denied、git-denied | 未授权动作的拒绝行为 |

拟议 baseline/candidate 两条件、每任务 3 次，共 72 次模型调用；本次实际调用 0 次。5 美元只是待审议试点上限，目前批准费用为 0。策划任务不是实际用户任务，路由／安全准确性不能证明工程任务完成；全资产收益还需真实任务成功、wrong-route、abstain-precision、可信耗时、人工介入、费用和合并／退役信号。

8.0.2 与 8.0.5 的 skill/agent/profile 等资产正文没有实际干预差异，不能用这两个版本标签直接构造有效效果比较。baseline/candidate 必须具有经审查的真实内容或资产集合差异，固定其余六类控制输入；builder 从原始 source 计算引用和 bundle 摘要，不手填派生哈希。最终 measurement 的资产集合必须等于预注册 candidate bundle，多个有效 measurement 的并集覆盖所有当前资产。

## 冻结、签名与恢复顺序

输入确认之后，先构建 `llm-agent-effect-preregistration-source/v1`，再用 Root builder 生成和独立验证 `llm-agent-effect-preregistration-package/v2`。本次 plan.json 是审查草案，不能作为上述 source/package 传给执行器；未生成或提交可执行 campaign contract。

包必须先通过 main 的 `.github/workflows/effect-preregister.yml`；审查 certificate identity、issuer 和可信 Rekor integratedTime。签名时间必须早于每条 Run Evidence、managed receipt 观察时间及对应签名时间。不得用 registered_at 字段或事后补签伪造预注册。

未来获授权后，用 ADK `eval campaign run` 的 `--state-dir`、显式预算和小批量 `--max-new-results`，按相同冻结计划 `--resume`。中断先对账已有 checkpoint，不能重新调用未知结果。materialize-effect 不调用 provider，输出仍是 test-only 比较输入；真实 managed receipts、authority、签名和 owner review 是另外的验收，不能由 materializer 自动补齐。

## 本阶段验证与责任

本阶段实现者为主 Agent；验证以 actual CLI、当前资产清单逐项重算、既有离线测试及 CI 为准。方案默认 review-required，没有替代真实 human owner 的身份或批准。用户／已登记责任人后续审查模型、干预、任务总体、预算、签名权限、独立操作者和逐资产决策。

连续预算前缀与新阶段分配写在 plan.json，保留旧 goal 用量，另留转场计量余量，不通过新 goal 重置 9000 万总限。源码阶段交付回读见 [上一阶段 closure](../20261007-reference-product-evidence/closure.md)。G21 跟踪 agent-dev-kit#153，G22 跟踪 llm_agent#154；本阶段没有关闭这些真实证据事项。
