# 产品成熟度模型

`llm_agent` 与 `agent-dev-kit` 是 Agent 资产平台与参考实践治理/交付控制面，不是通用 LLM 推理 runtime。成熟度用于回答“产品是否可以稳定使用和发布”，而不是用现场运营年限代替软件质量。

## M0-M5

| Level | 名称 | 判定 |
|---|---|---|
| M0 | Absent | 能力不存在或只有描述。 |
| M1 | Implicit | 有零散脚本/经验，但无稳定契约。 |
| M2 | Designed | 目标、边界、契约和验收已设计。 |
| M3 | Implemented | 核心路径已实现并有定向测试。 |
| M4 | Release-ready | 接口、CI、回归、安全、制品与回滚可重复验证。 |
| M5 | Production-qualified | 当前候选具有签名供应链证据、代表性真实 runtime 验证、真实独立软件仓使用证据，且所有 M5 阻断门禁由机器认证器判定通过。 |

M5 v3 不再把“30 天、双 runtime 全矩阵、第二位人工 operator、历史旧制品可恢复性”作为**首次达到 M5**的必要条件。这些项目继续保留为长期运营成熟度与发布治理的 advisory，不允许伪造成已完成证据。

## Software M5 v3 必须满足

1. **当前候选身份一致**：`adk.lock`、当前 ADK gitlink/interface lock 与 promotion evidence 指向同一版本、commit、tree 和 manifest blob。
2. **供应链可验证**：promotion evidence 必须 `release_eligible=true`，带 Sigstore bundle provenance；root CI 继续执行 Cosign/Rekor v2 验证。
3. **至少一个真实 measured runtime**：当前版本至少一个真实 runtime smoke 为 PASS，且其全部 quality gates 为 true。
4. **真实独立软件仓证据**：至少一个 governed independent real-software repository 已进入真实 pilot，并有 hash-bound `pilot_started` field event。
5. **至少一名真人 operator**：真实 field event 必须由 ledger 中的 human operator 产生。
6. **证据完整性**：field event 使用 append-only hash chain，所有 evidence 文件内容 SHA256 与事件记录一致。
7. **机器认证**：`scripts/software-m5.sh certify --summary-json` 必须返回 0，scorecard/current-status 必须与计算结果一致。

## 不再阻塞首次 M5、但继续跟踪的运营项

- 独立 pilot 满 30 天；
- 第二位 human operator 与独立 reviewer；
- Codex + Claude 全量 baseline/adk comparative campaign；
- repository runtime campaign；
- 历史 4.0.0 official artifact continuity；
- 更多 direct target native runtime smoke；
- 5.1.0 release train。

这些项目不能被删除，也不能伪造完成状态；它们体现“持续运营成熟度”，而不是“软件首次可用资格”。

## 证据层

- `source`：代码、schema、manifest、policy、lock。
- `test`：单元、集成、负向、回归和 CI。
- `runtime`：真实 CLI/runtime、构建、安装、签名与运行结果。
- `field`：真实软件仓和真实 operator 的现场事件。

初次 M5 需要四层中适用的证据都存在，但不要求长期观察窗口已经结束。

## 权威入口

- 策略：`manifests/software_m5_policy.json`
- 机器 scorecard：`manifests/product_maturity_scorecard.json`
- 试点 ledger：`manifests/software_m5_pilot_ledger.json`
- 事件链：`reports/field-evidence/software-m5-v5-events.jsonl`
- 认证器：`tools/codex_assets/software_m5_v3.py`
- CLI：`scripts/software-m5.sh`

任何来源、签名、runtime 或 field evidence 完整性失败都必须 fail closed；只有 advisory 可以在 M5 后继续推进。
