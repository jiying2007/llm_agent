# Maintainability Evidence Metrics

## 目标与边界

`tools.codex_assets.maintainability_budget` 除静态增长预算外，还支持三类需要历史或运行数据的维护性指标：

| Metric | 重算方法 | Unit | 当前 enforcement |
|---|---|---|---|
| `churn` | 固定窗口内每文件 `additions + deletions` 的最大值 | changed lines/file/window | report-only |
| `owner_concentration` | reviewed scopes 中占比最高 owner 的份额 | basis points | report-only |
| `inactive_assets` | invocation window 中零调用 asset 的份额 | basis points | report-only |

没有受审查输入时，三项必须输出 `status=not-available`、`observed=null`，不能用 0 代替缺失数据。当前根仓没有 pinned git-history、ownership 或 invocation snapshot，因此三项都保持 report-only/not-available；strict gate 不因数据缺失失败，也不声称指标健康。

`reports/runtime-evidence/` 保存 schema-bound runtime evidence 与 campaign plan，不计入面向人类的 root report 数量预算；这些文件仍由 policy、SHA-256、freshness 和 current-status checker 治理。该语义排除不适用于普通报告目录，也不放宽 report warning/hard limit。

## Evidence contract

配置中的 evidence source 必须绑定：

- repo 内相对路径；
- evidence 文件 SHA-256；
- `llm-agent-maintainability-evidence/v1`；
- repository ID；
- metric-specific source kind；
- started/ended timestamp；
- revision start/end。
- `max_age_days`；
- reviewed complete population 的 count、digest 和 coverage。

Evidence JSON 必须包含相同 identity/window/population、`generated_at` 和非空 records。Loader 逐级检查 root 到 evidence 文件的每个路径组件，任何 parent 或 leaf symlink 都会失败；之后再校验文件 hash、identity、source kind、revision/time window、freshness 和时间顺序。Observed value 始终从 records 重算，输入不能直接声明 observed。

CLI 必须提供受管 `--repository-id`；root wrapper 固定为 `llm-agent`。Repository ID 必须与 `expected_repository_id` 和 source identity 一致。工具始终确认 revision start/end 都是当前 Git repository 中的 commit，并验证 start 是 end 的 ancestor。当前不支持 non-Git verifier 注入；若未来出现真实需求，必须另建 managed-verifier change，不能由普通 `evaluate()` 调用方传入 bypass callback。

三类 metric 都必须覆盖 reviewed population：

- churn 从全部 record path 重算 population digest，不能选择性漏掉高 churn 文件；
- owner concentration 从全部 reviewed scope ID 重算；
- inactive assets 从全部 asset ID 重算。

Count、digest 或 `coverage=complete` 任一不一致即失败。`max_age_days` 同时约束 window end 和 generated time，因此重新生成旧窗口文件不能刷新历史数据的新鲜度；`--as-of` 可用于确定性 freshness replay。

支持的 source kind：

- `git-history-numstat`
- `reviewed-ownership-snapshot`
- `sanitized-invocation-ledger`

Evidence window 的结束和生成时间不得在未来，且 `generated_at` 不得早于窗口结束。重复 path/scope/asset、绝对路径和 `..` 路径都会失败。Basis-point 指标使用 Decimal `ROUND_HALF_UP`；例如 `1/32` 固定为 313 bp，不使用 Python bankers rounding。

## Enforcement 决策

每项必须声明 risk、`report-only|budget` 和 enforcement rationale：

- 没有 reviewed baseline 时使用 report-only，不允许携带 baseline/limits。
- 只有 owner 审查了来源、窗口和风险后才可使用 budget。
- Budget 必须满足 `baseline <= warning_limit < hard_limit`；warning 在 strict 模式失败，hard limit 始终失败。

当前 churn 风险为 medium；owner concentration 和 inactive assets 风险为 high。三项仍无 reviewed source，因此设置阈值会制造虚假精度，暂不启用预算。

## Privacy gate

Contract 与 evidence JSON 在字段语义解析前执行递归 secret scan，覆盖：

- OpenAI-style API keys
- GitHub tokens
- Bearer tokens
- AWS access keys
- private-key blocks
- Slack tokens
- password/credential/API-key/token assignment
- sensitive keys、raw prompt、messages、raw input/output/content 和 tool payload

最终 report 也执行同一扫描，因此 secret-like root/path/hotspot 不会被回显。失败只返回 secret category，不回显原始值。Evidence 不得保存 prompt、raw log、credential 或未脱敏 invocation payload。

## 验证

```bash
rtk tests/test_maintainability_budgets.sh
rtk scripts/check-maintainability-budgets.sh --strict --summary-json
```

定向测试覆盖：

- 根仓无三类输入时 not-available/null 且 strict pass；
- 三类 fixture 的确定性重算；
- evidence budget warning 与 strict failure；
- digest mismatch；
- stale snapshot、重新生成的旧窗口、foreign repository、missing commit 和 reversed ancestry；
- parent/leaf symlink；
- incomplete population；
- half-up `1/32=313`；
- token taxonomy、敏感字段、credential assignment、raw-content 和 final-report secret 拒绝；
- legacy v1 contract 明确拒绝。

## 迁移与回滚

Maintainability contract 和 report 已从 v1 升级到 v2；旧 v1 contract 会明确失败。消费方应读取结构化 `semantic_axes.<metric>.status/observed/source`，不能继续把 semantic axis 当字符串。

回滚时同时回退工具、backlog contract、测试和本 runbook。不得只把报告 schema 改回 v1 而保留 v2 evidence metrics，否则会造成 consumer/schema 语义不一致。
