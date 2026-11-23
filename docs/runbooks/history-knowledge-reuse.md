# 历史经验与知识复用

适用：跨会话复盘、重复流程发现、llm_agent / ADK 迭代设计。优先复用 Hub 与 Codex source 已有工具；历史发现、检索命中、知识批准、运行效果分别记录。

## 读取顺序与覆盖口径

1. 运行 Provider `context`，传目标仓库的绝对 `--cwd`。核对 `route_resolution.state=resolved` 以及 `execution_subject.id` 与预期项目一致，再读取 current、decision、validation 的摘要。
2. 查 governed activity facts / session receipts，按显式 subject 与 repo identity 归并；活动回执是事实源，不自动成为长期 runbook。
3. 查询 Hub registry 与正文索引；`reviewing`、历史条目和当前 source 分层陈述。零命中先看过滤原因、缩短 query 或用已知 item ID，不直接判定“没有知识”。
4. 仅在需要全量覆盖或无法判断复现时，读取本地历史索引。`session_index.jsonl` 是发现入口，不是全部 Codex 会话全集。
5. 需要完整盘点时，以只读线程数据库、session 文件清单、history 有效行共同说明覆盖；按线程 ID 去重，将 subagent 映射到 parent 后再计算独立复现，保留无法映射的数量。
6. 只对高信号 session 的明确段落回读原文，输出脱敏步骤与证据位置。不要把数 GB 会话全文加载到上下文或归档。

`cwd` 是历史 provenance，项目归属应按 Hub registry / workspace mapping 复核。旧目录别名、一次任务的多个 child agent、同一历史行的反复追加都不能提高复现置信度。

## 现有命令

```bash
rtk bash ~/codex/scripts/knowledge-provider.sh context \
  --cwd /path/to/agent-dev-kit \
  --query 'Token 上下文 工作流' --task-type general \
  --context-budget small --limit 3 --summary-json

rtk bash ~/knowledge-hub/tools/knowledge-search.sh \
  '团队 Codex Runtime Bundle' --limit 3 --summary-json --no-telemetry

rtk bash ~/codex/scripts/workflow-mining-report.sh \
  --from 2026-04-04 --to 2026-09-05 --limit 3 --json
```

Provider v4 的 `context` 不接受 `--project`。同一个工作区内查询 Root 和 ADK 时，分别传各自的仓库根目录，预期 subject 分别为 `llm-agent`、`agent-dev-kit`。项目活动报告是另一操作，沿用 `activity-report --scope project --project-id <id>`。

最后一条做标题发现。可追加 `--session-root ~/.codex/sessions` 读取 session header，将有据可查的子线程归到主线程，报告未映射数量；文件日期、索引更新时间和工作事项日期使用不同分母。可重复传入 `--activity-receipt /path/to/sanitized-receipt.json`，聚合显式提供的 `activity-session-receipt` v2 工作事项。默认只输出计数，`--include-match-terms` 只显示命中的内置词汇。标题匹配、工作事项和项目计数都不能直接证明独立复现。

- `--activity-project <Provider 项目 ID>` 只过滤显式传入的活动回执，报告日期窗外、项目缺失和项目不同的去重事项数。先通过 Provider 核对 canonical ID，路径别名和简称不会被当成项目身份。
- 核验标题发现时可同时使用 `--session-root`、`--json` 和 `--include-thread-refs`。报告按组列出最多 20 个由会话头确认的主线程 ID 以及已有 Skill 提示。孤立子线程仍列入未映射计数。该选项不输出标题、原文或本机路径。

## 复用决策与交接

| 发现 | 动作 | 验收 |
|---|---|---|
| 已有知识命中且与当前源码一致 | reuse | 记录 item ID、适用版本、实际采用动作 |
| 已有机制但入口/描述缺失 | extend-existing | 增加正例与相邻负例，路由不扩大权限 |
| 已有多份同义结论 | consolidate-candidate | 建立 supersedes / canonical link；保留原始证据身份 |
| 仅活动回执里有新结论 | archive-candidate | 脱敏正文、reviewing、证据引用与明确 owner；由 Hub 正式 intake 登记 |
| 新机制但独立复现不足 | needs-more-evidence | 同项目至少两独立会话，或跨两项目至少三会话后再评估 |
| 缺少输入/结果或只命中模板 | skip | 如实记录原因，不增加 Skill 数量 |

Miner 归属 Codex 源仓，保持 report-only。工作事项按显式主体、项目和事项 ID 去重，优先用于证明实际工作；标题和会话头用于发现及来源覆盖。未映射的标题不进入主线程数，事项计数也不进入独立会话数。

## 检索验收

本轮可复跑样本与结果在 [检索基线](../../reports/knowledge-retrieval-baseline-2026-09-05.json)。以其中 query 调用上述 search 命令；每次保留日期、index 状态、前 3 个 item ID、预期命中位置和 zero-hit 原因。

- 正例：精确主题、自然语言释义、旧路径别名、跨语言术语、跨项目聚合。
- 负例：不存在的主题、错误 project filter、历史知识冒充最新事实、reviewing 冒充 approved、回执冒充知识正文、child 重复计数。
- 评价：固定 query 集与独立预期答案后的 Hit@3 / MRR、零命中原因正确率、实际引用率、采用后返工率。没有观测值保持 missing，不补零。
- 排名试验：优先测词法/别名/元数据与已注册正文；只有未命中样本证明需要时再考虑混合检索或 embeddings。
- 时延：区分 cold/warm 和并发条件，固定样本多次测量后才报告 P95；一次命令时延不是性能承诺。
- 回执覆盖不等于知识覆盖；“回执 持久化”在 2026-09-05 的 Hub search 零命中，是需要归档/入口调查的缺口，不能以 query 改写命中其他旧文掩盖。

本轮产物是根仓 runbook 与跨仓实施交接，尚未改写 Codex miner、Hub ranking、registry 或运行资产。
