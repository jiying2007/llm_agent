# WeChat Article Absorption Runbook

`wechat-articles/` 是临时参考素材池，不是 `agent-dev-kit` 的事实标准。吸收目标是把可复用经验转成规则、门禁、模板、脚本或测试；不是把公众号原文、工具宣传和一次性教程搬进核心资产。

## Default Policy

- 先生成 article-level ledger，再按批次吸收。
- 每篇文章只允许有一个当前状态，状态源为 `reports/wechat-article-intake.jsonl`。
- 外部 GitHub、源码、安装命令和配置片段默认 `report-only-until-security-review`。
- 已有同类能力时默认增强现有资产，不新建平行 skill/workflow。
- 纯资讯、重复教程、过期模型动态默认 `REFERENCE_ONLY` 或 `REJECT`。

## Commands

```bash
rtk scripts/generate-wechat-intake-ledger.sh
rtk scripts/check-wechat-intake-ledger.sh .
```

生成物：

- `reports/wechat-article-intake.jsonl`：每篇文章的结构化 intake ledger。
- `reports/wechat-article-decisions.tsv`：人工审查后的决策输入，由 generator 合成回 ledger；不得手工改 ledger 状态。
- `reports/wechat-absorb-next-batch.md`：按 P0/P1 优先选出的下一批候选。
- `reports/wechat-absorb-batch.template.md`：每批决策与验证报告模板。

## Batch Order

1. `P0-context-memory-token`：上下文、记忆、token、日志压缩、回退原文、复盘沉淀。
2. `P0-skill-agent-sop`：Skill/AGENTS/SOP、adk-first 路由、触发边界、完成标准。
3. `P1-multi-agent-review`：多 Agent、worktree、PR review、Git 协作。
4. `P1-test-release-quality`：测试、CI、发布、eval、质量门禁。
5. `P2-external-code-candidates`：开源代码候选，仅做供应链和适配评估。
6. `P2-reference-only`：保留引用或拒绝，不进入核心资产。

## Absorption Gate

每个候选项必须回答：

1. 现有 `agent-dev-kit` 是否已有等价 skill、workflow、script 或文档？
2. 候选项是否符合 adk 嵌入式全栈边界？
3. 是否会引入触发词、职责或门禁重复？
4. 是否需要修改 `manifest.yaml`、导航、runbook 或测试？
5. 为什么不能只作为 `REFERENCE_ONLY`？

## Decision Overlay

批次执行后只维护 `reports/wechat-article-decisions.tsv`，再重新运行 generator。`reports/wechat-article-intake.jsonl` 必须由脚本生成，保持每篇文章一个当前状态。推荐状态：

- `queued`：尚未审查或等待后续批次。
- `absorbed-method-only`：只吸收抽象方法，不吸收文章来源、工具宣传或代码。
- `reference-only`：已有资产覆盖或内容不稳定，只保留为参考。
- `rejected`：超出 ADK 边界、质量不足或与现有规则冲突。

P0 批次不得混入 P1 实装；若旧批次报告出现 P1 候选，只能登记为 `DEFER`，由对应批次处理。

## Verification

最小验证：

```bash
rtk scripts/check-wechat-intake-ledger.sh .
rtk scripts/check-all.sh --quick
```

涉及 `agent-dev-kit` 资产时追加：

```bash
rtk agent-dev-kit/tests/run_all.sh
rtk agent-dev-kit/scripts/validate-assets.sh --strict
rtk agent-dev-kit/scripts/check-token-budget.sh
rtk agent-dev-kit/scripts/check-memory-governance.sh
```

涉及 routing、manifest 或 skill metadata 时追加：

```bash
rtk scripts/check-skill-routing-conflicts.sh .
rtk scripts/check-skill-metadata.sh .
```

## Anti-Drift Rules

- 不把文章来源名、营销表达或平台排名写进 core skill。
- 不因文章提到工具就新增子仓；必须先通过供应链审查。
- 不用文章覆盖 `AGENTS.md`、`docs/absorption-governance.md` 或 `agent-dev-kit/manifest.yaml` 的既有边界。
- 不把长期规则写成一次性任务记录。
- 不保留空草稿、未引用模板或未接入门禁的脚本。
